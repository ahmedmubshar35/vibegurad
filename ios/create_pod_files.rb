#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

# Create Pods project if it doesn't exist
pods_project_path = 'Pods/Pods.xcodeproj'
if !File.exist?(pods_project_path)
  pods_project = Xcodeproj::Project.new(pods_project_path)
  pods_project.save
  puts "Created Pods.xcodeproj"
end

# Create Target Support Files directory structure
FileUtils.mkdir_p('Pods/Target Support Files/Pods-Runner')
FileUtils.mkdir_p('Pods/Target Support Files/Pods-RunnerTests')

# Create the missing xcfilelist files with proper content
files = {
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-input-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-output-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-input-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Debug-output-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Debug-input-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Debug-output-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Profile-input-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Profile-output-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Profile-input-files.xcfilelist' => '',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Profile-output-files.xcfilelist' => ''
}

files.each do |path, content|
  File.write(path, content)
  puts "Created: #{path}"
end

# Create xcconfig files
configs = {
  'Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig' => 'FRAMEWORK_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
HEADER_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
LIBRARY_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
OTHER_LDFLAGS = $(inherited) -framework "Flutter"
PODS_BUILD_DIR = ${BUILD_DIR}
PODS_CONFIGURATION_BUILD_DIR = ${PODS_BUILD_DIR}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)
USE_RECURSIVE_SCRIPT_INPUTS_IN_SCRIPT_PHASES = YES',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig' => 'FRAMEWORK_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
HEADER_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
LIBRARY_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
OTHER_LDFLAGS = $(inherited) -framework "Flutter"
PODS_BUILD_DIR = ${BUILD_DIR}
PODS_CONFIGURATION_BUILD_DIR = ${PODS_BUILD_DIR}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)
USE_RECURSIVE_SCRIPT_INPUTS_IN_SCRIPT_PHASES = YES',
  'Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig' => 'FRAMEWORK_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
HEADER_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
LIBRARY_SEARCH_PATHS = $(inherited) "${PODS_CONFIGURATION_BUILD_DIR}"
OTHER_LDFLAGS = $(inherited) -framework "Flutter"
PODS_BUILD_DIR = ${BUILD_DIR}
PODS_CONFIGURATION_BUILD_DIR = ${PODS_BUILD_DIR}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)
USE_RECURSIVE_SCRIPT_INPUTS_IN_SCRIPT_PHASES = YES'
}

configs.each do |path, content|
  File.write(path, content)
  puts "Created: #{path}"
end

puts "All files created successfully!"