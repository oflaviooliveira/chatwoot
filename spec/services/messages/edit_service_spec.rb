require 'rails_helper'

RSpec.describe Messages::EditService do
  let(:message) do
    create(
      :message,
      message_type: :outgoing,
      content_type: :text,
      content: 'Original message',
      status: :sent,
      created_at: 5.minutes.ago
    )
  end

  it 'updates the content and records the edit metadata' do
    described_class.new(message, 'Corrected message').perform

    expect(message.reload.content).to eq('Corrected message')
    expect(message.content_attributes).to include('edited' => true)
    expect(message.content_attributes['edited_at']).to be_present
  end

  it 'rejects edits after the WhatsApp edit window' do
    message.update_column(:created_at, 16.minutes.ago)

    expect { described_class.new(message, 'Too late').perform }
      .to raise_error(described_class::Error, 'The message edit window has expired')
  end

  it 'rejects incoming messages' do
    message.incoming!

    expect { described_class.new(message, 'Not allowed').perform }
      .to raise_error(described_class::Error, 'Only outgoing messages can be edited')
  end
end
