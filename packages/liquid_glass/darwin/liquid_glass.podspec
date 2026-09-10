Pod::Spec.new do |s|
  s.name             = 'liquid_glass'
  s.version          = '0.5.0'
  s.summary          = 'Apple Liquid Glass as a Flutter platform view.'
  s.description      = <<-DESC
Liquid Glass (UIGlassEffect on iOS 26, NSGlassEffectView on macOS 26) as a
Flutter platform view, with a system blur fallback on older releases.
                       DESC
  s.homepage         = 'https://github.com/Project516/spectrumflutter-native'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Spectrum 3847' => 'project516@project516.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'liquid_glass/Sources/liquid_glass/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  # Deployment targets stay where the apps are. The glass classes need 26 and
  # every use of them is behind `#available`, so an older OS gets the blur
  # fallback instead of a missing symbol.
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
