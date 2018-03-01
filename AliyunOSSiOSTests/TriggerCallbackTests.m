//
//  TriggerCallbackTests.m
//  AliyunOSSiOSTests
//
//  Created by huaixu on 2018/1/29.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "AliyunOSSTests.h"
#import "OSSTestUtils.h"

@interface TriggerCallbackTests : AliyunOSSTests
{
    NSString *_privateBucketName;
}
@end

@implementation TriggerCallbackTests

- (void)setUp {
    [super setUp];
    NSArray *array1 = [self.name componentsSeparatedByString:@" "];
    NSString *testName = [[array1[1] substringToIndex:([array1[1] length] -1)] lowercaseString];
    _privateBucketName = [@"oss-ios-" stringByAppendingString:testName];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    OSSPlainTextAKSKPairCredentialProvider *provider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    self.client = [[OSSClient alloc] initWithEndpoint:@"http://oss-cn-shenzhen.aliyuncs.com" credentialProvider:provider];
    OSSCreateBucketRequest *createBucket1 = [OSSCreateBucketRequest new];
    createBucket1.bucketName = _privateBucketName;
    [[self.client createBucket:createBucket1] waitUntilFinished];
    
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    put.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    [[self.client putObject:put] waitUntilFinished];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [OSSTestUtils cleanBucket:_privateBucketName with:self.client];
}

- (void)testExample {
    OSSCallBackRequest *request = [OSSCallBackRequest new];
    request.bucketName = _privateBucketName;
    request.objectName = OSS_IMAGE_KEY;
    request.callbackParam = @{@"callbackUrl": OSS_CALLBACK_URL,
                              @"callbackBody": @"test"};
    request.callbackVar = @{@"var1": @"value1",
                            @"var2": @"value2"};
    
    [[[self.client triggerCallBack:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
}

@end
