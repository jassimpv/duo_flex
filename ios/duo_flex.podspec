#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint duo_flex.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'duo_flex'
  s.version          = '0.1.0'
  s.summary          = 'Native iOS display and fold data with adaptive Flutter layouts.'
  s.description      = <<-DESC
Typed access to iOS device, application window, safe-area, display regions, and
public UIKit hinge information, with responsive Flutter layout widgets.
                       DESC
  s.homepage         = 'https://pub.dev/packages/duo_flex'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author            = 'DuoFlex contributors'
  s.source           = { :path => '.' }
  s.source_files = 'duo_flex/Sources/duo_flex/**/*.swift'
  s.dependency 'Flutter'
  s.ios.deployment_target = '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'duo_flex_privacy' => ['duo_flex/Sources/duo_flex/PrivacyInfo.xcprivacy']}
end
