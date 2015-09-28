Pod::Spec.new do |s|

  s.name         = "AliyunOSSiOS"

  s.version      = "2.0.2"

  s.summary      = "An iOS SDK for Aliyun Object Storage Service"

  s.description  = <<-DESC
                   It's an SDK for aliyun object storage service, which implement by Objective-C.It helps the iOS developers to access the OSS easier.
                   DESC

  s.homepage     = "https://github.com/aliyun/AliyunOSSiOS"

  s.license      = "Apache License, Version 2.0"

  s.authors      = { "Aliyun Open Service" => "aliyuncloudcomputing" }

  s.source       = { :git => "https://github.com/aliyun/aliyun-oss-ios-sdk.git", :tag => "release_" + s.version.to_s }

  s.requires_arc = true

  s.ios.deployment_target = '7.0'

  s.source_files = 'AliyunOSSiOS/*.{h,m}', 'AliyunOSSiOS/httpdns/*.{h,m}'

  s.dependency 'Bolts'

end
