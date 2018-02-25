# Alibaba Cloud OSS SDK for iOS

## [README of Chinese](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/README-CN.md)

## Introduction

This document mainly describes how to install and use the OSS iOS SDK. This document assumes that you have already activated the Alibaba Cloud OSS service and created an *AccessKeyID* and an *AccessKeySecret*. In the document, *ID* refers to the *AccessKeyID* and *KEY* indicates the *AccessKeySecret*. If you have not yet activated or do not know about the OSS service, log on to the [OSS Product Homepage](http://www.aliyun.com/product/oss) for more help.

## Environment requirements
- iOS ***8.0*** or above. 
- You must have registered an Alibaba Cloud account with the OSS activated.

## Installation

### Introduce framework directly

The OSS iOS SDK framework needs to be introduced.

You can use this project to directly generate a framework in MacOS : 

```bash
# Clone the project
$ git clone git@github.com:aliyun/aliyun-oss-ios-sdk.git

# Enter the directory
$ cd aliyun-oss-ios-sdk

# Run the packaging script
$ sh ./buildFramework.sh

# Enter the generated packaging directory  where the AliyunOSSiOS.framework will be generated
$ cd Products && ls
```

In Xcode, drag the OSS iOS SDK framework and drop it to your target, and select *Copy items if needed* in the pop-up box.

### Pod dependency

If your project manages dependencies using a Pod, add the following dependency to the Podfile. In this case, you do not need to import the OSS iOS SDK framework.

```
pod 'AliyunOSSiOS', '~> 2.9.0'
```

CocoaPods is an outstanding dependency manager. Recommended official reference documents: [CocoaPods Installation and Usage Tutorial]((http://code4app.com/article/cocoapods-install-usage)).

You can directly introduce the OSS iOS SDK framework or the Pod dependency, either way works.

### Introduce the header file to the project

```objc
#import <AliyunOSSiOS/AliyunOSSiOS.h>
```

**Note:** After you introduce the OSS iOS SDK framework, add `-ObjC` to *Other Linker Flags* of *Build Settings* in your project. If the `-force_load` option has been configured for your project, add `-force_load <framework path>/AliyunOSSiOS`.

### Compatible with IPv6-Only networks

The OSS mobile SDK has introduced the *HTTPDNS* for domain name resolution to solve the problem of domain resolution hijacking in a wireless network and directly uses IP addresses for requests to the server. In the IPv6-Only network, compatibility issues may occur. The app has officially issued the review requirements for apps, requiring apps to be IPv6-only network compatible. To this end, the SDK starts to be compatible from ***V2.5.0***. In the new version, apart from `-ObjC` settings, two system libraries should be introduced:

```
libresolv.tbd
SystemConfiguration.framework
CoreTelephony.framework
```

### The ATS policy of Apple

At the WWDC 2016, Apple announced that starting January 1, 2017, all the apps in Apple App Store must enable App Transport Security (ATS). That is to say, all newly submitted apps are not allowed to use `NSAllowsArbitraryLoads` to bypass the ATS limitation by default. We'd better ensure that all network requests of the app are HTTPS-encrypted. Otherwise the app may have troubles to pass the review.

This SDK provides the support in ***V2.6.0*** and above. Specifically, the SDK will not issue any non-HTTPS requests. At the same time, the SDK supports *endpoint* with the `https://` prefix. You only need to set the correct HTTPS *endpoint* to ensure that all network requests comply with the requirements.

**Note:**
* Use a URL with the `https://` prefix for setting the *endpoint*.
* Ensure that the app will not send non-HTTPS requests when *implementing signing* and *getting STSToken callbacks*.

### Descriptions of OSSTask

You will get an *OSSTask* immediately for all operations that call APIs:

```
OSSTask * task = [client getObject:get];
```

You can configure a continuation for the *task* to achieve asynchronous callback. For example, 
```
[task continueWithBlock: ^(OSSTask *task) {
	// do something
	...

	return nil;
}];
```

You can also wait till the *task* is finished (synchronous wait). For example, 

```
[task waitUntilFinished];

...
```

## Quick start

The basic object upload and download processes are demonstrated below. For details, you can refer to the following directories of this project:

*test*: [Click to view details](https://github.com/aliyun/AliyunOSSiOS/tree/master/AliyunOSSiOSTests); 

or

*demo*: [click to view details](https://github.com/alibaba/alicloud-ios-demo).

### Step-1. Initialize the OSSClient

We recommend STS authentication mode to initialize the OSSClient on mobile. For details about authentication, refer to the *Access Control* section in the complete official documentation provided in the following link.

```objc
NSString *endpoint = @"oss-cn-hangzhou.aliyuncs.com";

id<OSSCredentialProvider> credential = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"<StsToken.AccessKeyId>" secretKeyId:@"<StsToken.SecretKeyId>" securityToken:@"<StsToken.SecurityToken>"];

client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credential];

```

### Step-2. Upload a file

Suppose that you have a bucket in the OSS console. An *OSSTask* will be returned after each SDK operation. You can configure a continuation for the task to achieve asynchronous callback. You can also use the *waitUntilFinished* to block other requests and wait until the task is finished.

```objc
OSSPutObjectRequest * put = [OSSPutObjectRequest new];

put.bucketName = @"<bucketName>";
put.objectKey = @"<objectKey>";

put.uploadingData = <NSData *>; // Directly upload NSData

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

// Wait until the task is finished
// [putTask waitUntilFinished];

```

### Step-3. Download a specified object

The following code downloads a specified *object* as *NSData*:

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

// Use a blocking call to wait until the task is finished
// [task waitUntilFinished];

```

## Complete documentation

The SDK provides advanced upload, download, resumable upload/download, object management and bucket management features. For details, see the complete official documentation: [click to view details](http://help.aliyun.com/document_detail/oss/sdk/ios-sdk/preface.html?spm=5176.product8314910_oss.4.30.tK2G02). 

## API documentation

[Click to view details](http://aliyun.github.io/aliyun-oss-ios-sdk/).

## F&Q

1.how to support armv7s？

​arm is backward compatible, armv7 library is also suitable for app that needs to support armv7s. 
 If you still need to optimize armv7s, you could set up as shown below.

![list1](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/Images/list1.png)

## License

* Apache License 2.0.

## Contact us

* [Alibaba Cloud OSS official website](http://oss.aliyun.com).
* [Alibaba Cloud OSS official forum](http://bbs.aliyun.com).
* [Alibaba Cloud OSS official documentation center](http://www.aliyun.com/product/oss#Docs).
* Alibaba Cloud official technical support: [Submit a ticket](https://workorder.console.aliyun.com/#/ticket/createIndex).
