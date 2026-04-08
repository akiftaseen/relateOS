require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
target = project.targets.find { |t| t.name == 'KeyboardExtension' }
raise 'KeyboardExtension target not found' unless target

target.product_name = 'KeyboardExtension'

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'KeyboardExtension'
  config.build_settings['EXECUTABLE_NAME'] = 'KeyboardExtension'
  config.build_settings['WRAPPER_EXTENSION'] = 'appex'
  config.build_settings['MACH_O_TYPE'] = 'mh_execute'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'KeyboardExtension/Info.plist'
end

project.save
puts 'KeyboardExtension build settings fixed.'
