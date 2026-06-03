require 'rails_helper'

RSpec.describe EvolutionApi::WhatsappProfileEnrichmentService do
  subject(:service) { described_class.new(conversation: conversation) }

  let(:account) { create(:account) }
  let(:api_channel) { create(:channel_api, account: account) }
  let(:inbox) { api_channel.inbox }
  let(:contact) { create(:contact, account: account, name: contact_name, phone_number: nil) }
  let(:contact_name) { '5521985294475' }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: source_id) }
  let(:source_id) { '5521985294475' }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:client) { instance_double(EvolutionApi::ProfileClient, configured?: true) }

  before do
    allow(EvolutionApi::ProfileClient).to receive(:new).and_return(client)
  end

  def with_sync_env(&)
    with_modified_env(
      WHATSAPP_PROFILE_SYNC_ENABLED: 'true',
      WHATSAPP_PROFILE_SYNC_INBOX_IDS: inbox.id.to_s,
      &
    )
  end

  it 'updates generic contact data with profile information' do
    allow(client).to receive(:fetch_contact_profile).with('5521985294475').and_return(
      profile: { 'pushName' => 'João Pedro' },
      business_profile: { 'businessName' => 'Cliente Ana', 'description' => 'BPO financeiro', 'email' => 'ana@example.com' },
      profile_picture: { 'profilePictureUrl' => 'https://example.com/avatar.png' }
    )
    allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)

    with_sync_env { service.perform }

    contact.reload
    expect(contact.name).to eq('Cliente Ana')
    expect(contact.email).to eq('ana@example.com')
    expect(contact.phone_number).to eq('+5521985294475')
    expect(contact.additional_attributes).to include(
      'company_name' => 'Cliente Ana',
      'description' => 'BPO financeiro'
    )
    expect(contact.additional_attributes['whatsapp_profile']).to include(
      'type' => 'contact',
      'jid' => '5521985294475',
      'profile_name' => 'João Pedro',
      'business_name' => 'Cliente Ana',
      'description' => 'BPO financeiro',
      'email' => 'ana@example.com',
      'source' => 'evolution',
      'profile_picture_url' => 'https://example.com/avatar.png',
      'last_error' => nil
    )
    expect(contact.additional_attributes['whatsapp_profile']['synced_at']).to be_present
    expect(Avatar::AvatarFromUrlJob).to have_received(:perform_later).with(contact, 'https://example.com/avatar.png')
  end

  it 'does not overwrite a meaningful contact name' do
    contact.update!(name: 'Nome manual do cliente')
    allow(client).to receive(:fetch_contact_profile).and_return(
      profile: { 'pushName' => 'João Pedro' },
      business_profile: { 'businessName' => 'Cliente Ana' },
      profile_picture: {}
    )

    with_sync_env { service.perform }

    expect(contact.reload.name).to eq('Nome manual do cliente')
  end

  it 'does not overwrite visible fields filled manually' do
    contact.update!(
      email: 'manual@example.com',
      additional_attributes: {
        'company_name' => 'Empresa manual',
        'description' => 'Descricao manual'
      }
    )
    allow(client).to receive(:fetch_contact_profile).and_return(
      profile: { 'pushName' => 'João Pedro' },
      business_profile: { 'businessName' => 'Cliente Ana', 'description' => 'BPO financeiro', 'email' => 'ana@example.com' },
      profile_picture: {}
    )

    with_sync_env { service.perform }

    contact.reload
    expect(contact.email).to eq('manual@example.com')
    expect(contact.additional_attributes).to include(
      'company_name' => 'Empresa manual',
      'description' => 'Descricao manual'
    )
  end

  it 'does not set a phone number already used by another contact' do
    create(:contact, account: account, phone_number: '+5521985294475')
    allow(client).to receive(:fetch_contact_profile).and_return(
      profile: { 'pushName' => 'João Pedro' },
      business_profile: {},
      profile_picture: {}
    )

    with_sync_env { service.perform }

    expect(contact.reload.phone_number).to be_nil
  end

  it 'syncs group information from group JID' do
    contact.update!(name: '120363123@g.us')
    contact_inbox.update!(source_id: '120363123@g.us')
    allow(client).to receive(:fetch_group_profile).with('120363123@g.us').and_return(
      group: { 'subject' => 'Cliente Ana - Diretoria', 'desc' => 'Grupo oficial do cliente', 'size' => 8 },
      profile_picture: { 'profilePictureUrl' => 'https://example.com/group.png' }
    )
    allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)

    with_sync_env { service.perform }

    contact.reload
    expect(contact.name).to eq('Cliente Ana - Diretoria')
    expect(contact.phone_number).to be_nil
    expect(contact.additional_attributes).to include(
      'company_name' => 'Cliente Ana - Diretoria',
      'description' => 'Grupo oficial do cliente'
    )
    expect(contact.additional_attributes['whatsapp_profile']).to include(
      'type' => 'group',
      'jid' => '120363123@g.us',
      'profile_name' => 'Cliente Ana - Diretoria',
      'description' => 'Grupo oficial do cliente',
      'participants_count' => 8
    )
  end

  it 'uses contact identifier when API source id is not a WhatsApp JID' do
    contact.update!(name: '120363123@g.us', identifier: '120363123@g.us')
    contact_inbox.update!(source_id: '4ee4074a-3889-4865-92b6-d51553836591')
    allow(client).to receive(:fetch_group_profile).with('120363123@g.us').and_return(
      group: { 'subject' => 'Cliente Ana - Diretoria' },
      profile_picture: {}
    )

    with_sync_env { service.perform }

    expect(client).to have_received(:fetch_group_profile).with('120363123@g.us')
    expect(contact.reload.additional_attributes['whatsapp_profile']).to include(
      'type' => 'group',
      'jid' => '120363123@g.us'
    )
  end

  it 'ignores inboxes outside the configured list' do
    allow(client).to receive(:fetch_contact_profile)

    with_modified_env(WHATSAPP_PROFILE_SYNC_ENABLED: 'true', WHATSAPP_PROFILE_SYNC_INBOX_IDS: '999') do
      service.perform
    end

    expect(client).not_to have_received(:fetch_contact_profile)
  end

  it 'does not sync again before the interval' do
    contact.update!(
      additional_attributes: {
        'whatsapp_profile' => {
          'synced_at' => 1.day.ago.iso8601,
          'source' => 'evolution'
        }
      }
    )
    allow(client).to receive(:fetch_contact_profile)

    with_sync_env { service.perform }

    expect(client).not_to have_received(:fetch_contact_profile)
  end

  it 'syncs again before the interval when saved profile does not match the current WhatsApp identifier' do
    contact.update!(
      name: '120363123@g.us',
      identifier: '120363123@g.us',
      additional_attributes: {
        'whatsapp_profile' => {
          'jid' => '4ee4074a-3889-4865-92b6-d51553836591',
          'type' => 'contact',
          'synced_at' => 1.day.ago.iso8601,
          'source' => 'evolution'
        }
      }
    )
    contact_inbox.update!(source_id: '4ee4074a-3889-4865-92b6-d51553836591')
    allow(client).to receive(:fetch_group_profile).with('120363123@g.us').and_return(
      group: { 'subject' => 'Cliente Ana - Diretoria' },
      profile_picture: {}
    )

    with_sync_env { service.perform }

    expect(client).to have_received(:fetch_group_profile).with('120363123@g.us')
    expect(contact.reload.additional_attributes['whatsapp_profile']).to include(
      'type' => 'group',
      'jid' => '120363123@g.us'
    )
  end

  it 'stores errors without raising' do
    allow(client).to receive(:fetch_contact_profile).and_raise(StandardError, 'timeout')

    expect { with_sync_env { service.perform } }.not_to raise_error

    expect(contact.reload.additional_attributes['whatsapp_profile']['last_error']).to eq('StandardError: timeout')
  end
end
