require 'rails_helper'

describe Messages::MessageBuilder do
  subject(:message_builder) { described_class.new(user, conversation, params).perform }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:inbox_member) { create(:inbox_member, inbox: inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:message_for_reply) { create(:message, conversation: conversation) }
  let(:params) do
    ActionController::Parameters.new({
                                       content: 'test'
                                     })
  end

  describe '#perform' do
    it 'creates a message' do
      message = message_builder
      expect(message.content).to eq params[:content]
    end
  end

  describe '#content_attributes' do
    context 'when content_attributes is a JSON string' do
      let(:params) do
        ActionController::Parameters.new({
                                           content: 'test',
                                           content_attributes: "{\"in_reply_to\":#{message_for_reply.id}}"
                                         })
      end

      it 'parses content_attributes from JSON string' do
        message = described_class.new(user, conversation, params).perform
        expect(message.content_attributes).to include(in_reply_to: message_for_reply.id)
      end
    end

    context 'when content_attributes is a hash' do
      let(:params) do
        ActionController::Parameters.new({
                                           content: 'test',
                                           content_attributes: { in_reply_to: message_for_reply.id }
                                         })
      end

      it 'uses content_attributes as provided' do
        message = described_class.new(user, conversation, params).perform
        expect(message.content_attributes).to include(in_reply_to: message_for_reply.id)
      end
    end

    context 'when content_attributes is absent' do
      let(:params) do
        ActionController::Parameters.new({ content: 'test' })
      end

      it 'defaults to an empty hash' do
        message = message_builder
        expect(message.content_attributes).to eq({})
      end
    end

    context 'when content_attributes is nil' do
      let(:params) do
        ActionController::Parameters.new({
                                           content: 'test',
                                           content_attributes: nil
                                         })
      end

      it 'defaults to an empty hash' do
        message = message_builder
        expect(message.content_attributes).to eq({})
      end
    end

    context 'when content_attributes is an invalid JSON string' do
      let(:params) do
        ActionController::Parameters.new({
                                           content: 'test',
                                           content_attributes: 'invalid_json'
                                         })
      end

      it 'defaults to an empty hash' do
        message = message_builder
        expect(message.content_attributes).to eq({})
      end
    end
  end

  describe '#perform when message_type is incoming' do
    context 'when channel is not api' do
      let(:params) do
        ActionController::Parameters.new({
                                           content: 'test',
                                           message_type: 'incoming'
                                         })
      end

      it 'creates throws error when channel is not api' do
        expect { message_builder }.to raise_error 'Incoming messages are only allowed in Api inboxes'
      end
    end

    context 'when channel is api' do
      let(:channel_api) { create(:channel_api, account: account) }
      let(:conversation) { create(:conversation, inbox: channel_api.inbox, account: account) }
      let(:params) do
        ActionController::Parameters.new({
                                           content: 'test',
                                           message_type: 'incoming'
                                         })
      end

      it 'creates message when channel is api' do
        message = message_builder
        expect(message.message_type).to eq params[:message_type]
      end
    end

    context 'when an Evolution API group message includes sender and mention text' do
      let(:channel_api) { create(:channel_api, account: account) }
      let(:group_contact) { create(:contact, account: account, identifier: '120363123@g.us') }
      let(:group_contact_inbox) do
        create(
          :contact_inbox,
          contact: group_contact,
          inbox: channel_api.inbox,
          source_id: '120363123@g.us'
        )
      end
      let(:conversation) do
        create(
          :conversation,
          inbox: channel_api.inbox,
          account: account,
          contact: group_contact,
          contact_inbox: group_contact_inbox
        )
      end
      let(:client) { instance_double(EvolutionApi::ProfileClient, configured?: true) }
      let(:params) do
        content = '**+55 21 98712 1920 - Thayane - Administrativo e Financeiro:**' \
                  "\n\n@76716890431647 Quarta"

        ActionController::Parameters.new({
                                           content: content,
                                           message_type: 'incoming',
                                           content_attributes: { in_reply_to: message_for_reply.id }
                                         })
      end

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('WHATSAPP_GROUP_MENTIONS_ENABLED', false).and_return('true')
        allow(EvolutionApi::ProfileClient).to receive(:new).and_return(client)
        allow(client).to receive(:fetch_group_participants).with('120363123@g.us').and_return(
          [
            {
              jid: '5521985294475@s.whatsapp.net',
              lid: '76716890431647@lid',
              label: 'Flavio Oliveira',
              phone: '5521985294475'
            }
          ]
        )
      end

      it 'stores the group sender separately and renders the raw mention with the participant label' do
        message = message_builder
        content_attributes = message.content_attributes.with_indifferent_access

        expect(message.content).to eq('@Flavio Oliveira Quarta')
        expect(content_attributes[:in_reply_to]).to eq(message_for_reply.id)
        expect(content_attributes.dig(:whatsapp_group_sender, :label))
          .to eq('Thayane - Administrativo e Financeiro')
        expect(content_attributes.dig(:whatsapp_group_sender, :phone)).to eq('5521987121920')
        expect(content_attributes[:whatsapp_mentions]).to include(
          include(
            jid: '5521985294475@s.whatsapp.net',
            lid: '76716890431647@lid',
            label: 'Flavio Oliveira'
          )
        )
      end

      context 'when the group sender arrives as a WhatsApp LID' do
        let(:params) do
          ActionController::Parameters.new({
                                             content: "**76716890431647@lid - 76716890431647@lid:**\n\nT2",
                                             message_type: 'incoming',
                                             content_attributes: {}
                                           })
        end

        it 'resolves the visible sender label from the group participant list' do
          message = message_builder
          content_attributes = message.content_attributes.with_indifferent_access

          expect(message.content).to eq('T2')
          expect(content_attributes.dig(:whatsapp_group_sender, :label)).to eq('Flavio Oliveira')
          expect(content_attributes.dig(:whatsapp_group_sender, :name)).to eq('Flavio Oliveira')
          expect(content_attributes.dig(:whatsapp_group_sender, :phone)).to eq('5521985294475')
          expect(content_attributes.dig(:whatsapp_group_sender, :lid)).to eq('76716890431647@lid')
        end
      end
    end

    context 'when WhatsApp group mentions are disabled' do
      let(:channel_api) { create(:channel_api, account: account) }
      let(:group_contact) { create(:contact, account: account, identifier: '120363123@g.us') }
      let(:group_contact_inbox) do
        create(
          :contact_inbox,
          contact: group_contact,
          inbox: channel_api.inbox,
          source_id: '120363123@g.us'
        )
      end
      let(:conversation) do
        create(
          :conversation,
          inbox: channel_api.inbox,
          account: account,
          contact: group_contact,
          contact_inbox: group_contact_inbox
        )
      end
      let(:params) do
        ActionController::Parameters.new({
                                           content: "**+55 21 98712 1920 - Thayane:**\n\n@76716890431647 Quarta",
                                           message_type: 'incoming'
                                         })
      end

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('WHATSAPP_GROUP_MENTIONS_ENABLED', false).and_return('false')
      end

      it 'keeps the incoming content unchanged' do
        message = message_builder

        expect(message.content).to eq(params[:content])
        expect(message.content_attributes).to eq({})
      end
    end

    context 'when attachment messages' do
      let(:params) do
        ActionController::Parameters.new({
                                           content: 'test',
                                           attachments: [Rack::Test::UploadedFile.new('spec/assets/avatar.png', 'image/png')]
                                         })
      end

      it 'creates message with attachments' do
        message = message_builder
        expect(message.attachments.first.file_type).to eq 'image'
      end

      context 'when DIRECT_UPLOAD_ENABLED' do
        let(:params) do
          ActionController::Parameters.new({
                                             content: 'test',
                                             attachments: [get_blob_for('spec/assets/avatar.png', 'image/png').signed_id]
                                           })
        end

        it 'creates message with attachments' do
          message = message_builder
          expect(message.attachments.first.file_type).to eq 'image'
        end
      end
    end

    context 'when email channel messages' do
      let!(:channel_email) { create(:channel_email, account: account) }
      let(:inbox_member) { create(:inbox_member, inbox: channel_email.inbox) }
      let(:conversation) { create(:conversation, inbox: channel_email.inbox, account: account) }
      let(:params) do
        ActionController::Parameters.new({ cc_emails: 'test_cc_mail@test.com', bcc_emails: 'test_bcc_mail@test.com' })
      end

      it 'creates message with content_attributes for cc and bcc email addresses' do
        message = message_builder

        expect(message.content_attributes[:cc_emails]).to eq [params[:cc_emails]]
        expect(message.content_attributes[:bcc_emails]).to eq [params[:bcc_emails]]
      end

      it 'does not create message with wrong cc and bcc email addresses' do
        params = ActionController::Parameters.new({ cc_emails: 'test.com', bcc_emails: 'test_bcc.com' })
        expect { described_class.new(user, conversation, params).perform }.to raise_error 'Invalid email address'
      end

      it 'strips off whitespace before saving cc_emails and bcc_emails' do
        cc_emails = ' test1@test.com , test2@test.com, test3@test.com'
        bcc_emails = 'test1@test.com,test2@test.com, test3@test.com '
        params = ActionController::Parameters.new({ cc_emails: cc_emails, bcc_emails: bcc_emails })

        message = described_class.new(user, conversation, params).perform

        expect(message.content_attributes[:cc_emails]).to eq ['test1@test.com', 'test2@test.com', 'test3@test.com']
        expect(message.content_attributes[:bcc_emails]).to eq ['test1@test.com', 'test2@test.com', 'test3@test.com']
      end

      context 'when custom email content is provided' do
        before do
          account.enable_features('quoted_email_reply')
        end

        it 'creates message with custom HTML email content' do
          params = ActionController::Parameters.new({
                                                      content: 'Regular message content',
                                                      email_html_content: '<p>Custom <strong>HTML</strong> content</p>'
                                                    })

          message = described_class.new(user, conversation, params).perform

          expect(message.content_attributes.dig('email', 'html_content', 'full')).to eq '<p>Custom <strong>HTML</strong> content</p>'
          expect(message.content_attributes.dig('email', 'html_content', 'reply')).to eq '<p>Custom <strong>HTML</strong> content</p>'
          expect(message.content_attributes.dig('email', 'text_content', 'full')).to eq 'Regular message content'
          expect(message.content_attributes.dig('email', 'text_content', 'reply')).to eq 'Regular message content'
        end

        it 'does not process custom email content for private messages' do
          params = ActionController::Parameters.new({
                                                      content: 'Regular message content',
                                                      email_html_content: '<p>Custom HTML content</p>',
                                                      private: true
                                                    })

          message = described_class.new(user, conversation, params).perform

          expect(message.content_attributes.dig('email', 'html_content')).to be_nil
          expect(message.content_attributes.dig('email', 'text_content')).to be_nil
        end

        it 'falls back to default behavior when no custom email content is provided' do
          params = ActionController::Parameters.new({
                                                      content: 'Regular **markdown** content'
                                                    })

          message = described_class.new(user, conversation, params).perform

          expect(message.content_attributes.dig('email', 'html_content', 'full')).to include('<strong>markdown</strong>')
          expect(message.content_attributes.dig('email', 'text_content', 'full')).to eq 'Regular **markdown** content'
        end
      end

      context 'when liquid templates are present in email content' do
        let(:contact) { create(:contact, name: 'John', email: 'john@example.com') }
        let(:conversation) { create(:conversation, inbox: channel_email.inbox, account: account, contact: contact) }

        it 'processes liquid variables in email content' do
          params = ActionController::Parameters.new({
                                                      content: 'Hello {{contact.name}}, your email is {{contact.email}}'
                                                    })

          message = described_class.new(user, conversation, params).perform

          expect(message.content_attributes.dig('email', 'html_content', 'full')).to include('Hello John')
          expect(message.content_attributes.dig('email', 'html_content', 'full')).to include('john@example.com')
          expect(message.content_attributes.dig('email', 'text_content', 'full')).to eq 'Hello John, your email is john@example.com'
        end

        it 'does not process liquid in code blocks' do
          params = ActionController::Parameters.new({
                                                      content: 'Hello {{contact.name}}, use this code: `{{contact.email}}`'
                                                    })

          message = described_class.new(user, conversation, params).perform

          expect(message.content_attributes.dig('email', 'text_content', 'full')).to eq 'Hello John, use this code: `{{contact.email}}`'
        end

        it 'handles broken liquid syntax gracefully' do
          params = ActionController::Parameters.new({
                                                      content: 'Hello {{contact.name}  {{invalid}}'
                                                    })

          message = described_class.new(user, conversation, params).perform

          expect(message.content_attributes.dig('email', 'text_content', 'full')).to eq 'Hello {{contact.name}  {{invalid}}'
        end

        it 'does not process liquid for incoming messages' do
          params = ActionController::Parameters.new({
                                                      content: 'Hello {{contact.name}}',
                                                      message_type: 'incoming'
                                                    })

          api_channel = create(:channel_api, account: account)
          api_conversation = create(:conversation, inbox: api_channel.inbox, account: account, contact: contact)

          message = described_class.new(user, api_conversation, params).perform

          expect(message.content).to eq 'Hello {{contact.name}}'
        end

        it 'does not process liquid for private messages' do
          params = ActionController::Parameters.new({
                                                      content: 'Hello {{contact.name}}',
                                                      private: true
                                                    })

          message = described_class.new(user, conversation, params).perform

          expect(message.content_attributes.dig('email', 'html_content')).to be_nil
          expect(message.content_attributes.dig('email', 'text_content')).to be_nil
        end
      end
    end
  end
end
