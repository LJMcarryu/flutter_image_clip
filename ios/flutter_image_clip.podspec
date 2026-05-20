Pod::Spec.new do |s|
  s.name             = 'flutter_image_clip'
  s.version          = '0.7.3'
  s.summary          = 'Native decode helpers for flutter_image_clip.'
  s.description      = <<-DESC
Native sampled image decode and format normalization for flutter_image_clip.
                       DESC
  s.homepage         = 'https://github.com/LJMcarryu/flutter_image_clip'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'flutter_image_clip' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_image_clip/Sources/flutter_image_clip/**/*.swift'
  s.resource_bundles = {
    'flutter_image_clip_privacy' => ['flutter_image_clip/Sources/flutter_image_clip/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
