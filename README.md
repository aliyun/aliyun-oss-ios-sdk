阿里云计算开放服务软件开发工具包iOS版
Aliyun Open Services SDK for iOS

版权所有 （C）阿里云计算有限公司

Copyright (C) Alibaba Cloud Computing
All rights reserved.

http://www.aliyun.com

环境要求：
- iOS系统版本：iOS 7.0以上
- 必须注册有Aliyun.com用户账户，并开通相应的服务（如OTS、OSS等）。


## 简介

本文档主要介绍OSS iOS SDK的安装和使用。本文档假设您已经开通了阿里云OSS 服务，并创建了Access Key ID 和Access Key Secret。文中的ID 指的是Access Key ID，KEY 指的是Access Key Secret。如果您还没有开通或者还不了解OSS，请登录OSS产品主页获取更多的帮助。

## 安装

SDK依赖了以下三方库：

* [Bolts](https://github.com/BoltsFramework/Bolts-iOS)

### 直接引入Framework

需要引入OSS iOS SDK 和 Bolts 两个framework。

clone工程到本地，执行./release.sh，即可得到OSS-iOS-SDK.Framework。

选中您的工程 -> TARGETS -> 您的项目 -> General -> Linked Frameworks and Libraries -> 点击"+" -> add other -> framework所在的目录 -> 选中framework文件 -> open

### Pod依赖

暂不支持pod依赖方式，后续会改进，当前也可以直接引入源码到工程。

## 工程中引入头文件

```
#import <AliyunOSSiOS/OSSService.h>
```

## 快速入门

以下演示了上传、下载文件的基本流程。

### STEP-1. 初始化OSSClient

初始化主要完成Endpoint设置、鉴权方式设置、Client参数设置。其中，鉴权方式包含明文设置模式、自签名模式、Federation鉴权模式。

```
NSString *endpoint = "oss-cn-hangzhou.aliyuncs.com";

// 明文设置secret的方式建议只在测试时使用，更多鉴权模式请参考后面的`OSSClient`章节
id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"<your accesskey"
                                                                                                        secretKey:@"<your secretKey"];

client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credential];

```

### STEP-2. 上传文件

这里假设您已经在控制台上拥有自己的bucket。SDK的所有操作，都会返回一个`BFTask`，您可以为这个task设置一个延续动作，等待其异步完成，也可以通过调用`waitUntilFinished`阻塞等待其完成。

```
OSSPutObjectRequest * put = [OSSPutObjectRequest new];

put.bucketName = @"<bucketName>";
put.objectKey = @"<objectKey>";

// 从文件上传
put.uploadingFileURL = [NSURL fileURLWithPath:@"<filepath>"];

// put.uploadingData = ...; // 直接上传NSData

put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
	NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
};

BFTask * putTask = [client putObject:put];

[putTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		NSLog(@"upload object success!");
	} else {
		NSLog(@"upload object failed, error: %@" , task.error);
	}
	return nil;
}];

// 可以等待任务完成
// [putTask waitUntilFinished];

// 可以取消
// [put cancel];
```

### STEP-3. 罗列Bucket中的文件

完成上传以后，可能需要查看某个Bucket中有哪些object:

```
OSSGetBucketRequest * getBucket = [OSSGetBucketRequest new];
getBucket.bucketName = @"<bucketName>";
getBucket.marker = @"";
getBucket.prefix = @"";
getBucket.delimiter = @"";
getBucket.maxKeys = 100;

BFTask * getBucketTask = [client getBucket:getBucket];

[getBucketTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		OSSGetBucketResult * result = task.result;
		NSLog(@"get bucket success!");
		for (NSDictionary * objectInfo in result.contents) {
			NSLog(@"list object: %@", objectInfo);
		}
	} else {
		NSLog(@"get bucket failed, error: %@", task.error);
	}
	return nil;
}];

// 如果需要阻塞等待任务完成
// [task waitUntilFinished];
```

### STEP-4. 下载指定文件

可以下载一个指定`object`，并指定是下载为文件，还是下载为`NSData`:

```
OSSGetObjectRequest * request = [OSSGetObjectRequest new];
// required
request.bucketName = @"<bucketName>";
request.objectKey = @"<objectKey>";

//optional
request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
	NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
};

// request.downloadToFileURL = [NSURL fileURLWithPath:@"<filepath>"];

BFTask * getTask = [client getObject:request];

[getTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		NSLog(@"download object success!");
		OSSGetObjectResult * getResult = task.result; // 如果设置下载到文件这里result.downloadedData会为nil
		NSLog(@"download result: %@", getResult.dowloadedData);
	} else {
		NSLog(@"download object failed, error: %@" ,task.error);
	}
	return nil;
}];

// 如果需要阻塞等待任务完成
// [task waitUntilFinished];

// 如果需要取消任务
// [request cancel];
```

## OSSClient

OSSClient是OSS服务的iOS客户端，它为调用者提供了一系列的方法，用于和OSS服务进行交互。

在`快速入门`章节中，初始化OSSClient使用了明文设置密码的方式，这种方式安全性极差，是不适合线上环境的。因此SDK提供了另外两种鉴权方式：自实现签名和Federation鉴权。

### 自实现签名模式

自签名模式是指，您需要实现一个回调，这个回调需要按照OSS规定的签名算法，对一串字符内容进行加签，然后返回这个签名。下面演示了如何直接调用SDK的工具函数进行签名，但实际应用中，建议您把这串内容POST到您的业务服务器，由业务服务器加签并返回签名结果：

```
id<OSSCredentialProvider> credential = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
    // 您需要在这里依照OSS规定的签名算法，实现加签一串字符内容，并把得到的签名传拼接上Accesskey后返回
    // 一般实现是，将字符内容post到您的业务服务器，然后返回签名
    // 如果因为某种原因加签失败，描述error信息后，返回nil

    NSString *signature = [OSSUtil calBase64Sha1WithData:contentToSign withSecret:@"<your secret key>"]; // 这里是用SDK内的工具函数进行本地加签，建议您通过业务server实现远程加签
    if (signature != nil) {
        *error = nil;
    } else {
        *error = [NSError errorWithDomain:@"<your domain>" code:-1001 userInfo:@"<your error info>"];
        return nil;
    }
    return [NSString stringWithFormat:@"OSS %@:%@", @"<your access key>", signature];
}];
```


### Federation鉴权模式

Federation鉴权模式是指，您需要实现一个回调，这个回调通过您实现的方式去获取一个Federation Token，然后返回。SDK会利用这个Token来进行加签处理，并在需要更新时主动调用这个回调获取Token。

```
id<OSSCredentialProvider> credential = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
    // 您需要在这里实现获取一个FederationToken，并构造成OSSFederationToken对象返回
    // 如果因为某种原因获取失败，可直接返回nil

    OSSFederationToken * token;
    // 下面是一些获取token的代码，比如从您的server获取
    ...
    return token;
}];
```

### 设置本地参数

可以在初始化时设置一些本地参数:

```
OSSClientConfiguration * conf = [OSSClientConfiguration new];
conf.maxRetryCount = 3;
conf.enableBackgroundTransmitService = true;
conf.timeoutIntervalForRequest = 15;
conf.timeoutIntervalForResource = 24 * 60 * 60;

client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credential clientConfiguration:conf];
```

## Bucket

### 创建bucket

```
OSSCreateBucketRequest * create = [OSSCreateBucketRequest new];
create.bucketName = @"<bucketName>";
create.xOssACL = @"public-read";
create.location = @"oss-cn-hangzhou";

BFTask * createTask = [client createBucket:create];

[createTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		NSLog(@"create bucket success!");
	} else {
		NSLog(@"create bucket failed, error: %@", task.error);
	}
	return nil;
}];
```

### 罗列bucket

```
OSSGetBucketRequest * getBucket = [OSSGetBucketRequest new];
getBucket.bucketName = @"<bucketName>";
// getBucket.marker = @"";
// getBucket.prefix = @"";
// getBucket.delimiter = @"";
// getBucket.maxKeys = 100;

BFTask * getBucketTask = [client getBucket:getBucket];

[getBucketTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		OSSGetBucketResult * result = task.result;
		NSLog(@"get bucket success!");
		for (NSDictionary * objectInfo in result.contents) {
			NSLog(@"list object: %@", objectInfo);
		}
	} else {
		NSLog(@"get bucket failed, error: %@", task.error);
	}
	return nil;
}];
```

### 删除bucket

```
OSSDeleteBucketRequest * delete = [OSSDeleteBucketRequest new];
delete.bucketName = @"<bucketName>";

BFTask * deleteTask = [client deleteBucket:delete];

[deleteTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		NSLog(@"delete bucket success!");
	} else {
		NSLog(@"delete bucket failed, error: %@", task.error);
	}
	return nil;
}];
```

## 对于BFTask的一些说明

SDK主要使用了Bolts库中的BFTask。所有调用api的操作，都会立即获得一个BFTask，如：

```
BFTask * task = [client getObject:get];
```

可以为这个Task设置一个延续(continution)，以实现异步回调，如：

```
[task continueWithBlock: ^(BFTask *task) {
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

更多用法参考：[Bolts](https://github.com/BoltsFramework/Bolts-iOS)


## Object


在OSS中，用户操作的基本数据单元是Object。单个Object最大允许大小根据上传数据方式不同而不同,Put Object方式最大不能超过5GB, 使用multipart上传方式object大小不能超过48.8TB。Object包含key、meta和data。其中，key是Object的名字；meta是用户对该object的描述，由一系列name-value对组成；data是Object的数据。

### 命名规范

Object的命名规范如下：

* 使用UTF-8编码
* 长度必须在1-1023字节之间
* 不能以“/”或者“\”字符开头
* 不能含有“\r”或者“\n”的换行符

### 上传文件

上传数据可以直接上传OSSData，或者通过NSURL上传一个文件;

```
OSSPutObjectRequest * put = [OSSPutObjectRequest new];

// required fields
put.bucketName = @"<bucketName>";
put.objectKey = @"<objectKey>";
NSString * docDir = [self getDocumentDirectory];
put.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];

