# Aliyun OSS SDK for iOS

## [README of English](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/README.md)

## 关于 OSS SDK for iOS V2
>- OSS SDK for iOS V2([alibabacloud-oss-swift-sdk-v2](https://github.com/aliyun/alibabacloud-oss-swift-sdk-v2)) 测试版已发布, 是对V1（aliyun-oss-ios-sdk）代码库的重大改写。
>- V2是一个全新的版本，简化了底层操作例如身份验证、自动请求重试及错误处理等；提供了灵活友好的参数配置以及丰富的高级接口，例如分页器、传输管理器等，全面提升了开发效率和体验。


## 简介

本文档主要介绍OSS iOS SDK的安装和使用。本文档假设您已经开通了阿里云OSS 服务，并创建了Access Key ID 和Access Key Secret。文中的ID 指的是Access Key ID，KEY 指的是Access Key Secret。如果您还没有开通或者还不了解OSS，请登录[OSS产品主页](http://www.aliyun.com/product/oss)获取更多的帮助。

## 环境要求：
- iOS系统版本：iOS 8.0以上
- 必须注册有Aliyun.com用户账户，并开通OSS服务。

## 安装

### 直接引入Framework

需要引入OSS iOS SDK framework。

您可以在MacOS系统中直接使用本工程，选择对应的scheme为AliyunOSSSDK OSX，然后生成framwork：

```bash
# clone工程
$ git clone git@github.com:aliyun/aliyun-oss-ios-sdk.git

# 进入目录
$ cd aliyun-oss-ios-sdk

# 执行打包脚本
$ sh ./buildiOSFramework.sh

# 进入打包生成目录，AliyunOSSiOS.framework生成在该目录下
$ cd Products && ls
```

在Xcode中，直接把framework拖入您对应的Target下即可，在弹出框勾选`Copy items if needed`。

**注意：buildiOSFramework.sh脚本生成的framework是支持i386,x86_64,armv7,arm64架构的版本，所以当您需要archive product时，需要直接使用工程文件生成只支持真机的framework版本。**

### Pod依赖

如果工程是通过pod管理依赖，那么在Podfile中加入以下依赖即可，不需要再导入framework：

```
pod 'AliyunOSSiOS'
```

CocoaPods是一个非常优秀的依赖管理工具，推荐参考官方文档: [CocoaPods安装和使用教程](https://cocoapods.org/)。

直接引入Framework和Pod依赖，两种方式选其一即可。

### 工程中引入头文件

```objc
#import <AliyunOSSiOS/AliyunOSSiOS.h>
```

注意，引入Framework后，需要在工程`Build Settings`的`Other Linker Flags`中加入`-ObjC`。如果工程此前已经设置过`-force_load`选项，那么，需要加入`-force_load <framework path>/AliyunOSSiOS`。

### 兼容IPv6-Only网络

OSS移动端SDK为了解决无线网络下域名解析容易遭到劫持的问题，已经引入了HTTPDNS进行域名解析，直接使用IP请求OSS服务端。在IPv6-Only的网络下，可能会遇到兼容性问题。而APP官方近期发布了关于IPv6-only网络环境兼容的APP审核要求，为此，SDK从`2.5.0`版本开始已经做了兼容性处理。在新版本中，除了`-ObjC`的设置，还需要引入两个系统库：

```
libresolv.tbd
SystemConfiguration.framework
CoreTelephony.framework
```

### 关于苹果ATS政策

WWDC 2016开发者大会上，苹果宣布从2017年1月1日起，苹果App Store中的所有App都必须启用 App Transport Security(ATS) 安全功能。也就是说，所有的新提交 app 默认是不允许使用`NSAllowsArbitraryLoads`来绕过 ATS 限制的。我们最好保证 app 的所有网络请求都是 HTTPS 加密的，否则可能会在应用审核时遇到麻烦。

本SDK在`2.6.0`以上版本中对此做出支持，其中，SDK不会自行发出任何非HTTPS请求，同时，SDK支持`https://`前缀的`Endpoint`，只需要设置正确的HTTPS `Endpoint`，就能保证发出的网络请求都是符合要求的。

所以，用户需要注意：

* 设置`Endpoint`时，需要使用`https://`前缀的URL。
* 在实现加签、获取STSToken等回调时，需要确保自己不会发出 非HTTPS 的请求。

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
[task waitUntilFinished];	// 调用此方法时会阻塞当前线程直到task完成

...
```

## 快速入门

以下演示了上传、下载文件的基本流程。更多细节用法可以参考本工程的：

test资源：[点击查看](https://github.com/aliyun/AliyunOSSiOS/tree/master/AliyunOSSiOSTests)

或者：

demo示例: [点击查看](https://github.com/alibaba/alicloud-ios-demo)。

### STEP-1. 初始化OSSClient

在移动环境下，我们推荐STS鉴权模式来初始化OSSClient。鉴权细节详见后面链接给出的官网完整文档的`访问控制`章节。

**注意: 如果您的应用只用到一个[数据中心](https://help.aliyun.com/document_detail/31837.html)下的bucket,建议保持OSSClient实例与应用程序的生命周期一致(比如在Appdelegate.m的 - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions])中进行初始化，如下所示:**

```objc
@interface AppDelegate ()

@property (nonatomic, strong) OSSClient *client;

@end

/**
 * 获取sts信息的url,配置在业务方自己的搭建的服务器上。详情可见https://help.aliyun.com/document_detail/31920.html
 */
#define OSS_STS_URL                 @"oss_sts_url"


/**
 * bucket所在的region的endpoint,详情可见https://help.aliyun.com/document_detail/31837.html
 */
#define OSS_ENDPOINT                @"your bucket's endpoint"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    // 初始化OSSClient实例
    [self setupOSSClient];
    
    return YES;
}

- (void)setupOSSClient {

    // 初始化具有自动刷新的provider
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STS_URL];
    
    // client端的配置,如超时时间，开启dns解析等等
    OSSClientConfiguration *cfg = [[OSSClientConfiguration alloc] init];
    
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:credentialProvider clientConfiguration:cfg];
}

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

## 完整文档

SDK提供进阶的上传、下载功能、断点续传，以及文件管理、Bucket管理等功能。详见官方完整文档：[点击查看](https://help.aliyun.com/document_detail/32055.html)


## API文档

[点击查看](https://help.aliyun.com/document_detail/31947.html)

## 常见问题

1.工程编译出来的iOS库怎么没有支持armv7s的架构？

​	Xcode9中默认支持的架构是armv7/arm64,由于arm是向下兼容的，armv7的库在需要支持armv7s的app中也是适用的，如果仍然需要针对armv7s进行优化，那么需要如下图进行设置

![list1](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/Images/list1.png)

## License

* Apache License 2.0.

## 联系我们

* 阿里云OSS官方网站：http://oss.aliyun.com
* 阿里云OSS官方论坛：http://bbs.aliyun.com
* 阿里云OSS官方文档中心：http://www.aliyun.com/product/oss#Docs
* 阿里云官方技术支持 登录OSS控制台 https://home.console.aliyun.com -> 点击"工单系统"

