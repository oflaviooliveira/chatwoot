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
    update_contact_profile(contact_inbox.contact)

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
      next enrich_unsaved_participant(decorated_participant) unless contact

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
      contact.additional_attributes&.dig('company_name'),
      contact.additional_attributes&.dig('whatsapp_profile', 'display_name'),
      contact.additional_attributes&.dig('whatsapp_profile', 'business_name'),
      contact.additional_attributes&.dig('whatsapp_profile', 'profile_name'),
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

  def enrich_unsaved_participant(participant)
    return participant unless should_enrich_participant?(participant)

    profile = profile_for_participant(participant_phone(participant))
    return participant if profile.blank?

    participant.merge(profile.compact)
  end

  def should_enrich_participant?(participant)
    return false unless client.configured?

    phone = participant_phone(participant)
    return false if phone.blank?
    return false if profile_lookup_limit_reached?

    label = participant[:label] || participant['label']
    label.blank? || numeric_label?(label) || label.to_s.include?('@')
  end

  def profile_for_participant(phone)
    @participant_profile_cache ||= {}
    return @participant_profile_cache[phone] if @participant_profile_cache.key?(phone)

    @participant_profile_lookup_count ||= 0
    @participant_profile_lookup_count += 1
    @participant_profile_cache[phone] = normalize_participant_profile(client.fetch_contact_profile(phone), phone)
  rescue StandardError => e
    Rails.logger.warn(
      "Whatsapp group participant profile lookup failed for conversation #{@conversation.id}: " \
      "#{e.class} - #{e.message}"
    )
    @participant_profile_cache[phone] = {}
  end

  def profile_lookup_limit_reached?
    (@participant_profile_lookup_count || 0) >= participant_profile_lookup_limit
  end

  def participant_profile_lookup_limit
    ENV.fetch('WHATSAPP_GROUP_PARTICIPANT_PROFILE_LOOKUP_LIMIT', 8).to_i.clamp(0, 25)
  end

  def normalize_participant_profile(profile_data, phone)
    profile_data ||= {}
    profile = profile_data[:profile] || {}
    business_profile = profile_data[:business_profile] || {}
    profile_picture = profile_data[:profile_picture] || {}

    description = extract_first(business_profile, %w[description businessDescription about status]) ||
                  extract_first(profile, %w[description businessDescription about status])
    website = extract_first(business_profile, %w[website websites site]) ||
              extract_first(profile, %w[website websites site])
    email = extract_first(business_profile, %w[email businessEmail]) ||
            extract_first(profile, %w[email businessEmail])
    business_name = extract_first(business_profile, %w[businessName name verifiedName]) ||
                    inferred_business_name(description: description, website: website, email: email)
    profile_name = extract_first(profile, %w[name pushName profileName notify])
    display_name = [business_name, profile_name].find { |value| value.present? && !numeric_label?(value) && !value.include?('@') }

    {
      label: display_name,
      profile_name: profile_name,
      business_name: business_name,
      description: description,
      category: extract_first(business_profile, %w[category businessCategory vertical]),
      website: website,
      email: email,
      profile_picture_url: extract_first(profile_picture, %w[profilePictureUrl url picture]) ||
        extract_first(profile, %w[profilePictureUrl picture url]),
      phone: phone
    }.compact
  end

  def inferred_business_name(description:, website:, email:)
    business_name_from_description(description) ||
      business_name_from_domain(website) ||
      business_name_from_domain(email.to_s.split('@').last)
  end

  def business_name_from_description(description)
    text = description.to_s.strip
    return if text.blank?

    candidate = text[/\b(?:da|do|de)\s+([^.,;\n]+)/i, 1]
    normalize_inferred_business_name(candidate)
  end

  def business_name_from_domain(value)
    values = normalize_website_values(value)
    host = values.filter_map do |candidate|
      candidate = candidate.to_s.strip
      next if candidate.blank?

      url = candidate.match?(%r{\Ahttps?://}i) ? candidate : "https://#{candidate}"
      URI.parse(url).host
    rescue URI::InvalidURIError
      nil
    end.first
    return if host.blank?

    normalize_inferred_business_name(host.sub(/\Awww\./, '').split('.').first&.titleize)
  end

  def normalize_website_values(value)
    return value if value.is_a?(Array)
    return [] if value.blank?

    parsed = JSON.parse(value.to_s)
    parsed.is_a?(Array) ? parsed : [value]
  rescue JSON::ParserError
    [value]
  end

  def normalize_inferred_business_name(value)
    value = value.to_s.squish
    return if value.blank?
    return if numeric_label?(value) || value.include?('@')
    return if value.length > 80

    value
  end

  def extract_first(payload, keys)
    payload = unwrap_payload(payload)
    keys.lazy.map { |key| payload[key] || payload[key.to_sym] }.find(&:present?)
  end

  def unwrap_payload(payload)
    return {} unless payload.is_a?(Hash)

    data = payload['data'] || payload[:data]
    return unwrap_payload(data) if data.is_a?(Hash)

    business_profile = payload['businessProfile'] || payload[:businessProfile]
    return unwrap_payload(business_profile) if business_profile.is_a?(Hash)

    payload
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
      phone: participant_phone_from_jid,
      lid: participant_lid
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

  def participant_lid
    lid = params[:lid].to_s.strip
    return if lid.blank?
    return lid if lid.end_with?('@lid')

    digits = phone_digits(lid)
    digits.present? ? "#{digits}@lid" : nil
  end

  def formatted_participant_phone
    phone = participant_phone_from_jid
    return if phone.blank?

    "+#{phone}"
  end

  def contact_attributes_for_participant
    {
      name: contact_name_for_participant,
      email: participant_email,
      phone_number: formatted_participant_phone,
      identifier: participant_jid,
      additional_attributes: {
        whatsapp_jid: participant_jid,
        whatsapp_lid: participant_lid,
        whatsapp_group_jid: source_id,
        whatsapp_group_participant: true
      }.compact.merge(participant_additional_attributes)
    }.compact
  end

  def contact_name_for_participant
    enriched_name = participant_enriched_name
    return enriched_name if enriched_name.present?
    return participant_label unless numeric_label?(participant_label)

    formatted_participant_phone || participant_jid
  end

  def update_contact_name(contact)
    label = participant_enriched_name || participant_label
    return if numeric_label?(label)
    return if contact.name.present? && !numeric_label?(contact.name)

    contact.update!(name: label)
  end

  def participant_enriched_name
    [
      params[:business_name],
      params[:profile_name],
      params[:label]
    ].map { |value| value.to_s.strip }
     .find { |value| value.present? && !numeric_label?(value) && !value.include?('@') }
  end

  def participant_email
    email = params[:email].to_s.strip
    return unless Devise.email_regexp.match?(email)
    return if Current.account.contacts.where(email: email).exists?

    email
  end

  def participant_additional_attributes
    attrs = {}
    attrs[:company_name] = params[:business_name].to_s.strip if params[:business_name].present?
    attrs[:description] = params[:description].to_s.strip if params[:description].present?
    attrs[:whatsapp_profile] = participant_whatsapp_profile
    attrs.compact
  end

  def participant_whatsapp_profile
    {
      type: 'contact',
      jid: participant_jid,
      lid: participant_lid,
      display_name: participant_enriched_name,
      profile_name: params[:profile_name].to_s.strip.presence,
      business_name: params[:business_name].to_s.strip.presence,
      description: params[:description].to_s.strip.presence,
      category: params[:category].to_s.strip.presence,
      website: params[:website].to_s.strip.presence,
      email: participant_email,
      phone_number: formatted_participant_phone,
      profile_picture_url: params[:profile_picture_url].to_s.strip.presence,
      source: 'evolution',
      synced_at: Time.current.iso8601
    }.compact
  end

  def update_contact_profile(contact)
    attrs = contact.additional_attributes || {}
    contact.update!(additional_attributes: attrs.deep_merge(participant_additional_attributes.deep_stringify_keys))
    enqueue_avatar_sync(contact)
  end

  def enqueue_avatar_sync(contact)
    avatar_url = params[:profile_picture_url].to_s.strip
    return if avatar_url.blank?

    Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
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
