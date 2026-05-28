class UpdateGquicksHubAtendimentoWebBranding < ActiveRecord::Migration[7.1]
  BRANDING_NAME = 'Gquicks HUB - Atendimento Web'.freeze

  def up
    {
      'INSTALLATION_NAME' => BRANDING_NAME,
      'BRAND_NAME' => BRANDING_NAME,
      'BRAND_URL' => 'https://gquicks.pro',
      'WIDGET_BRAND_URL' => 'https://gquicks.pro',
      'TERMS_URL' => 'https://gquicks.pro',
      'PRIVACY_URL' => 'https://gquicks.pro',
      'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
      'LOGO' => '/brand-assets/logo.svg',
      'LOGO_DARK' => '/brand-assets/logo_dark.svg',
      'DISPLAY_MANIFEST' => false
    }.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.locked = true if config.locked.nil?
      config.save!
    end

    GlobalConfig.clear_cache
  end
end
