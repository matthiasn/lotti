Pod::Spec.new do |s|
  s.name             = 'sqlite_vec'
  s.version          = '0.1.0'
  s.summary          = 'sqlite-vec FFI plugin for Flutter (macOS).'
  s.homepage         = 'https://github.com/asg017/sqlite-vec'
  s.license          = { :type => 'MIT' }
  s.author           = { 'sqlite-vec' => 'https://github.com/asg017/sqlite-vec' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.osx.deployment_target = '10.14'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_CFLAGS' => '-O3 -DSQLITE_VEC_ENABLE_NEON',
  }
end
