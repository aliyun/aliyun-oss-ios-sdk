//
//  TriggerCallbackTests.m
//  AliyunOSSiOSTests
//
//  Created by huaixu on 2018/1/29.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "AliyunOSSTests.h"

@interface TriggerCallbackTests : AliyunOSSTests

@end

@implementation TriggerCallbackTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    OSSPlainTextAKSKPairCredentialProvider *provider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    self.client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:provider];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    OSSCallBackRequest *request = [OSSCallBackRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectName = @"landscape-painting.jpeg";
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
