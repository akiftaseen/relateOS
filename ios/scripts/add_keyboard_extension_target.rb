require 'xcodeproj'

project_path = File.expand_path('../Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner_target

existing = project.targets.find { |t| t.name == 'KeyboardExtension' }
if existing
  puts 'KeyboardExtension target already exists; skipping target creation.'
  project.save
  exit 0
end

# Ensure group exists
keyboard_group = project.main_group.find_subpath('KeyboardExtension', true)
keyboard_group.set_source_tree('SOURCE_ROOT')

# Add source and plist files
kb_swift_path = 'KeyboardExtension/KeyboardViewController.swift'
kb_info_path = 'KeyboardExtension/Info.plist'
kb_entitlements_path = 'KeyboardExtension/KeyboardExtension.entitlements'

kb_swift_ref = keyboard_group.files.find { |f| f.path == 'KeyboardViewController.swift' } || keyboard_group.new_file(kb_swift_path)
kb_info_ref = keyboard_group.files.find { |f| f.path == 'Info.plist' } || keyboard_group.new_file(kb_info_path)
kb_entitlements_ref = keyboard_group.files.find { |f| f.path == 'KeyboardExtension.entitlements' } || keyboard_group.new_file(kb_entitlements_path)

# Create app extension target
target = project.new_target(:app_extension, 'KeyboardExtension', :ios, '13.0')

# Build phase: add swift file
target.source_build_phase.add_file_reference(kb_swift_ref, true)

# Set build settings for extension
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.akiftaseen.relateos.KeyboardExtension'
  config.build_settings['INFOPLIST_FILE'] = kb_info_path
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = kb_entitlements_path
  config.build_settings['DEVELOPMENT_TEAM'] = '52B4D6Y598'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

# Configure Runner entitlements for App Group
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  config.build_settings['DEVELOPMENT_TEAM'] = '52B4D6Y598'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

# Embed extension into Runner (PlugIns)
frameworks_phase = runner_target.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plugins }
unless frameworks_phase
  frameworks_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  frameworks_phase.name = 'Embed App Extensions'
  frameworks_phase.dst_subfolder_spec = '13'
  runner_target.build_phases << frameworks_phase
end

frameworks_phase.add_file_reference(target.product_reference, true)

project.save
puts 'KeyboardExtension target created and embedded successfully.'
