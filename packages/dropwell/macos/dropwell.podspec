#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint dropwell.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'dropwell'
  s.version          = '0.0.1'
  s.summary          = 'Native file drag-and-drop and clipboard file reading for Flutter.'
  s.description      = <<-DESC
Native file drag-and-drop and clipboard file reading for Flutter.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'dropwell/Sources/dropwell/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'dropwell_privacy' => ['dropwell/Sources/dropwell/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