// optional fields
put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
	NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
};
put.contentType = @"";
put.contentMd5 = @"";
put.contentEncoding = @"";
put.contentDisposition = @"";

BFTask * putTask = [client putObject:put];

[putTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		NSLog(@"upload object success!");
	} else {
		NSLog(@"upload object failed, error: %@" , task.error);
	}
	return nil;
}];

// [putTask waitUntilFinished];

// [put cancel];
```

### 下载文件

下载数据可以直接下载为OSSData，或者存储为NSURL指定的一个文件;

```
OSSGetObjectRequest * request = [OSSGetObjectRequest new];
// required
request.bucketName = @"<bucketName>";
request.objectKey = @"<objectKey>";

//optional
request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
	NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
};

// request.downloadToFileURL = [NSURL fileURLWithPath:@"<filepath>"];

BFTask * getTask = [client getObject:request];

[getTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		NSLog(@"download object success!");
		OSSGetObjectResult * getResult = task.result;
		NSLog(@"download result: %@", getResult.dowloadedData);
	} else {
		NSLog(@"download object failed, error: %@" ,task.error);
	}
	return nil;
}];

// [getTask waitUntilFinished];

// [request cancel];
```

### 删除文件

删除指定文件：

```
OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
delete.bucketName = @"<bucketName>";
delete.objectKey = @"<objectKey>";

