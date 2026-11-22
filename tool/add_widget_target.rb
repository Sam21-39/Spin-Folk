#!/usr/bin/env ruby
# One-shot and idempotent: wires the Phase 4 native files into
# ios/Runner.xcodeproj without the Xcode GUI.
#   - SpinfolkAttributes.swift, LiveActivityBridge.swift -> Runner
#   - new app-extension target SpinfolkWidget (SpinfolkLiveActivity.swift +
#     the shared SpinfolkAttributes.swift), embedded in Runner
# Run from the repo root:  ruby tool/add_widget_target.rb
require 'xcodeproj'

NAME = 'SpinfolkWidget'
project = Xcodeproj::Project.open(ARGV[0] || 'ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target missing'
if project.targets.any? { |t| t.name == NAME }
  puts "#{NAME} already present, nothing to do"
  exit 0
end

native = project.main_group['Runner']['Native'] or abort 'Runner/Native group missing'
ref = lambda do |group, file|
  group.files.find { |f| f.path == file } || group.new_file(file)
end
attributes = ref.call(native, 'SpinfolkAttributes.swift')
bridge = ref.call(native, 'LiveActivityBridge.swift')
compiled = runner.source_build_phase.files_references
runner.add_file_references([attributes, bridge].reject { |f| compiled.include?(f) })

# Target, built by hand: Project#new_target would add a Foundation.framework
# reference and a Resources phase this extension does not need.
widget = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
project.targets << widget
widget.name = NAME
widget.product_name = NAME
widget.product_type = Xcodeproj::Constants::PRODUCT_TYPE_UTI[:app_extension]
widget.product_reference = project.products_group.new_product_ref_for_target(NAME, :app_extension)
widget.build_phases << project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
widget.build_phases << project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)

# One configuration per Runner configuration (Debug, Release, Profile), on the
# same Flutter xcconfig so FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER resolve and
# the extension's version always equals the app's. No DEVELOPMENT_TEAM.
list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
list.default_configuration_is_visible = '0'
list.default_configuration_name = 'Release'
runner.build_configurations.each do |rc|
  c = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  c.name = rc.name
  c.base_configuration_reference = rc.base_configuration_reference
  c.build_settings = {
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => "#{NAME}/Info.plist",
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'
    ],
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'in.appamania.spinfolk.SpinfolkWidget',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
  }
  if rc.name == 'Debug'
    c.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    c.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
  end
  list.build_configurations << c
end
widget.build_configuration_list = list

group = project.main_group.new_group(NAME, NAME)
widget.add_file_references([group.new_file('SpinfolkLiveActivity.swift'), attributes])
group.new_file('Info.plist') # referenced by INFOPLIST_FILE, member of no phase

# Embed in Runner. The phase must sit before Flutter's "Thin Binary" script,
# otherwise Xcode reports "Cycle inside Runner".
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(widget.product_reference, true).settings = {
  'ATTRIBUTES' => ['RemoveHeadersOnCopy']
}
thin = runner.build_phases.index { |p| p.display_name == 'Thin Binary' } or abort 'Thin Binary phase missing'
runner.build_phases.move(embed, thin)
runner.add_dependency(widget)

project.save
puts "added #{NAME}; Runner phases: #{runner.build_phases.map(&:display_name).join(' > ')}"
