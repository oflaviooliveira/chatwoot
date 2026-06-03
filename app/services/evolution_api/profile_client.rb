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
      group: safe_post("/group/findGroupInfos/#{@instance_name}", groupJid: group_jid),
      profile_picture: safe_post("/chat/fetchProfilePictureUrl/#{@instance_name}", number: group_jid)
    }.compact
  end

  private

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
