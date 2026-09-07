#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint liquid_glass.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'liquid_glass'
  s.version          = '0.0.1'
  s.summary          = 'iOS 26 Liquid Glass as a Flutter platform view.'
  s.description      = <<-DESC
iOS 26 Liquid Glass as a Flutter platform view.
                       DESC
  s.homepage         = 'https://github.com/Project516/spectrumflutter-native'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Spectrum 3847' => 'project516@project516.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'liquid_glass/Sources/liquid_glass/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'liquid_glass_privacy' => ['liquid_glass/Sources/liquid_glass/PrivacyInfo.xcprivacy']}
end
