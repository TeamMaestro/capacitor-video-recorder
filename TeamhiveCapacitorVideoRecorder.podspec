
  Pod::Spec.new do |s|
    s.name = 'TeamhiveCapacitorVideoRecorder'
    s.version = '0.3.10'
    s.summary = 'Records video'
    s.license = 'MIT'
    s.homepage = 'https://github.com/TeamHive/capacitor-video-recorder.git'
    s.author = 'Sean Bannigan'
    s.source = { :git => 'https://github.com/TeamHive/capacitor-video-recorder.git', :tag => s.version.to_s }
    s.source_files = 'ios/Plugin/Plugin/*.{swift,h,m,c,cc,mm,cpp}' ,'ios/Plugin/Plugin/**/*.{swift,h,m,c,cc,mm,cpp}'
    s.ios.deployment_target  = '10.0'
    s.dependency 'Capacitor'
  end
