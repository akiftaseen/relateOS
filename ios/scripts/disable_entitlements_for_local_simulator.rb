require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')

%w[Runner KeyboardExtension].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target

  target.build_configurations.each do |config|
    config.build_settings.delete('CODE_SIGN_ENTITLEMENTS')
  end
end

project.save
puts 'Removed CODE_SIGN_ENTITLEMENTS from Runner and KeyboardExtension for local simulator testing.'
