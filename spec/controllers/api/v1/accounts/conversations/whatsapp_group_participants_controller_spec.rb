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
      expect(response.parsed_body['participants']).to eq(
        [
          {
            'jid' => '5521985294475@s.whatsapp.net',
            'label' => 'Joao Pedro',
            'phone' => '5521985294475'
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
end
