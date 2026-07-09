class Whatsapp::GroupMessageNormalizer
  GROUP_SENDER_PATTERN = /\A\*\*(?<sender>[^*\n]+):\*\*\s*\n+(?<body>.*)\z/m
  DIGIT_MENTION_PATTERN = /@(?<token>\d{6,})(?!\w)/

  def initialize(conversation:, message_type:, content:, content_attributes:)
    @conversation = conversation
    @message_type = message_type.to_s
    @content = content.to_s
    @content_attributes = content_attributes.presence || {}
  end

  def perform
    return normalized_payload unless should_normalize?

    extract_group_sender_from_content
    normalize_mentions_in_content

    normalized_payload
  end

  private

  attr_reader :conversation

  def normalized_payload
    {
      content: @content,
      content_attributes: @content_attributes
    }
  end

  def should_normalize?
    enabled? && incoming_message? && api_inbox? && group_source_id.present?
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch('WHATSAPP_GROUP_MENTIONS_ENABLED', false)
    )
  end

  def incoming_message?
    @message_type == 'incoming'
  end

  def api_inbox?
    conversation.inbox&.api?
  end

  def group_source_id
    @group_source_id ||= [
      conversation.contact_inbox&.source_id,
      conversation.contact&.identifier,
      conversation.contact&.phone_number
    ].map { |value| value.to_s.strip }.find { |value| value.end_with?('@g.us') }
  end

  def extract_group_sender_from_content
    match = @content.match(GROUP_SENDER_PATTERN)
    return unless match

    @content = match[:body]
    @content_attributes = @content_attributes.merge(
      whatsapp_group_sender: group_sender_payload(match[:sender])
    )
  end

  def group_sender_payload(sender_label)
    participant_sender = group_sender_participant_payload(sender_label)
    return participant_sender if participant_sender.present?

    phone = phone_digits(sender_label)
    name = sender_label.to_s.sub(/\A[\d\s+\-().]+-\s*/, '').strip.presence

    {
      label: name || formatted_phone(phone) || sender_label,
      name: name,
      phone: phone,
      jid: phone.present? ? "#{phone}@s.whatsapp.net" : nil
    }.compact
  end

  def group_sender_participant_payload(sender_label)
    return unless sender_label.to_s.include?('@lid')
    return unless evolution_client.configured?

    sender_keys = group_sender_lookup_keys(sender_label)
    return if sender_keys.blank?

    participant = evolution_client.fetch_group_participants(group_source_id)
                                  .filter_map { |item| normalize_mention(item) }
                                  .find do |mention|
      (mention_lookup_keys(mention) & sender_keys).any?
    end
    return if participant.blank?

    label = participant[:label]
    return if label.blank? || label.include?('@lid') || numeric_label?(label)

    {
      label: label,
      name: label,
      phone: participant[:phone],
      jid: participant[:jid],
      lid: participant[:lid]
    }.compact
  rescue StandardError => e
    Rails.logger.warn(
      "Whatsapp group sender normalization failed for conversation #{conversation.id}: " \
      "#{e.class} - #{e.message}"
    )
    nil
  end

  def normalize_mentions_in_content
    return unless @content.match?(DIGIT_MENTION_PATTERN)

    mentions_by_token = structured_mentions_by_token
    if mentions_by_token.blank?
      mentions_by_token = mentions_by_token.merge(participant_mentions_by_token)
    end
    return if mentions_by_token.blank?

    selected_mentions = []
    @content = @content.gsub(DIGIT_MENTION_PATTERN) do
      token = Regexp.last_match[:token]
      mention = mentions_by_token[token]
      next Regexp.last_match[0] unless mention

      selected_mentions << mention
      "@#{mention[:label]}"
    end

    merge_whatsapp_mentions(selected_mentions)
  end

  def structured_mentions_by_token
    whatsapp_mentions.each_with_object({}) do |mention, index|
      normalized = normalize_mention(mention)
      next if normalized.blank?

      mention_lookup_keys(normalized).each { |key| index[key] ||= normalized }
    end
  end

  def participant_mentions_by_token
    return {} unless evolution_client.configured?

    participants = evolution_client.fetch_group_participants(group_source_id)
    participants.each_with_object({}) do |participant, index|
      normalized = normalize_mention(participant)
      next if normalized.blank?

      mention_lookup_keys(normalized).each { |key| index[key] ||= normalized }
    end
  rescue StandardError => e
    Rails.logger.warn(
      "Whatsapp group mention normalization failed for conversation #{conversation.id}: " \
      "#{e.class} - #{e.message}"
    )
    {}
  end

  def evolution_client
    @evolution_client ||= EvolutionApi::ProfileClient.new
  end

  def normalize_mention(mention)
    return unless mention.respond_to?(:with_indifferent_access)

    mention = mention.with_indifferent_access
    jid = mention[:jid].presence
    lid = mention[:lid].presence
    phone = mention[:phone].presence || phone_digits(jid)
    label = mention[:label].presence ||
            contact_label_for(phone, jid, lid) ||
            formatted_phone(phone) ||
            jid ||
            lid
    return if label.blank?

    {
      jid: jid,
      lid: lid,
      phone: phone,
      label: label
    }.compact
  end

  def contact_label_for(phone, jid, lid)
    contact = contacts_by_key[phone] || contacts_by_key[jid] || contacts_by_key[lid]
    return unless contact

    [
      contact.name,
      contact.additional_attributes&.dig('name'),
      contact.additional_attributes&.dig('push_name'),
      contact.additional_attributes&.dig('pushName')
    ].find { |value| value.present? && !numeric_label?(value) }
  end

  def contacts_by_key
    @contacts_by_key ||= begin
      keys = mention_tokens_from_content
      contacts = Contact
                 .where(account_id: conversation.account_id)
                 .left_outer_joins(:contact_inboxes)
                 .where(
                   'contacts.phone_number IN (:phones) OR contacts.identifier IN (:sources) ' \
                   'OR contact_inboxes.source_id IN (:sources)',
                   phones: keys.flat_map { |key| [key, "+#{key}"] },
                   sources: keys.flat_map { |key| [key, "#{key}@s.whatsapp.net", "#{key}@lid"] }
                 )
                 .preload(:contact_inboxes)
                 .select('contacts.*')
                 .distinct

      contacts.each_with_object({}) do |contact, index|
        contact_lookup_keys(contact).each { |key| index[key] ||= contact }
      end
    end
  end

  def contact_lookup_keys(contact)
    [
      contact.phone_number,
      contact.identifier,
      contact.additional_attributes&.dig('whatsapp_jid'),
      contact.additional_attributes&.dig('whatsapp_lid'),
      contact.contact_inboxes.map(&:source_id)
    ].flatten.compact.flat_map { |value| lookup_keys(value) }.uniq
  end

  def mention_lookup_keys(mention)
    [
      mention[:phone],
      mention[:jid],
      mention[:lid]
    ].compact.flat_map { |value| lookup_keys(value) }.uniq
  end

  def mention_tokens_from_content
    @content.scan(DIGIT_MENTION_PATTERN).flatten.uniq
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

  def group_sender_lookup_keys(sender_label)
    jid_tokens = sender_label.to_s.scan(/\d+@(?:lid|s\.whatsapp\.net)/)
    (lookup_keys(sender_label) + jid_tokens.flat_map { |token| lookup_keys(token) }).uniq
  end

  def phone_digits(value)
    value.to_s.gsub(/\D/, '').presence
  end

  def formatted_phone(phone)
    phone.present? ? "+#{phone}" : nil
  end

  def numeric_label?(value)
    value.to_s.strip.match?(/\A[\d\s+\-().]+\z/)
  end

  def merge_whatsapp_mentions(selected_mentions)
    mentions = whatsapp_mentions
    mention_keys = mentions.filter_map do |mention|
      next unless mention.respond_to?(:with_indifferent_access)

      mention = mention.with_indifferent_access
      mention[:jid] || mention[:lid]
    end

    selected_mentions.uniq { |mention| mention[:jid] || mention[:lid] }.each do |mention|
      key = mention[:jid] || mention[:lid]
      next if key.present? && mention_keys.include?(key)

      mentions << mention
    end

    return if mentions.blank?

    @content_attributes = @content_attributes
                          .except(:whatsapp_mentions, 'whatsapp_mentions')
                          .merge(whatsapp_mentions: mentions)
  end

  def whatsapp_mentions
    Array(@content_attributes[:whatsapp_mentions] || @content_attributes['whatsapp_mentions'])
  end
end
