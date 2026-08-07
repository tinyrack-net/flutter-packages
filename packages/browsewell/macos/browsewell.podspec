#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint browsewell.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'browsewell'
  s.version          = '0.0.1'
  s.summary          = 'Trusted automation helpers for Browsewell.'
  s.description      = <<-DESC
Native input and capture support for Browsewell's macOS WKWebView backend.
                       DESC
  s.homepage         = 'https://github.com/tinyrack-net/flutter-packages'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tinyrack' => 'opensource@tinyrack.net' }

  s.source           = { :path => '.' }
  s.source_files = 'browsewell/Sources/browsewell/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'browsewell_privacy' => ['browsewell/Sources/browsewell/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
