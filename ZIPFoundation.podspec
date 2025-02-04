Pod::Spec.new do |s|
  s.name = 'ZIPFoundation'
  s.version = '0.9.9'
  s.license = 'MIT'
  s.summary = 'Effortless ZIP Handling in Swift'
  s.homepage = 'https://github.com/weichsel/ZIPFoundation'
  s.social_media_url = 'http://twitter.com/weichsel'
  s.authors = { 'Thomas Zoechling' => 'thomas@peakstep.com' }
  s.source = { :git => 'https://github.com/apptopia/ZIPFoundation.git', :tag => s.version }
  s.swift_version = '4.0'

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = 'Sources/ZIPFoundation/*.swift'
end
