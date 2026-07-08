class EvolutionApi::ProfileClient
  TIMEOUT = 10

  def initialize(api_url: ENV.fetch('EVOLUTION_API_URL', nil),
                 instance_name: ENV.fetch('EVOLUTION_INSTANCE_NAME', nil),
                 api_key: ENV.fetch('EVOLUTION_API_KEY', nil))
    @api_url = api_url.to_s.delete_suffix('/')
    @instance_name = instance_name
    @api_key = api_key
  end

  def configured?
    @api_url.present? && @instance_name.present? && @api_key.present?
  end

  def fetch_contact_profile(number)
    return {} if number.blank?

    {
      profile: safe_post("/chat/fetchProfile/#{@instance_name}", number: number),
      business_profile: safe_post("/chat/fetchBusinessProfile/#{@instance_name}", number: number),
      profile_picture: safe_post("/chat/fetchProfilePictureUrl/#{@instance_name}", number: number)
    }.compact
  end

  def fetch_group_profile(group_jid)
    return {} if group_jid.blank?

    {
      group: fetch_group_info(group_jid),
      profile_picture: safe_post("/chat/fetchProfilePictureUrl/#{@instance_name}", number: group_jid)
    }.compact
  end

  def fetch_group_participants(group_jid)
    return [] if group_jid.blank?

    normalize_group_participants(fetch_group_info(group_jid))
  end

  private

  def fetch_group_info(group_jid)
    safe_get("/group/findGroupInfos/#{@instance_name}", groupJid: group_jid)
  end

  def normalize_group_participants(payload)
    participants = extract_participants(unwrap_payload(payload))

    participants
      .filter_map { |participant| normalize_group_participant(participant) }
      .uniq { |participant| participant[:jid] }
      .sort_by { |participant| participant[:label].to_s.downcase }
  end

  def extract_participants(payload)
    return [] unless payload.is_a?(Hash)

    direct_participants = extract_first_array(payload, %w[participants Participants])
    return direct_participants if direct_participants.present?

    nested_group = extract_first_hash(payload, %w[group groupMetadata metadata])
    extract_participants(nested_group)
  end

  def normalize_group_participant(participant)
    payload = unwrap_payload(participant)
    return if payload.blank?

    jid = normalize_participant_jid(
      extract_first(payload, %w[phoneNumber jid participant remoteJid number id])
    )
    return if jid.blank? || jid.end_with?('@g.us')

    {
      jid: jid,
      label: participant_label(payload, jid),
      phone: participant_phone(jid),
      lid: normalize_lid(extract_first(payload, %w[id lid])),
      admin: extract_first(payload, %w[admin isAdmin])
    }.compact
  end

  def participant_label(payload, jid)
    extract_first(
      payload,
      %w[name pushName notify verifiedName displayName shortName]
    ) || participant_phone(jid) || jid
  end

  def participant_phone(jid)
    jid.to_s.split('@').first
  end

  def normalize_participant_jid(value)
    value = value.to_s.strip
    return if value.blank?
    return value if value.end_with?('@s.whatsapp.net', '@lid')

    digits = value.gsub(/\D/, '')
    return if digits.blank?

    "#{digits}@s.whatsapp.net"
  end

  def normalize_lid(value)
    value = value.to_s.strip
    return if value.blank?
    return unless value.end_with?('@lid')

    value
  end

  def extract_first(payload, keys)
    payload = unwrap_payload(payload)
    keys.lazy.map { |key| payload[key] || payload[key.to_sym] }.find(&:present?)
  end

  def extract_first_array(payload, keys)
    keys.lazy.map { |key| payload[key] || payload[key.to_sym] }
        .find { |value| value.is_a?(Array) }
  end

  def extract_first_hash(payload, keys)
    keys.lazy.map { |key| payload[key] || payload[key.to_sym] }
        .find { |value| value.is_a?(Hash) }
  end

  def unwrap_payload(payload)
    payload = parse_payload(payload)
    return {} unless payload.is_a?(Hash)

    data = payload['data'] || payload[:data]
    return unwrap_payload(data) if data.is_a?(Hash)

    payload
  end

  def parse_payload(payload)
    return safe_parse_json(payload) if payload.is_a?(String)

    payload
  end

  def safe_parse_json(payload)
    JSON.parse(payload)
  rescue JSON::ParserError
    {}
  end

  def safe_get(path, query)
    response = HTTParty.get(
      "#{@api_url}#{path}",
      headers: headers,
      query: query,
      timeout: TIMEOUT
    )
    return response.parsed_response if response.success?

    Rails.logger.warn("EvolutionApi::ProfileClient #{path} failed with #{response.code}: #{response.body}")
    nil
  rescue StandardError => e
    Rails.logger.warn("EvolutionApi::ProfileClient #{path} failed: #{e.class} - #{e.message}")
    nil
  end

  def safe_post(path, payload)
    response = HTTParty.post(
      "#{@api_url}#{path}",
      headers: headers,
      body: payload.to_json,
      timeout: TIMEOUT
    )
    return response.parsed_response if response.success?

    Rails.logger.warn("EvolutionApi::ProfileClient #{path} failed with #{response.code}: #{response.body}")
    nil
  rescue StandardError => e
    Rails.logger.warn("EvolutionApi::ProfileClient #{path} failed: #{e.class} - #{e.message}")
    nil
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'apikey' => @api_key
    }
  end
end