BFTask * deleteTask = [client deleteObject:delete];

[deleteTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		// ...
	}
	return nil;
}];

// [deleteTask waitUntilFinished];
```

## 分块上传

下面演示通过分块上传文件的整个流程：

### 初始化分块上传

```
__block NSString * uploadId = nil;
__block NSMutableArray * partInfos = [NSMutableArray new];

NSString * uploadToBucket = @"<bucketName>";
NSString * uploadObjectkey = @"<objectKey>";

OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
init.bucketName = uploadToBucket;
init.objectKey = uploadObjectkey;
init.contentType = @"application/octet-stream";

BFTask * initTask = [client multipartUploadInit:init];

[initTask waitUntilFinished];

if (!initTask.error) {
	OSSInitMultipartUploadResult * result = initTask.result;
	uploadId = result.uploadId;
} else {
	NSLog(@"multipart upload failed, error: %@", initTask.error);
	return;
}
```

### 上传分块

```
for (int i = 1; i <= 3; i++) {
	OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
	uploadPart.bucketName = uploadToBucket;
	uploadPart.objectkey = uploadObjectkey;
	uploadPart.uploadId = uploadId;
	uploadPart.partNumber = i; // part number start from 1

	NSString * docDir = [self getDocumentDirectory];
	uploadPart.uploadPartFileURL = [NSURL URLWithString:[docDir stringByAppendingPathComponent:@"file1m"]];

	BFTask * uploadPartTask = [client uploadPart:uploadPart];

	[uploadPartTask waitUntilFinished];

	if (!uploadPartTask.error) {
		OSSUploadPartResult * result = uploadPartTask.result;
		uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:uploadPart.uploadPartFileURL.absoluteString error:nil] fileSize];
		[partInfos addObject:[OSSPartInfo partInfoWithPartNum:i eTag:result.eTag size:fileSize]];
	} else {
		NSLog(@"upload part error: %@", uploadPartTask.error);
		return;
	}
}
```

### 完成分块上传

```
OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
complete.bucketName = uploadToBucket;
complete.objectKey = uploadObjectkey;
complete.uploadId = uploadId;
complete.partInfos = partInfos;

