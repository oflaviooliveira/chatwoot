class Whatsapp::ProfileEnrichmentJob < ApplicationJob
  queue_as :low

  def self.enqueue_for_message(message)
    return unless message&.incoming?

    perform_later(message.id)
  rescue StandardError => e
    Rails.logger.warn("Whatsapp::ProfileEnrichmentJob enqueue failed: #{e.class} - #{e.message}")
  end

  def perform(message_id)
    message = Message.includes(conversation: [:contact, :contact_inbox, :inbox]).find_by(id: message_id)
    return unless message&.incoming?

    EvolutionApi::WhatsappProfileEnrichmentService.new(conversation: message.conversation).perform
  end
end
