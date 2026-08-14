require 'xcodeproj'

project_path = '/Users/fox/Documents/PROJECTS/M5/UltimateLLMStudio/UltimateLLMStudio.xcodeproj'
project = Xcodeproj::Project.new(project_path)

target = project.new_target(:application, 'UltimateLLMStudio', :osx)
group = project.main_group.new_group('Sources', '.')

['App.swift', 'ContentView.swift', 'BackendManager.swift', 'M5Ultimate-Bridging-Header.h', 'M5UltimateWrapper.h', 'M5UltimateWrapper.mm'].each do |file|
  file_ref = group.new_file(file)
  if file.end_with?('.swift') || file.end_with?('.mm')
    target.add_file_references([file_ref])
  end
end

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.fox.ultimatellmstudio'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'M5Ultimate-Bridging-Header.h'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'NO'
end

project.save
puts "[+] Xcode project generated successfully"