BFTask * completeTask = [client completeMultipartUpload:complete];

[[completeTask continueWithBlock:^id(BFTask *task) {
	if (!task.error) {
		OSSCompleteMultipartUploadResult * result = task.result;
		// ...
	} else {
		// ...
	}
	return nil;
}] waitUntilFinished];
```

### 删除分块上传事件

```
OSSAbortMultipartUploadRequest * abort = [OSSAbortMultipartUploadRequest new];
abort.bucketName = @"<bucketName>";
abort.objectKey = @"<objectKey>";
abort.uploadId = uploadId;

BFTask * abortTask = [client abortMultipartUpload:abort];

[abortTask waitUntilFinished];

if (!abortTask.error) {
	OSSInitMultipartUploadResult * result = abortTask.result;
	uploadId = result.uploadId;
} else {
	NSLog(@"multipart upload failed, error: %@", abortTask.error);
	return;
}
```

## 异常响应

SDK中发生的异常分为两类：ClientError和ServerError。其中前者指的是参数错误、网络错误等，后者指OSS Server返回的异常响应。

|Error类型|Error Domain|Code|UserInfo|
|---|---|---|---|
|ClientError|com.aliyun.oss.clientError|OSSClientErrorCodeNetworkingFailWithResponseCode0|连接异常|
|ClientError|com.aliyun.oss.clientError|OSSClientErrorCodeSignFailed|签名失败|
|ClientError|com.aliyun.oss.clientError|OSSClientErrorCodeFileCantWrite|文件无法写入|
|ClientError|com.aliyun.oss.clientError|OSSClientErrorCodeInvalidArgument|参数非法|
|ClientError|com.aliyun.oss.clientError|OSSClientErrorCodeNilUploadid|断点续传任务未获取到uploadId|
|ClientError|com.aliyun.oss.clientError|OSSClientErrorCodeNetworkError|网络异常|
|ClientError|com.aliyun.oss.clientError|OSSClientErrorCodeTaskCancelled|任务被取消|
|ServerError|com.aliyun.oss.serverError|(-1 * httpResponseCode)|解析响应XML得到的Dictionary|

## License

Copyright (c) 2015 zhouzhuo Aliyun inc.

Licensed under the Apache License, Version 2.0 (the "License");

you may not use this file except in compliance with the License.

You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software

distributed under the License is distributed on an "AS IS" BASIS,

WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

See the License for the specific language governing permissions and

limitations under the License.
