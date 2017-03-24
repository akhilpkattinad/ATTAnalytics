Pod::Spec.new do |s|  
    s.name              = 'CantizAnalytics'
    s.version           = '0.0.3'
    s.summary           = 'A really cool SDK for simplifying the use of differnet analytics.'
    s.homepage          = 'https://github.com/akhilpkattinad/ATTAnalytics'

    s.author            = { 'Sreekanth' => 'akhil.pk@attinadsoftware.com' }
    s.license           = { :type => 'Apache-2.0', :file => 'LICENSE' }

    s.platform          = :ios
    s.source            = { :git => 'https://github.com/akhilpkattinad/ATTAnalytics.git', :tag => s.version.to_s }

    s.ios.deployment_target = '8.0'
    s.ios.vendored_frameworks = 'ATTAnalytics.framework'
    s.ios.resources = 'ATTBackends.bundle'
    s.ios.framework  = ['CoreLocation', 'CoreData', 'CoreTelephony', 'SystemConfiguration']

end 