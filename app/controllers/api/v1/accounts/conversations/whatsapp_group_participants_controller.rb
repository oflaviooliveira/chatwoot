class Api::V1::Accounts::Conversations::WhatsappGroupParticipantsController < Api::V1::Accounts::Conversations::BaseController
  def show
    disable_cache
    render json: { participants: participants }
  end

  def save_contact
    return render json: { error: 'Whatsapp group mentions are disabled' }, status: :forbidden unless enabled?
    return render json: { error: 'Conversation is not an API inbox group' }, status: :unprocessable_entity unless api_inbox? && group_source_id?

    contact_inbox = ContactInboxWithContactBuilder.new(
      inbox: @conversation.inbox,
      contact_attributes: contact_attributes_for_participant,
      source_id: participant_jid,
      hmac_verified: false
    ).perform

    update_contact_name(contact_inbox.contact)

    render json: {
      participant: decorate_participants([participant_payload]).first,
      contact: contact_payload(contact_inbox.contact)
    }
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
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

  def disable_cache
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
  end

  def decorate_participants(participants)
    participants = Array(participants)
    contacts_by_key = contacts_indexed_by_participant_key(participants)

    participants.map do |participant|
      contact = participant_lookup_keys(participant).filter_map { |key| contacts_by_key[key] }.first
      decorated_participant = participant.merge(saved: contact.present?)
      next decorated_participant unless contact

      label = contact_label(contact, participant)
      decorated_participant.merge(
        label: label || participant[:label] || participant['label'],
        contact_id: contact.id
      )
    end
  end

  def contacts_indexed_by_participant_key(participants)
    participant_keys = participants.flat_map { |participant| participant_lookup_keys(participant) }.compact_blank.uniq
    return {} if participant_keys.blank?

    phone_keys = participant_keys.select { |key| key.match?(/\A\d+\z/) }
    jid_keys = participant_keys.grep(/@/)
    phone_match_values = phone_keys.flat_map { |phone| [phone, "+#{phone}"] }.uniq
    phone_source_values = phone_keys.flat_map do |phone|
      [phone, "+#{phone}", "#{phone}@s.whatsapp.net"]
    end
    source_match_values = (jid_keys + phone_source_values).uniq

    contacts = Contact
               .where(account_id: Current.account.id)
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
      contact_lookup_keys(contact).each do |key|
        index[key] ||= contact
      end
    end
  end

  def contact_lookup_keys(contact)
    values = [
      contact.phone_number,
      contact.identifier,
      contact.contact_inboxes.map(&:source_id)
    ].flatten

    values.flat_map { |value| lookup_keys(value) }.uniq
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

  def participant_lookup_keys(participant)
    [
      participant[:phone],
      participant['phone'],
      participant[:jid],
      participant['jid']
    ].flat_map { |value| lookup_keys(value) }.uniq
  end

  def participant_phone(participant)
    phone_digits(participant[:phone] || participant['phone'] || participant[:jid] || participant['jid'])
  end

  def lookup_keys(value)
    value = value.to_s.strip
    return [] if value.blank?

    keys = []
    keys << value if value.include?('@')
    digits = phone_digits(value)
    keys << digits if digits.present?
    keys
  end

  def phone_digits(value)
    digits = value.to_s.gsub(/\D/, '')
    digits.presence
  end

  def numeric_label?(value)
    value.to_s.strip.match?(/\A[\d\s+\-().]+\z/)
  end

  def participant_jid
    @participant_jid ||= normalize_participant_jid(params[:jid])
  end

  def normalize_participant_jid(value)
    value = value.to_s.strip
    raise ActionController::ParameterMissing, 'jid' if value.blank?
    return value if value.end_with?('@s.whatsapp.net', '@lid')

    digits = phone_digits(value)
    raise ActionController::ParameterMissing, 'jid' if digits.blank?

    "#{digits}@s.whatsapp.net"
  end

  def participant_payload
    {
      jid: participant_jid,
      label: participant_label,
      phone: participant_phone_from_jid
    }.compact
  end

  def participant_label
    label = params[:label].to_s.strip
    return label if label.present?

    participant_phone_from_jid || participant_jid
  end

  def participant_phone_from_jid
    phone_digits(participant_jid)
  end

  def formatted_participant_phone
    phone = participant_phone_from_jid
    return if phone.blank?

    "+#{phone}"
  end

  def contact_attributes_for_participant
    {
      name: contact_name_for_participant,
      phone_number: formatted_participant_phone,
      identifier: participant_jid,
      additional_attributes: {
        whatsapp_jid: participant_jid,
        whatsapp_group_jid: source_id,
        whatsapp_group_participant: true
      }
    }.compact
  end

  def contact_name_for_participant
    return participant_label unless numeric_label?(participant_label)

    formatted_participant_phone || participant_jid
  end

  def update_contact_name(contact)
    label = participant_label
    return if numeric_label?(label)
    return if contact.name.present? && !numeric_label?(contact.name)

    contact.update!(name: label)
  end

  def contact_payload(contact)
    {
      id: contact.id,
      name: contact.name,
      phone_number: contact.phone_number,
      identifier: contact.identifier
    }
  end
end
