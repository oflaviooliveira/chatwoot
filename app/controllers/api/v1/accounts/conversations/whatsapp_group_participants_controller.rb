class Api::V1::Accounts::Conversations::WhatsappGroupParticipantsController < Api::V1::Accounts::Conversations::BaseController
  def show
    render json: { participants: participants }
  end

  private

  def participants
    return [] unless enabled?
    return [] unless api_inbox?
    return [] unless group_source_id?
    return [] unless client.configured?

    client.fetch_group_participants(source_id)
  rescue StandardError => e
    Rails.logger.warn(
      "Whatsapp group participants lookup failed for conversation #{@conversation.id}: " \
      "#{e.class} - #{e.message}"
    )
    []
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch('WHATSAPP_GROUP_MENTIONS_ENABLED', false)
    )
  end

  def api_inbox?
    @conversation.inbox&.api?
  end

  def group_source_id?
    source_id.to_s.end_with?('@g.us')
  end

  def source_id
    @source_id ||= source_id_candidates.min_by { |value| source_id_priority(value) }.to_s
  end

  def source_id_candidates
    [
      @conversation.contact_inbox&.source_id,
      @conversation.contact&.identifier,
      @conversation.contact&.phone_number
    ].map { |value| value.to_s.strip }.reject(&:blank?)
  end

  def source_id_priority(value)
    value.end_with?('@g.us') ? 0 : 1
  end

  def client
    @client ||= EvolutionApi::ProfileClient.new
  end
end
