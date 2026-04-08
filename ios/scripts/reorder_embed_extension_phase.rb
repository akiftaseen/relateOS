require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

phase = runner.build_phases.find { |bp| bp.isa == 'PBXCopyFilesBuildPhase' && bp.name == 'Embed App Extensions' }
raise 'Embed App Extensions phase not found' unless phase

runner.build_phases.delete(phase)

# Insert right after Resources (before Embed Frameworks / Thin Binary scripts)
resources_index = runner.build_phases.index { |bp| bp.isa == 'PBXResourcesBuildPhase' }
insert_index = resources_index ? resources_index + 1 : runner.build_phases.length
runner.build_phases.insert(insert_index, phase)

project.save
puts "Moved 'Embed App Extensions' to index #{insert_index}."
