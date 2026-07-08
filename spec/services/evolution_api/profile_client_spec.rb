require 'rails_helper'

RSpec.describe EvolutionApi::ProfileClient do
  let(:client) do
    described_class.new(
      api_url: 'https://evolution.example.com',
      instance_name: 'gquick-atendimento',
      api_key: 'secret-key'
    )
  end

  def response(payload, success: true, code: 200, body: payload.to_json)
    instance_double(HTTParty::Response, success?: success, parsed_response: payload, code: code, body: body)
  end

  describe '#configured?' do
    it 'returns true when api url, instance and key are present' do
      expect(client.configured?).to be(true)
    end

    it 'returns false when any required value is blank' do
      client = described_class.new(api_url: '', instance_name: 'instance', api_key: 'key')

      expect(client.configured?).to be(false)
    end
  end

  describe '#fetch_contact_profile' do
    it 'fetches profile, business profile and profile picture' do
      allow(HTTParty).to receive(:post)
        .with(
          'https://evolution.example.com/chat/fetchProfile/gquick-atendimento',
          hash_including(body: { number: '5521985294475' }.to_json)
        ).and_return(response({ 'pushName' => 'João Pedro' }))
      allow(HTTParty).to receive(:post)
        .with(
          'https://evolution.example.com/chat/fetchBusinessProfile/gquick-atendimento',
          hash_including(body: { number: '5521985294475' }.to_json)
        ).and_return(response({ 'businessName' => 'Cliente Ana' }))
      allow(HTTParty).to receive(:post)
        .with(
          'https://evolution.example.com/chat/fetchProfilePictureUrl/gquick-atendimento',
          hash_including(body: { number: '5521985294475' }.to_json)
        ).and_return(response({ 'profilePictureUrl' => 'https://example.com/avatar.png' }))

      result = client.fetch_contact_profile('5521985294475')

      expect(result).to eq(
        profile: { 'pushName' => 'João Pedro' },
        business_profile: { 'businessName' => 'Cliente Ana' },
        profile_picture: { 'profilePictureUrl' => 'https://example.com/avatar.png' }
      )
    end

    it 'keeps remaining data when one endpoint fails' do
      allow(HTTParty).to receive(:post).and_return(
        response({ 'pushName' => 'João Pedro' }),
        response({ 'error' => 'not found' }, success: false, code: 404, body: 'not found'),
        response({ 'profilePictureUrl' => 'https://example.com/avatar.png' })
      )

      result = client.fetch_contact_profile('5521985294475')

      expect(result).to eq(
        profile: { 'pushName' => 'João Pedro' },
        profile_picture: { 'profilePictureUrl' => 'https://example.com/avatar.png' }
      )
    end
  end

  describe '#fetch_group_profile' do
    it 'fetches group info and picture' do
      allow(HTTParty).to receive(:get)
        .with(
          'https://evolution.example.com/group/findGroupInfos/gquick-atendimento',
          hash_including(query: { groupJid: '120363123@g.us' })
        ).and_return(response({ 'subject' => 'Cliente Ana - Diretoria' }))
      allow(HTTParty).to receive(:post)
        .with(
          'https://evolution.example.com/chat/fetchProfilePictureUrl/gquick-atendimento',
          hash_including(body: { number: '120363123@g.us' }.to_json)
        ).and_return(response({ 'profilePictureUrl' => 'https://example.com/group.png' }))

      result = client.fetch_group_profile('120363123@g.us')

      expect(result).to eq(
        group: { 'subject' => 'Cliente Ana - Diretoria' },
        profile_picture: { 'profilePictureUrl' => 'https://example.com/group.png' }
      )
    end
  end

  describe '#fetch_group_participants' do
    it 'normalizes participants from group info' do
      allow(HTTParty).to receive(:get)
        .with(
          'https://evolution.example.com/group/findGroupInfos/gquick-atendimento',
          hash_including(query: { groupJid: '120363123@g.us' })
        ).and_return(
          response(
            {
              'participants' => [
                { 'id' => '5521985294475@s.whatsapp.net', 'name' => 'João Pedro', 'admin' => 'admin' },
                { 'id' => '5521999999999', 'notify' => 'Ana Silva' },
                { 'id' => '5521985294475@s.whatsapp.net', 'name' => 'João Pedro' }
              ]
            }
          )
        )

      result = client.fetch_group_participants('120363123@g.us')

      expect(result).to eq(
        [
          { jid: '5521999999999@s.whatsapp.net', label: 'Ana Silva', phone: '5521999999999' },
          { jid: '5521985294475@s.whatsapp.net', label: 'João Pedro', phone: '5521985294475', admin: 'admin' }
        ]
      )
    end

    it 'prefers phoneNumber over lid ids and keeps the lid as metadata' do
      allow(HTTParty).to receive(:get)
        .with(
          'https://evolution.example.com/group/findGroupInfos/gquick-atendimento',
          hash_including(query: { groupJid: '120363123@g.us' })
        ).and_return(
          response(
            {
              'participants' => [
                {
                  'id' => '203079056117967@lid',
                  'phoneNumber' => '5521981618351@s.whatsapp.net',
                  'admin' => nil
                }
              ]
            }
          )
        )

      result = client.fetch_group_participants('120363123@g.us')

      expect(result).to eq(
        [
          {
            jid: '5521981618351@s.whatsapp.net',
            label: '5521981618351',
            phone: '5521981618351',
            lid: '203079056117967@lid'
          }
        ]
      )
    end
  end
end
