//
//  SequentialMultipartUploadTests.m
//  AliyunOSSiOSTests
//
//  Created by huaixu on 2018/1/18.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "AliyunOSSTests.m"

@interface SequentialMultipartUploadTests : AliyunOSSTests

@end

@implementation SequentialMultipartUploadTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAPI_sequentialMultipartUpload_crcClosed {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    OSSResumableUploadRequest *request = [OSSResumableUploadRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.objectKey = @"sequential-multipart";
    request.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.deleteUploadIdOnCancelling = NO;
    request.crcFlag = OSSRequestCRCClosed;
    
    OSSTask *task = [self.client sequentialMultipartUpload:request];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_sequentialMultipartUpload_crcOpen {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    OSSResumableUploadRequest *request = [OSSResumableUploadRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.objectKey = @"sequential-multipart";
    request.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.deleteUploadIdOnCancelling = NO;
    request.crcFlag = OSSRequestCRCOpen;
    
    OSSTask *task = [self.client sequentialMultipartUpload:request];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_sequentialMultipartUpload_cancel {
    OSSResumableUploadRequest *request = [OSSResumableUploadRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.objectKey = @"sequential-multipart";
    request.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.deleteUploadIdOnCancelling = NO;
    request.crcFlag = OSSRequestCRCOpen;
    __weak typeof(request) weakRequest = request;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        if (totalBytesSent > totalBytesExpectedToSend / 2) {
            [weakRequest cancel];
        }
    };
    
    OSSTask *task = [self.client sequentialMultipartUpload:request];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_sequentialMultipartUpload_cancel_and_resume_crcClosed {
    OSSResumableUploadRequest *request = [OSSResumableUploadRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.objectKey = @"sequential-multipart";
    request.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.deleteUploadIdOnCancelling = NO;
    request.crcFlag = OSSRequestCRCClosed;
    __weak typeof(request) weakRequest = request;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        if (totalBytesSent > totalBytesExpectedToSend / 2) {
            [weakRequest cancel];
        }
    };
    
    OSSTask *task = [self.client sequentialMultipartUpload:request];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
    
    OSSResumableUploadRequest *resumedRequest = [OSSResumableUploadRequest new];
    resumedRequest.bucketName = OSS_BUCKET_PUBLIC;
    resumedRequest.objectKey = @"sequential-multipart";
    resumedRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    resumedRequest.deleteUploadIdOnCancelling = NO;
    resumedRequest.crcFlag = OSSRequestCRCClosed;
    
    task = [self.client sequentialMultipartUpload:resumedRequest];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_sequentialMultipartUpload_cancel_and_resume_crcOpened {
    OSSResumableUploadRequest *request = [OSSResumableUploadRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.objectKey = @"sequential-multipart";
    request.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.deleteUploadIdOnCancelling = NO;
    request.crcFlag = OSSRequestCRCOpen;
    __weak typeof(request) weakRequest = request;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        if (totalBytesSent > totalBytesExpectedToSend / 2) {
            [weakRequest cancel];
        }
    };
    
    OSSTask *task = [self.client sequentialMultipartUpload:request];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
    
    OSSResumableUploadRequest *resumedRequest = [OSSResumableUploadRequest new];
    resumedRequest.bucketName = OSS_BUCKET_PUBLIC;
    resumedRequest.objectKey = @"sequential-multipart";
    resumedRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    resumedRequest.deleteUploadIdOnCancelling = NO;
    resumedRequest.crcFlag = OSSRequestCRCOpen;
    
    task = [self.client sequentialMultipartUpload:resumedRequest];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_sequentialMultipartUpload_cancel_and_resume_lastCrcOpened {
    OSSResumableUploadRequest *request = [OSSResumableUploadRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.objectKey = @"sequential-multipart";
    request.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.deleteUploadIdOnCancelling = NO;
    request.crcFlag = OSSRequestCRCClosed;
    __weak typeof(request) weakRequest = request;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        if (totalBytesSent > totalBytesExpectedToSend / 2) {
            [weakRequest cancel];
        }
    };
    
    OSSTask *task = [self.client sequentialMultipartUpload:request];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
    
    OSSResumableUploadRequest *resumedRequest = [OSSResumableUploadRequest new];
    resumedRequest.bucketName = OSS_BUCKET_PUBLIC;
    resumedRequest.objectKey = @"sequential-multipart";
    resumedRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    resumedRequest.deleteUploadIdOnCancelling = NO;
    resumedRequest.crcFlag = OSSRequestCRCOpen;
    
    task = [self.client sequentialMultipartUpload:resumedRequest];
    [[task continueWithBlock:^OSSTask* (OSSTask* t) {
        XCTAssertNotNil(t.error);
        return nil;
    }] waitUntilFinished];
}

@end
