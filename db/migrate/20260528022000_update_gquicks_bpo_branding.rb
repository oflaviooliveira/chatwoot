class UpdateGquicksBpoBranding < ActiveRecord::Migration[7.1]
  BRANDING_CONFIG = {
    'INSTALLATION_NAME' => 'Gquicks BPO',
    'BRAND_NAME' => 'Gquicks BPO',
    'BRAND_URL' => 'https://gquicks.pro',
    'WIDGET_BRAND_URL' => 'https://gquicks.pro',
    'TERMS_URL' => 'https://gquicks.pro',
    'PRIVACY_URL' => 'https://gquicks.pro',
    'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
    'LOGO' => '/brand-assets/logo.svg',
    'LOGO_DARK' => '/brand-assets/logo_dark.svg',
    'DISPLAY_MANIFEST' => false
  }.freeze

  def up
    BRANDING_CONFIG.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.locked = true if config.locked.nil?
      config.save!
    end

    GlobalConfig.clear_cache
  end
end
