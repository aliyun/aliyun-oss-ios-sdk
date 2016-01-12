## 简介

本文档主要介绍OSS iOS SDK的安装和使用。本文档假设您已经开通了阿里云OSS 服务，并创建了Access Key ID 和Access Key Secret。文中的ID 指的是Access Key ID，KEY 指的是Access Key Secret。如果您还没有开通或者还不了解OSS，请登录[OSS产品主页](http://www.aliyun.com/product/oss)获取更多的帮助。

### 环境要求：
- iOS系统版本：iOS 7.0以上
- 必须注册有Aliyun.com用户账户，并开通OSS服务。

-----
## 安装

### 直接引入Framework

需要引入OSS iOS SDK framework。

您可以在MacOS系统中直接使用在本工程生成framwork：

```bash
# clone工程
$ git clone git@github.com:aliyun/aliyun-oss-ios-sdk.git

# 进入目录
$ cd aliyun-oss-ios-sdk

# 执行打包脚本
$ sh ./buildFramework.sh

# 进入打包生成目录，AliyunOSSiOS.framework生成在该目录下
$ cd Products && ls
```

在Xcode中，直接把framework拖入您对应的Target下即可，在弹出框勾选`Copy items if needed`。

### Pod依赖

如果工程是通过pod管理依赖，那么在Podfile中加入以下依赖即可，不需要再导入framework：

```
pod 'AliyunOSSiOS', '~> 2.1.4'
```

Cocoapods是一个非常优秀的依赖管理工具，推荐参考官方文档: [CocoaPods安装和使用教程](http://code4app.com/article/cocoapods-install-usage)。

直接引入Framework和Pod依赖，两种方式选其一即可。

### 工程中引入头文件

```objc
#import <AliyunOSSiOS/OSSService.h>
```

注意，引入Framework后，需要在工程`Build Settings`的`Other Linker Flags`中加入`-ObjC`。如果工程此前已经设置过`-force_load`选项，那么，需要加入`-force_load <framework path>/AliyunOSSiOS`。

### 对于OSSTask的一些说明

所有调用api的操作，都会立即获得一个OSSTask，如：

```
OSSTask * task = [client getObject:get];
```

可以为这个Task设置一个延续(continution)，以实现异步回调，如：

```
[task continueWithBlock: ^(OSSTask *task) {
	// do something
	...

	return nil;
}];
```

也可以等待这个Task完成，以实现同步等待，如：

```
[task waitUntilFinished];

...
```

-----
## 快速入门

以下演示了上传、下载文件的基本流程。更多细节用法可以参考本工程的：

test资源：[点击查看](https://github.com/aliyun/AliyunOSSiOS/tree/master/AliyunOSSiOSTests)

或者：

demo示例: [点击查看](https://github.com/alibaba/alicloud-ios-demo)。

### STEP-1. 初始化OSSClient

初始化主要完成Endpoint设置、鉴权方式设置、Client参数设置。其中，鉴权方式包含明文设置模式、自签名模式、STS鉴权模式。鉴权细节详见后面链接给出的官网完整文档的`访问控制`章节。

```objc
NSString *endpoint = "http://oss-cn-hangzhou.aliyuncs.com";

// 明文设置secret的方式建议只在测试时使用，更多鉴权模式参考后面链接给出的官网完整文档的`访问控制`章节
id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"<your accesskeyId>"
                                                                                                        secretKey:@"<your accessKeySecret>"];

client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credential];

```

### STEP-2. 上传文件

这里假设您已经在控制台上拥有自己的Bucket。SDK的所有操作，都会返回一个`OSSTask`，您可以为这个task设置一个延续动作，等待其异步完成，也可以通过调用`waitUntilFinished`阻塞等待其完成。

```objc
OSSPutObjectRequest * put = [OSSPutObjectRequest new];

put.bucketName = @"<bucketName>";
put.objectKey = @"<objectKey>";

put.uploadingData = <NSData *>; // 直接上传NSData

put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
	NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
};

OSSTask * putTask = [client putObject:put];

[putTask continueWithBlock:^id(OSSTask *task) {
	if (!task.error) {
		NSLog(@"upload object success!");
	} else {
		NSLog(@"upload object failed, error: %@" , task.error);
	}
	return nil;
}];

// 可以等待任务完成
// [putTask waitUntilFinished];

```

### STEP-3. 下载指定文件

下载一个指定`object`为`NSData`:

```objc
OSSGetObjectRequest * request = [OSSGetObjectRequest new];
request.bucketName = @"<bucketName>";
request.objectKey = @"<objectKey>";

request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
	NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
};

OSSTask * getTask = [client getObject:request];

[getTask continueWithBlock:^id(OSSTask *task) {
	if (!task.error) {
		NSLog(@"download object success!");
		OSSGetObjectResult * getResult = task.result;
		NSLog(@"download result: %@", getResult.downloadedData);
	} else {
		NSLog(@"download object failed, error: %@" ,task.error);
	}
	return nil;
}];

// 如果需要阻塞等待任务完成
// [task waitUntilFinished];

```

-----
## 完整文档

SDK提供进阶的上传、下载功能、断点续传，以及文件管理、Bucket管理等功能。详见官方完整文档：[点击查看](http://help.aliyun.com/document_detail/oss/sdk/ios-sdk/preface.html?spm=5176.product8314910_oss.4.30.tK2G02)

-----
## API文档

[点击查看](http://aliyun.github.io/aliyun-oss-ios-sdk/)

-----
## 联系我们

* 阿里云OSS官方网站：http://oss.aliyun.com
* 阿里云OSS官方论坛：http://bbs.aliyun.com
* 阿里云OSS官方文档中心：http://www.aliyun.com/product/oss#Docs
* 阿里云官方技术支持 登录OSS控制台 https://home.console.aliyun.com -> 点击"工单系统"

-----
## License

Copyright (c) 2015 Aliyun.Inc.

Licensed under the Apache License, Version 2.0 (the "License");

you may not use this file except in compliance with the License.

You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software

distributed under the License is distributed on an "AS IS" BASIS,

WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

See the License for the specific language governing permissions and

limitations under the License.
