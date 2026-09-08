#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint apple_ai.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'apple_ai'
  s.version          = '0.1.0'
  s.summary          = "Apple's on-device foundation model as a Flutter text generator."
  s.description      = <<-DESC
Apple's on-device foundation model (Apple Intelligence) as a Flutter text
generator, on iOS 26 and macOS 26.
                       DESC
  s.homepage         = 'https://github.com/Project516/spectrumflutter-native'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Spectrum 3847' => 'project516@project516.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'apple_ai/Sources/apple_ai/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  # Deployment targets stay where the apps are. FoundationModels needs 26, and
  # every call into it is behind `#available`, so an older OS gets the
  # unavailable answer instead of a missing symbol.
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
