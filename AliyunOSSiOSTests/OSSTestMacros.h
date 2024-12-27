//
//  OSSTestMacros.h
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/12/11.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#ifndef OSSTestMacros_h
#define OSSTestMacros_h

#define OSS_ACCESSKEY_ID                @"AccessKeyID"                              // 子账号id
#define OSS_SECRETKEY_ID                @"AccessKeySecret"                          // 子账号secret

#define OSS_BUCKET_PUBLIC               @"public-bucket"                            // bucket名称
#define OSS_BUCKET_PRIVATE              @"private-bucket"                           // bucket名称
#define OSS_ENDPOINT                    @"http://oss-cn-region.aliyuncs.com"      // 访问的阿里云endpoint
#define OSS_IMG_ENDPOINT                @"http://img-cn-region.aliyuncs.com"      // 旧版本图片服务的endpoint
#define OSS_REGION                      @"cn-hangzhou"
#define OSS_MULTIPART_UPLOADKEY         @"multipart_key"                            // 分片上传的object key
#define OSS_RESUMABLE_UPLOADKEY         @"resumable_key"                            // 断点续传的object key
#define OSS_CALLBACK_URL                @"http://oss-demo.aliyuncs.com:23450"       // 对象上传成功时回调的业务服务器地址
#define OSS_CNAME_URL                   @"http://www.cnametest.com/"                // cname，用于替换bucket.endpoint的访问域名
#define OSS_STSTOKEN_URL                @"http://*.*.*.*:****/sts/getsts"           // sts授权服务器的地址
#define OSS_IMAGE_KEY                   @"testImage.png"                            // 测试图片的名称

#define OSS_DOWNLOAD_FILE_NAME          @"OSS_DOWNLOAD_FILE_NAME"                   // 用于下载的object key

#endif /* OSSTestMacros_h */
