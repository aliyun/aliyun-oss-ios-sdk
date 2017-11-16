//
//  OSSCancellationTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/15.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSCancellationTokenSource.h"
#import "OSSCancellationTokenRegistration.h"
#import "OSSCancellationToken.h"

@interface OSSCancellationTests : XCTestCase

@end

@implementation OSSCancellationTests

- (void)testCancel {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested, @"Source should not be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should not be cancelled");
    
    [cts cancel];
    
    XCTAssertTrue(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertTrue(cts.token.cancellationRequested, @"Token should be cancelled");
}

- (void)testCancelMultipleTimes {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    XCTAssertFalse(cts.cancellationRequested);
    XCTAssertFalse(cts.token.cancellationRequested);
    
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
    
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
}

- (void)testCancellationBlock {
    __block BOOL cancelled = NO;
    
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    [cts.token registerCancellationObserverWithBlock:^{
        cancelled = YES;
    }];
    
    XCTAssertFalse(cts.cancellationRequested, @"Source should not be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should not be cancelled");
    
    [cts cancel];
    
    XCTAssertTrue(cancelled, @"Source should be cancelled");
}

- (void)testCancellationAfterDelay {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested, @"Source should not be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should not be cancelled");
    
    [cts cancelAfterDelay:200];
    XCTAssertFalse(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should be cancelled");
    
    // Spin the run loop for half a second, since `delay` is in milliseconds, not seconds.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    
    XCTAssertTrue(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertTrue(cts.token.cancellationRequested, @"Token should be cancelled");
}

- (void)testCancellationAfterDelayValidation {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested);
    XCTAssertFalse(cts.token.cancellationRequested);
    
    XCTAssertThrowsSpecificNamed([cts cancelAfterDelay:-2], NSException, NSInvalidArgumentException);
}

- (void)testCancellationAfterZeroDelay {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested);
    XCTAssertFalse(cts.token.cancellationRequested);
    
    [cts cancelAfterDelay:0];
    
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
}

- (void)testCancellationAfterDelayOnCancelled {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
    
    [cts cancelAfterDelay:1];
    
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
}

- (void)testDispose {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    [cts dispose];
    XCTAssertThrowsSpecificNamed([cts cancel], NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(cts.cancellationRequested, NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(cts.token.cancellationRequested, NSException, NSInternalInconsistencyException);
    
    cts = [OSSCancellationTokenSource cancellationTokenSource];
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertTrue(cts.token.cancellationRequested, @"Token should be cancelled");
    
    [cts dispose];
    XCTAssertThrowsSpecificNamed(cts.cancellationRequested, NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(cts.token.cancellationRequested, NSException, NSInternalInconsistencyException);
}

- (void)testDisposeMultipleTimes {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    [cts dispose];
    XCTAssertNoThrow([cts dispose]);
}

- (void)testDisposeRegistration {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{
        XCTFail();
    }];
    XCTAssertNoThrow([registration dispose]);
    
    [cts cancel];
}

- (void)testDisposeRegistrationMultipleTimes {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{
        XCTFail();
    }];
    XCTAssertNoThrow([registration dispose]);
    XCTAssertNoThrow([registration dispose]);
    
    [cts cancel];
}

- (void)testDisposeRegistrationAfterCancellationToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{ }];
    
    [registration dispose];
    [cts dispose];
}

- (void)testDisposeRegistrationBeforeCancellationToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{ }];
    
    [cts dispose];
    XCTAssertNoThrow([registration dispose]);
}

@end
