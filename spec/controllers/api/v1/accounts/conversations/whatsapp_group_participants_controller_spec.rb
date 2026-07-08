require 'rails_helper'

RSpec.describe 'Whatsapp Group Participants API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) { create(:channel_api, account: account) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account, identifier: '120363123@g.us') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '120363123@g.us') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:client) { instance_double(EvolutionApi::ProfileClient, configured?: true) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    allow(EvolutionApi::ProfileClient).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_group_participants).and_return([])
    allow(ENV).to receive(:fetch).and_call_original
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/<id>/whatsapp_group_participants' do
    it 'returns unauthorized for an unauthenticated user' do
      get api_v1_account_conversation_whatsapp_group_participants_url(
        account_id: account.id,
        conversation_id: conversation.display_id
      )

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns participants when the feature is enabled for an api group conversation' do
      allow(ENV).to receive(:fetch).with('WHATSAPP_GROUP_MENTIONS_ENABLED', false).and_return('true')
      allow(client).to receive(:fetch_group_participants).with('120363123@g.us').and_return(
        [
          { jid: '5521985294475@s.whatsapp.net', label: 'Joao Pedro', phone: '5521985294475' }
        ]
      )

      get api_v1_account_conversation_whatsapp_group_participants_url(
        account_id: account.id,
        conversation_id: conversation.display_id
      ),
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(response.headers['Pragma']).to eq('no-cache')
      expect(response.headers['Expires']).to eq('0')
      expect(response.parsed_body['participants']).to eq(
        [
          {
            'jid' => '5521985294475@s.whatsapp.net',
            'label' => 'Joao Pedro',
            'phone' => '5521985294475',
            'saved' => false
          }
        ]
      )
    end

    it 'uses an existing Chatwoot contact name when Evolution only returns the phone number' do
      participant_contact = create(:contact, account: account, name: 'Maria Silva', phone_number: '+5521985294475')
      create(:contact_inbox, contact: participant_contact, inbox: inbox, source_id: '5521985294475@s.whatsapp.net')

      allow(ENV).to receive(:fetch).with('WHATSAPP_GROUP_MENTIONS_ENABLED', false).and_return('true')
      allow(client).to receive(:fetch_group_participants).with('120363123@g.us').and_return(
        [
          { jid: '5521985294475@s.whatsapp.net', label: '5521985294475', phone: '5521985294475' }
        ]
      )

      get api_v1_account_conversation_whatsapp_group_participants_url(
        account_id: account.id,
        conversation_id: conversation.display_id
      ),
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(response.parsed_body['participants']).to eq(
        [
          {
            'jid' => '5521985294475@s.whatsapp.net',
            'label' => 'Maria Silva',
            'phone' => '5521985294475',
            'saved' => true,
            'contact_id' => participant_contact.id
          }
        ]
      )
    end

    it 'returns an empty list when the feature is disabled' do
      allow(ENV).to receive(:fetch).with('WHATSAPP_GROUP_MENTIONS_ENABLED', false).and_return('false')

      get api_v1_account_conversation_whatsapp_group_participants_url(
        account_id: account.id,
        conversation_id: conversation.display_id
      ),
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['participants']).to eq([])
      expect(client).not_to have_received(:fetch_group_participants)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/whatsapp_group_participants/save_contact' do
    it 'creates a contact and contact inbox for a group participant' do
      allow(ENV).to receive(:fetch).with('WHATSAPP_GROUP_MENTIONS_ENABLED', false).and_return('true')

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/whatsapp_group_participants/save_contact",
           params: {
             jid: '5521985294475@s.whatsapp.net',
             label: 'Maria Silva'
           },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)

      created_contact = account.contacts.find_by!(phone_number: '+5521985294475')
      expect(created_contact.name).to eq('Maria Silva')
      expect(inbox.contact_inboxes.find_by!(source_id: '5521985294475@s.whatsapp.net').contact).to eq(created_contact)
      expect(response.parsed_body['participant']).to include(
        'jid' => '5521985294475@s.whatsapp.net',
        'label' => 'Maria Silva',
        'phone' => '5521985294475',
        'saved' => true,
        'contact_id' => created_contact.id
      )
    end
  end
end
