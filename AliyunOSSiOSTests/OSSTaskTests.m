//
//  OSSTaskTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/15.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "OSSTask.h"
#import "OSSCancellationTokenSource.h"
#import "OSSCancellationToken.h"
#import "OSSExecutor.h"
#import "OSSTaskCompletionSource.h"

@interface OSSTaskTests : XCTestCase

@end

@implementation OSSTaskTests

- (void)testBasicOnSuccess {
    [[[OSSTask taskWithResult:@"foo"] continueWithSuccessBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        return nil;
    }] waitUntilFinished];
}

- (void)testBasicOnSuccessWithExecutor {
    __block BOOL completed = NO;
    OSSTask *task = [[OSSTask taskWithDelay:100] continueWithExecutor:[OSSExecutor immediateExecutor]
                                                   withSuccessBlock:^id _Nullable(OSSTask * _Nonnull _) {
                                                       completed = YES;
                                                       return nil;
                                                   }];
    [task waitUntilFinished];
    XCTAssertTrue(completed);
    XCTAssertTrue(task.completed);
    XCTAssertFalse(task.faulted);
    XCTAssertFalse(task.cancelled);
    XCTAssertNil(task.result);
}

- (void)testBasicOnSuccessWithToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSTask *task = [OSSTask taskWithDelay:100];
    
    task = [task continueWithSuccessBlock:^id(OSSTask *t) {
        XCTFail(@"Success block should not be triggered");
        return nil;
    } cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.cancelled);
}

- (void)testBasicOnSuccessWithExecutorToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSTask *task = [OSSTask taskWithDelay:100];
    
    task = [task continueWithExecutor:[OSSExecutor immediateExecutor]
                         successBlock:^id(OSSTask *t) {
                             XCTFail(@"Success block should not be triggered");
                             return nil;
                         }
                    cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.cancelled);
}

- (void)testBasicOnSuccessWithCancelledToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSTask *task = [OSSTask taskWithResult:nil];
    
    [cts cancel];
    
    task = [task continueWithExecutor:[OSSExecutor immediateExecutor]
                         successBlock:^id(OSSTask *t) {
                             XCTFail(@"Success block should not be triggered");
                             return nil;
                         }
                    cancellationToken:cts.token];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testBasicContinueWithError {
    NSError *originalError = [NSError errorWithDomain:@"Bolts" code:22 userInfo:nil];
    [[[OSSTask taskWithError:originalError] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error, @"Task should have failed.");
        XCTAssertEqual((NSInteger)22, t.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testBasicContinueWithToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSTask *task = [OSSTask taskWithDelay:100];
    
    task = [task continueWithExecutor:[OSSExecutor immediateExecutor]
                                block:^id(OSSTask *t) {
                                    XCTFail(@"Continuation block should not be triggered");
                                    return nil;
                                }
                    cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testBasicContinueWithCancelledToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    OSSTask *task = [OSSTask taskWithResult:nil];
    
    [cts cancel];
    
    task = [task continueWithExecutor:[OSSExecutor immediateExecutor]
                                block:^id(OSSTask *t) {
                                    XCTFail(@"Continuation block should not be triggered");
                                    return nil;
                                }
                    cancellationToken:cts.token];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testFinishLaterWithSuccess {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.result = @"bar";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testFinishLaterWithError {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testTransformConstantToConstant {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [[tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        return @"bar";
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.result = @"foo";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testTransformErrorToConstant {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [[tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        return @"bar";
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnSuccessfulTaskFromContinuation {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [[tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        return [OSSTask taskWithResult:@"bar"];
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.result = @"foo";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnSuccessfulTaskFromContinuationAfterError {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [[tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        return [OSSTask taskWithResult:@"bar"];
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnErrorTaskFromContinuation {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [[tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        NSError *originalError = [NSError errorWithDomain:@"Bolts" code:24 userInfo:nil];
        return [OSSTask taskWithError:originalError];
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)24, t.error.code);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.result = @"foo";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnErrorTaskFromContinuationAfterError {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [[tcs.task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        NSError *originalError = [NSError errorWithDomain:@"Bolts" code:24 userInfo:nil];
        return [OSSTask taskWithError:originalError];
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)24, t.error.code);
        return nil;
    }];
    [[OSSTask taskWithDelay:0] continueWithBlock:^id(OSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testPassOnError {
    NSError *originalError = [NSError errorWithDomain:@"Bolts" code:30 userInfo:nil];
    [[[[[[[[OSSTask taskWithError:originalError] continueWithSuccessBlock:^id(OSSTask *t) {
        XCTFail(@"This callback should be skipped.");
        return nil;
    }] continueWithSuccessBlock:^id(OSSTask *t) {
        XCTFail(@"This callback should be skipped.");
        return nil;
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)30, t.error.code);
        NSError *newError = [NSError errorWithDomain:@"Bolts" code:31 userInfo:nil];
        return [OSSTask taskWithError:newError];
    }] continueWithSuccessBlock:^id(OSSTask *t) {
        XCTFail(@"This callback should be skipped.");
        return nil;
    }] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)31, t.error.code);
        return [OSSTask taskWithResult:@"okay"];
    }] continueWithSuccessBlock:^id(OSSTask *t) {
        XCTAssertEqualObjects(@"okay", t.result);
        return nil;
    }] waitUntilFinished];
}

- (void)testCancellation {
    OSSTaskCompletionSource *tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSTask *task = [[OSSTask taskWithDelay:100] continueWithBlock:^id(OSSTask *t) {
        return tcs.task;
    }];
    
    [tcs cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testTaskForCompletionOfAllTasksSuccess {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[OSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(OSSTask *t) {
            return @(i);
        }]];
    }
    
    [[[OSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNil(t.error);
        XCTAssertFalse(t.isCancelled);
        
        for (int i = 0; i < kTaskCount; ++i) {
            XCTAssertEqual(i, [((OSSTask *)[tasks objectAtIndex:i]).result intValue]);
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksOneError {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[OSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(OSSTask *t) {
            if (i == 10) {
                return [OSSTask taskWithError:[NSError errorWithDomain:@"BoltsTests"
                                                                 code:35
                                                             userInfo:nil]];
            }
            return @(i);
        }]];
    }
    
    [[[OSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertFalse(t.isCancelled);
        
        XCTAssertEqualObjects(@"BoltsTests", t.error.domain);
        XCTAssertEqual(35, (int)t.error.code);
        
        for (int i = 0; i < kTaskCount; ++i) {
            if (i == 10) {
                XCTAssertNotNil(((OSSTask *)[tasks objectAtIndex:i]).error);
            } else {
                XCTAssertEqual(i, [((OSSTask *)[tasks objectAtIndex:i]).result intValue]);
            }
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksTwoErrors {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[OSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(OSSTask *t) {
            if (i == 10 || i == 11) {
                return [OSSTask taskWithError:[NSError errorWithDomain:@"BoltsTests"
                                                                 code:35
                                                             userInfo:nil]];
            }
            return @(i);
        }]];
    }
    
    [[[OSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertFalse(t.isCancelled);
        
        XCTAssertEqualObjects(@"bolts", t.error.domain);
        XCTAssertEqual(kOSSMultipleErrorsError, t.error.code);
        
        NSArray *errors = [t.error.userInfo objectForKey:OSSTaskMultipleErrorsUserInfoKey];
        XCTAssertEqualObjects(@"BoltsTests", [[errors objectAtIndex:0] domain]);
        XCTAssertEqual(35, (int)[[errors objectAtIndex:0] code]);
        XCTAssertEqualObjects(@"BoltsTests", [[errors objectAtIndex:1] domain]);
        XCTAssertEqual(35, (int)[[errors objectAtIndex:1] code]);
        
        for (int i = 0; i < kTaskCount; ++i) {
            if (i == 10 || i == 11) {
                XCTAssertNotNil(((OSSTask *)[tasks objectAtIndex:i]).error);
            } else {
                XCTAssertEqual(i, [((OSSTask *)[tasks objectAtIndex:i]).result intValue]);
            }
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksCancelled {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[OSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(OSSTask *t) {
            if (i == 10) {
                return [OSSTask cancelledTask];
            }
            return @(i);
        }]];
    }
    
    [[[OSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(OSSTask *t) {
        XCTAssertNil(t.error);
        XCTAssertTrue(t.isCancelled);
        
        for (int i = 0; i < kTaskCount; ++i) {
            if (i == 10) {
                XCTAssertTrue(((OSSTask *)[tasks objectAtIndex:i]).isCancelled);
            } else {
                XCTAssertEqual(i, [((OSSTask *)[tasks objectAtIndex:i]).result intValue]);
            }
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksNoTasksImmediateCompletion {
    NSMutableArray *tasks = [NSMutableArray array];
    
    OSSTask *task = [OSSTask taskForCompletionOfAllTasks:tasks];
    XCTAssertTrue(task.completed);
    XCTAssertFalse(task.cancelled);
    XCTAssertFalse(task.faulted);
}

- (void)testTaskForCompletionOfAllTasksWithResultsSuccess {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = i * 10;
        int result = i + 1;
        [tasks addObject:[[OSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(OSSTask *__unused t) {
            return @(result);
        }]];
    }
    
    [[[OSSTask taskForCompletionOfAllTasksWithResults:tasks] continueWithBlock:^id(OSSTask *t) {
        XCTAssertFalse(t.cancelled);
        XCTAssertFalse(t.faulted);
        
        NSArray *results = t.result;
        for (int i = 0; i < kTaskCount; ++i) {
            NSNumber *individualResult = [results objectAtIndex:i];
            XCTAssertEqual([individualResult intValue], [((OSSTask *)[tasks objectAtIndex:i]).result intValue]);
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksErrorCancelledSuccess {
    OSSTask *errorTask = [OSSTask taskWithError:[NSError new]];
    OSSTask *cancelledTask = [OSSTask cancelledTask];
    OSSTask *successfulTask = [OSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    OSSTask *allTasks = [OSSTask taskForCompletionOfAllTasks:@[ successfulTask, cancelledTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
}

- (void)testTaskForCompletionOfAllTasksExceptionErrorCancelledSuccess {
    OSSTask *errorTask = [OSSTask taskWithError:[NSError new]];
    OSSTask *cancelledTask = [OSSTask cancelledTask];
    OSSTask *successfulTask = [OSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    OSSTask *allTasks = [OSSTask taskForCompletionOfAllTasks:@[ successfulTask, cancelledTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
    XCTAssertNotNil(allTasks.error, @"Task should have error");
}

- (void)testTaskForCompletionOfAllTasksErrorCancelled {
    OSSTask *errorTask = [OSSTask taskWithError:[NSError new]];
    OSSTask *cancelledTask = [OSSTask cancelledTask];
    
    OSSTask *allTasks = [OSSTask taskForCompletionOfAllTasks:@[ cancelledTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
}

- (void)testTaskForCompletionOfAllTasksSuccessCancelled {
    OSSTask *cancelledTask = [OSSTask cancelledTask];
    OSSTask *successfulTask = [OSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    OSSTask *allTasks = [OSSTask taskForCompletionOfAllTasks:@[ successfulTask, cancelledTask ]];
    
    XCTAssertTrue(allTasks.cancelled, @"Task should be cancelled");
}

- (void)testTaskForCompletionOfAllTasksSuccessError {
    OSSTask *errorTask = [OSSTask taskWithError:[NSError new]];
    OSSTask *successfulTask = [OSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    OSSTask *allTasks = [OSSTask taskForCompletionOfAllTasks:@[ successfulTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
}


- (void)testTaskForCompletionOfAllTasksWithResultsNoTasksImmediateCompletion {
    NSMutableArray *tasks = [NSMutableArray array];
    
    OSSTask *task = [OSSTask taskForCompletionOfAllTasksWithResults:tasks];
    XCTAssertTrue(task.completed);
    XCTAssertFalse(task.cancelled);
    XCTAssertFalse(task.faulted);
    XCTAssertTrue(task.result != nil);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithSuccess {
    OSSTask *task = [OSSTask taskForCompletionOfAnyTask:@[[OSSTask taskWithDelay:20], [OSSTask taskWithResult:@"success"]]];
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(@"success", task.result);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithRacing {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    OSSExecutor *executor = [OSSExecutor executorWithDispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    OSSTask *first = [OSSTask taskFromExecutor:executor withBlock:^id _Nullable {
        return @"first";
    }];
    OSSTask *second = [OSSTask taskFromExecutor:executor withBlock:^id _Nullable {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        return @"second";
    }];
    
    OSSTask *task = [OSSTask taskForCompletionOfAnyTask:@[first, second]];
    [task waitUntilFinished];
    
    dispatch_semaphore_signal(semaphore);
    
    XCTAssertEqualObjects(@"first", task.result);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithErrorAndSuccess {
    NSError *error = [NSError errorWithDomain:@"BoltsTests"
                                         code:35
                                     userInfo:nil];
    
    OSSTask *task = [OSSTask taskForCompletionOfAnyTask:@[[OSSTask taskWithError:error], [OSSTask taskWithResult:@"success"]]];
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(@"success", task.result);
    XCTAssertNil(task.error);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithError {
    NSError *error = [NSError errorWithDomain:@"BoltsTests"
                                         code:35
                                     userInfo:nil];
    
    OSSTask *task = [OSSTask taskForCompletionOfAnyTask:@[[OSSTask taskWithError:error]]];
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(error, task.error);
    XCTAssertNotNil(task.error);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithNilArray {
    OSSTask *task = [OSSTask taskForCompletionOfAnyTask:nil];
    [task waitUntilFinished];
    
    XCTAssertNil(task.result);
    XCTAssertNil(task.error);
}

- (void)testTasksForTaskForCompletionOfAnyTasksAllErrors {
    NSError *error = [NSError errorWithDomain:@"BoltsTests"
                                         code:35
                                     userInfo:nil];
    
    OSSTask *task = [OSSTask taskForCompletionOfAnyTask:@[[OSSTask taskWithError:error], [OSSTask taskWithError:error]]];
    [task waitUntilFinished];
    
    XCTAssertNil(task.result);
    XCTAssertNotNil(task.error);
    XCTAssertNotNil(task.error.userInfo);
    XCTAssertEqualObjects(@"bolts", task.error.domain);
    XCTAssertTrue([task.error.userInfo[@"errors"] isKindOfClass:[NSArray class]]);
    XCTAssertEqual(2, [task.error.userInfo[@"errors"] count]);
}

- (void)testWaitUntilFinished {
    OSSTask *task = [[OSSTask taskWithDelay:50] continueWithBlock:^id(OSSTask *t) {
        return @"foo";
    }];
    
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(@"foo", task.result);
}

- (void)testDelayWithToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    
    OSSTask *task = [OSSTask taskWithDelay:100 cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.cancelled, @"Task should be cancelled immediately");
}

- (void)testDelayWithCancelledToken {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    [cts cancel];
    
    OSSTask *task = [OSSTask taskWithDelay:100 cancellationToken:cts.token];
    
    XCTAssertTrue(task.cancelled, @"Task should be cancelled immediately");
}

- (void)testTaskFromExecutor {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L);
    OSSExecutor *queueExecutor = [OSSExecutor executorWithDispatchQueue:queue];
    
    OSSTask *task = [OSSTask taskFromExecutor:queueExecutor withBlock:^id() {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        XCTAssertEqual(queue, dispatch_get_current_queue());
#pragma clang diagnostic pop
        return @"foo";
    }];
    [task waitUntilFinished];
    XCTAssertEqual(@"foo", task.result);
}

- (void)testDescription {
    OSSTask *task = [OSSTask taskWithResult:nil];
    NSString *expected = [NSString stringWithFormat:@"<OSSTask: %p; completed = YES; cancelled = NO; faulted = NO; result = (null)>", task];
    
    NSString *description = task.description;
    
    XCTAssertTrue([expected isEqualToString:description]);
}

- (void)testReturnTaskFromContinuationWithCancellation {
    OSSCancellationTokenSource *cts = [OSSCancellationTokenSource cancellationTokenSource];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"task"];
    [[[OSSTask taskWithDelay:1] continueWithBlock:^id(OSSTask *t) {
        [cts cancel];
        return [OSSTask taskWithDelay:10];
    } cancellationToken:cts.token] continueWithBlock:^id(OSSTask *t) {
        XCTAssertTrue(t.cancelled);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSetResult {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    taskCompletionSource.result = @"a";
    XCTAssertThrowsSpecificNamed([taskCompletionSource setResult:@"b"], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertEqualObjects(taskCompletionSource.task.result, @"a");
}

- (void)testTrySetResult {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    [taskCompletionSource trySetResult:@"a"];
    [taskCompletionSource trySetResult:@"b"];
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertEqualObjects(taskCompletionSource.task.result, @"a");
}

- (void)testSetError {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    
    NSError *error = [NSError errorWithDomain:@"TestDomain" code:100500 userInfo:nil];
    taskCompletionSource.error = error;
    XCTAssertThrowsSpecificNamed([taskCompletionSource setError:error], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.error, error);
}

- (void)testTrySetError {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    
    NSError *error = [NSError errorWithDomain:@"TestDomain" code:100500 userInfo:nil];
    [taskCompletionSource trySetError:error];
    [taskCompletionSource trySetError:error];
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.error, error);
}

- (void)testSetException {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    
    NSException *exception = [NSException exceptionWithName:@"testExceptionName" reason:@"testExceptionReason" userInfo:nil];
    taskCompletionSource.exception = exception;
    XCTAssertThrowsSpecificNamed([taskCompletionSource setException:exception], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.exception, exception);
}

- (void)testTrySetException {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    
    NSException *exception = [NSException exceptionWithName:@"testExceptionName" reason:@"testExceptionReason" userInfo:nil];
    [taskCompletionSource trySetException:exception];
    [taskCompletionSource trySetException:exception];
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.exception, exception);
}

- (void)testSetCancelled {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    
    [taskCompletionSource cancel];
    XCTAssertThrowsSpecificNamed([taskCompletionSource cancel], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.cancelled);
}

- (void)testTrySetCancelled {
    OSSTaskCompletionSource *taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
    
    [taskCompletionSource trySetCancelled];
    [taskCompletionSource trySetCancelled];
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.cancelled);
}

- (void)testMultipleWaitUntilFinished {
    OSSTask *task = [[OSSTask taskWithDelay:50] continueWithBlock:^id(OSSTask *t) {
        return @"foo";
    }];
    
    [task waitUntilFinished];
    
    XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [task waitUntilFinished];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testMultipleThreadsWaitUntilFinished {
    OSSTask *task = [[OSSTask taskWithDelay:500] continueWithBlock:^id(OSSTask *t) {
        return @"foo";
    }];
    
    dispatch_queue_t queue = dispatch_queue_create("com.bolts.tests.wait", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_group_async(group, queue, ^{
            [task waitUntilFinished];
        });
        dispatch_group_async(group, queue, ^{
            [task waitUntilFinished];
        });
        [task waitUntilFinished];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end
