require 'rails_helper'

RSpec.describe Whatsapp::ProfileEnrichmentJob do
  describe '.enqueue_for_message' do
    it 'enqueues for incoming messages' do
      message = create(:message, message_type: :incoming)

      expect { described_class.enqueue_for_message(message) }
        .to have_enqueued_job(described_class).with(message.id).on_queue('low')
    end

    it 'does not enqueue for outgoing messages' do
      message = create(:message, message_type: :outgoing)

      expect { described_class.enqueue_for_message(message) }
        .not_to have_enqueued_job(described_class)
    end
  end

  describe '#perform' do
    it 'runs the enrichment service for incoming messages' do
      message = create(:message, message_type: :incoming)
      service = instance_double(EvolutionApi::WhatsappProfileEnrichmentService, perform: true)
      allow(EvolutionApi::WhatsappProfileEnrichmentService).to receive(:new).with(conversation: message.conversation).and_return(service)

      described_class.perform_now(message.id)

      expect(service).to have_received(:perform)
    end

    it 'ignores outgoing messages' do
      message = create(:message, message_type: :outgoing)
      allow(EvolutionApi::WhatsappProfileEnrichmentService).to receive(:new)

      described_class.perform_now(message.id)

      expect(EvolutionApi::WhatsappProfileEnrichmentService).not_to have_received(:new)
    end
  end
end
