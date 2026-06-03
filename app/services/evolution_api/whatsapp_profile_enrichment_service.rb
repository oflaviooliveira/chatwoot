# rubocop:disable Metrics/ClassLength
class EvolutionApi::WhatsappProfileEnrichmentService
  PROFILE_ATTRIBUTE_KEY = 'whatsapp_profile'.freeze
  SYNC_INTERVAL = 7.days
  GENERIC_NAMES = %w[unknown undefined unavailable indisponivel indisponível contato cliente].freeze

  pattr_initialize [:conversation!]

  def perform
    return unless enabled?
    return unless eligible_inbox?
    return unless client.configured?
    return unless sync_due?

    sync_profile
  rescue StandardError => e
    Rails.logger.warn("Whatsapp profile enrichment failed for conversation #{conversation.id}: #{e.class} - #{e.message}")
    persist_error(e)
  end

  private

  delegate :contact, :contact_inbox, :inbox, to: :conversation

  def sync_profile
    profile_data = group_contact? ? client.fetch_group_profile(source_id) : client.fetch_contact_profile(query_number)
    normalized_profile = normalize_profile(profile_data)

    contact.assign_attributes(contact_update_attributes(normalized_profile))
    contact.save! if contact.changed?
    enqueue_avatar_sync(normalized_profile[:profile_picture_url])
  end

  def contact_update_attributes(profile)
    attrs = {}
    attrs[:name] = profile[:display_name] if should_update_name?(profile[:display_name])
    attrs[:phone_number] = profile[:phone_number] if should_update_phone_number?(profile[:phone_number])
    attrs[:additional_attributes] = merged_additional_attributes(profile)
    attrs
  end

  def merged_additional_attributes(profile)
    (contact.additional_attributes || {}).merge(
      PROFILE_ATTRIBUTE_KEY => profile.compact.stringify_keys.merge(
        'source' => 'evolution',
        'synced_at' => Time.current.iso8601,
        'last_error' => nil
      )
    )
  end

  def normalize_profile(profile_data)
    group_contact? ? normalize_group_profile(profile_data) : normalize_contact_profile(profile_data)
  end

  def normalize_contact_profile(profile_data)
    profile = profile_data[:profile] || {}
    business_profile = profile_data[:business_profile] || {}
    profile_picture = profile_data[:profile_picture] || {}

    business_name = extract_first(business_profile, %w[businessName name verifiedName])
    profile_name = extract_first(profile, %w[name pushName profileName notify])

    {
      type: 'contact',
      jid: source_id,
      display_name: business_name.presence || profile_name,
      profile_name: profile_name,
      business_name: business_name,
      description: extract_first(business_profile, %w[description businessDescription about status]),
      category: extract_first(business_profile, %w[category businessCategory vertical]),
      website: extract_first(business_profile, %w[website websites site]),
      email: extract_first(business_profile, %w[email businessEmail]),
      phone_number: normalized_phone_number,
      profile_picture_url: extract_first(profile_picture, %w[profilePictureUrl url picture])
    }
  end

  def normalize_group_profile(profile_data)
    group = profile_data[:group] || {}
    profile_picture = profile_data[:profile_picture] || {}

    {
      type: 'group',
      jid: source_id,
      display_name: extract_first(group, %w[subject name]),
      profile_name: extract_first(group, %w[subject name]),
      description: extract_first(group, %w[desc description]),
      owner: extract_first(group, %w[owner subjectOwner]),
      participants_count: extract_first(group, %w[size participantsCount]),
      profile_picture_url: extract_first(profile_picture, %w[profilePictureUrl url picture])
    }
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

  def enqueue_avatar_sync(avatar_url)
    return if avatar_url.blank?

    Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
  end

  def should_update_name?(candidate_name)
    candidate_name.present? && generic_name?(contact.name)
  end

  def generic_name?(name)
    normalized_name = name.to_s.strip.downcase
    return true if normalized_name.blank?
    return true if GENERIC_NAMES.include?(normalized_name)
    return true if normalized_name == source_id.to_s.downcase
    return true if normalized_name.match?(/\A\+?\d+\z/)
    return true if normalized_name.include?('@')

    false
  end

  def should_update_phone_number?(candidate_phone_number)
    candidate_phone_number.present? && contact.phone_number.blank? && phone_number_available?(candidate_phone_number)
  end

  def phone_number_available?(candidate_phone_number)
    !Contact.where(account_id: contact.account_id, phone_number: candidate_phone_number).where.not(id: contact.id).exists?
  end

  def normalized_phone_number
    return contact.phone_number if contact.phone_number.present?
    return if group_contact? || lid_contact?

    digits = source_id.to_s.gsub(/\D/, '')
    return if digits.length < 8 || digits.length > 15

    "+#{digits}"
  end

  def query_number
    return if lid_contact?

    normalized_phone_number&.delete_prefix('+') || source_id
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('WHATSAPP_PROFILE_SYNC_ENABLED', false))
  end

  def eligible_inbox?
    inbox_ids = ENV.fetch('WHATSAPP_PROFILE_SYNC_INBOX_IDS', '').split(',').map(&:strip).reject(&:blank?).map(&:to_i)
    inbox_ids.include?(inbox.id)
  end

  def sync_due?
    return true if current_profile['jid'].present? && current_profile['jid'] != source_id
    return true if current_profile['type'].present? && current_profile['type'] != expected_profile_type

    last_synced_at = current_profile['synced_at']
    return true if last_synced_at.blank?

    Time.zone.parse(last_synced_at) < SYNC_INTERVAL.ago
  rescue ArgumentError, TypeError
    true
  end

  def persist_error(error)
    return unless contact

    contact.reload if contact.persisted?
    contact.update!(
      additional_attributes: (contact.additional_attributes || {}).merge(
        PROFILE_ATTRIBUTE_KEY => current_profile.merge(
          'source' => 'evolution',
          'synced_at' => Time.current.iso8601,
          'last_error' => "#{error.class}: #{error.message}"
        )
      )
    )
  rescue StandardError => e
    Rails.logger.warn("Whatsapp profile enrichment error persistence failed for contact #{contact&.id}: #{e.class} - #{e.message}")
  end

  def current_profile
    (contact.additional_attributes || {})[PROFILE_ATTRIBUTE_KEY] || {}
  end

  def group_contact?
    source_id.to_s.end_with?('@g.us')
  end

  def expected_profile_type
    group_contact? ? 'group' : 'contact'
  end

  def lid_contact?
    source_id.to_s.end_with?('@lid')
  end

  def source_id
    @source_id ||= source_id_candidates.min_by { |value| source_id_priority(value) }.to_s
  end

  def source_id_candidates
    [contact_inbox&.source_id, contact&.identifier, contact&.phone_number].map { |value| value.to_s.strip }.reject(&:blank?)
  end

  def source_id_priority(value)
    return 0 if whatsapp_jid?(value)
    return 1 if phone_like?(value)

    2
  end

  def whatsapp_jid?(value)
    value.end_with?('@g.us', '@lid', '@s.whatsapp.net')
  end

  def phone_like?(value)
    digits = value.gsub(/\D/, '')
    digits.length.between?(8, 15)
  end

  def client
    @client ||= EvolutionApi::ProfileClient.new
  end
end
# rubocop:enable Metrics/ClassLength
