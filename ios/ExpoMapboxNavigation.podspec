require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ExpoMapboxNavigation'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = { :ios => '14.0' }
  s.swift_version  = '5.9'
  s.source         = { git: 'https://github.com/BryanQuezada1910/expo-mapbox-navigation' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  if ENV['ExpoNavigationMapboxMapsVersion'] && !ENV['ExpoNavigationMapboxMapsVersion'].strip.empty? && ENV['ExpoNavigationMapboxMapsVersion'] != 'undefined'
    s.dependency 'MapboxMaps', ENV['ExpoNavigationMapboxMapsVersion']
  else
    s.dependency 'MapboxMaps'
  end
  s.dependency 'Turf', '~> 4.0.0'

  s.source_files = "**/*.{h,m,swift}"
  s.exclude_files = ["Frameworks/*.xcframework/**/*.h"]
  s.preserve_paths = [
    "Frameworks/*.xcframework",
    "**/*.h",
    "Frameworks/*.xcframework/**/*.h"
  ]

  s.vendored_frameworks=[
    'Frameworks/_MapboxNavigationHelpers.xcframework',
    'Frameworks/MapboxDirections.xcframework',
    'Frameworks/MapboxNavigationCore.xcframework',
    'Frameworks/MapboxNavigationNative.xcframework',
    'Frameworks/MapboxNavigationUIKit.xcframework',
  ]

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
    'OTHER_SWIFT_FLAGS' => '$(inherited)'
  }

end
