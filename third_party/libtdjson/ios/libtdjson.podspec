#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint libtdjson.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'libtdjson'
  s.version          = '0.0.1'
  s.summary          = 'TDLib JSON FFI integration for Flutter.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/up9cloud/flutter_libtdjson'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'up9cloud' => '8325632+up9cloud@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'flutter_libtdjson', '1.8.65'
  s.platform = :ios, '13.0'
  s.libraries = 'c++', 'z'

  s.ios.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -force_load "${PODS_ROOT}/flutter_libtdjson/libtdjson-static.xcframework/ios-arm64/libtdjson.a"',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited) -force_load "${PODS_ROOT}/flutter_libtdjson/libtdjson-static.xcframework/ios-arm64_x86_64-simulator/libtdjson.a"',
  }
  s.swift_version = '5.0'
end
