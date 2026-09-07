#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint apple_web_auth.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'apple_web_auth'
  s.version          = '0.0.1'
  s.summary          = 'ASWebAuthenticationSession as a Flutter OAuth redirect listener.'
  s.description      = <<-DESC
Runs an OAuth authorization request in ASWebAuthenticationSession and returns
the callback URL, so a native app can sign in to a third-party service
without a loopback web server.
                       DESC
  s.homepage         = 'https://github.com/Project516/spectrumflutter-native'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Spectrum 3847' => 'project516@project516.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'apple_web_auth/Sources/apple_web_auth/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
