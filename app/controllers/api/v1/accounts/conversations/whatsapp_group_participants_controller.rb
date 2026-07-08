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

    decorate_participants(client.fetch_group_participants(source_id))
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

  def decorate_participants(participants)
    participants = Array(participants)
    contacts_by_phone = contacts_indexed_by_phone(participants)

    participants.map do |participant|
      contact = contacts_by_phone[participant_phone(participant)]
      next participant unless contact

      participant.merge(label: contact_label(contact, participant))
    end
  end

  def contacts_indexed_by_phone(participants)
    phones = participants.map { |participant| participant_phone(participant) }.compact_blank.uniq
    return {} if phones.blank?

    phone_match_values = phones.flat_map { |phone| [phone, "+#{phone}"] }.uniq
    source_match_values = phones.flat_map do |phone|
      [phone, "+#{phone}", "#{phone}@s.whatsapp.net"]
    end.uniq

    contacts = Contact
               .where(account_id: @account.id)
               .left_outer_joins(:contact_inboxes)
               .where(
                 'contacts.phone_number IN (:phone_values) OR contacts.identifier IN (:source_values) OR contact_inboxes.source_id IN (:source_values)',
                 phone_values: phone_match_values,
                 source_values: source_match_values
               )
               .preload(:contact_inboxes)
               .select('contacts.*')
               .distinct

    contacts.each_with_object({}) do |contact, index|
      contact_phones(contact).each do |phone|
        index[phone] ||= contact if contact_label(contact).present?
      end
    end
  end

  def contact_phones(contact)
    values = [
      contact.phone_number,
      contact.identifier,
      contact.contact_inboxes.map(&:source_id)
    ].flatten

    values.filter_map { |value| phone_digits(value) }.uniq
  end

  def contact_label(contact, participant = nil)
    [
      contact.name,
      contact.additional_attributes&.dig('name'),
      contact.additional_attributes&.dig('push_name'),
      contact.additional_attributes&.dig('pushName'),
      participant&.dig(:label),
      participant&.dig('label')
    ].find { |value| value.present? && !numeric_label?(value) }
  end

  def participant_phone(participant)
    phone_digits(participant[:phone] || participant['phone'] || participant[:jid] || participant['jid'])
  end

  def phone_digits(value)
    digits = value.to_s.gsub(/\D/, '')
    digits.presence
  end

  def numeric_label?(value)
    value.to_s.strip.match?(/\A[\d\s+\-().]+\z/)
  end
end
