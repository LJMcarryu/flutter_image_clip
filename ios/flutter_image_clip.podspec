Pod::Spec.new do |s|
  s.name             = 'flutter_image_clip'
  s.version          = '0.7.0'
  s.summary          = 'Native decode helpers for flutter_image_clip.'
  s.description      = <<-DESC
Native sampled image decode and format normalization for flutter_image_clip.
                       DESC
  s.homepage         = 'https://github.com/LJMcarryu/flutter_image_clip'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_image_clip' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.resource_bundles = {
    'flutter_image_clip_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
