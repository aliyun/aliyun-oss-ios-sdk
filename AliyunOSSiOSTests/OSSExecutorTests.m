//
//  OSSExecutorTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/15.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

@interface OSSExecutorTests : XCTestCase

@end

@implementation OSSExecutorTests

- (void)testExecuteImmediately {
    __block OSSTask *task = [OSSTask taskWithResult:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"test immediate executor"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        task = [task continueWithExecutor:[OSSExecutor immediateExecutor] withBlock:^id(OSSTask *_) {
            return nil;
        }];
        XCTAssertTrue(task.completed);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testExecuteOnDispatchQueue {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L);
    OSSExecutor *queueExecutor = [OSSExecutor executorWithDispatchQueue:queue];
    
    OSSTask *task = [OSSTask taskWithResult:nil];
    task = [task continueWithExecutor:queueExecutor withBlock:^id(OSSTask *_) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        XCTAssertEqual(queue, dispatch_get_current_queue());
#pragma clang diagnostic pop
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testExecuteOnOperationQueue {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    OSSExecutor *queueExecutor = [OSSExecutor executorWithOperationQueue:queue];
    
    OSSTask *task = [OSSTask taskWithResult:nil];
    task = [task continueWithExecutor:queueExecutor withBlock:^id(OSSTask *_) {
        XCTAssertEqual(queue, [NSOperationQueue currentQueue]);
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testMainThreadExecutor {
    OSSExecutor *executor = [OSSExecutor mainThreadExecutor];
    
    XCTestExpectation *immediateExpectation = [self expectationWithDescription:@"test main thread executor on main thread"];
    [executor execute:^{
        XCTAssertTrue([NSThread isMainThread]);
        [immediateExpectation fulfill];
    }];
    
    // Behaviour is different when running on main thread (runs immediately) vs running on the background queue.
    XCTestExpectation *backgroundExpectation = [self expectationWithDescription:@"test main thread executor on background thread"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [executor execute:^{
            XCTAssertTrue([NSThread isMainThread]);
            [backgroundExpectation fulfill];
        }];
    });
    
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end
