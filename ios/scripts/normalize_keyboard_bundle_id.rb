require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
target = project.targets.find { |t| t.name == 'KeyboardExtension' }
raise 'KeyboardExtension target not found' unless target

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.akiftaseen.relateos.keyboard'
end

project.save
puts 'KeyboardExtension bundle id normalized to lowercase.'
