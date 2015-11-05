/*
 *  Copyright (c) 2014, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "OSSExecutor.h"

@interface OSSExecutor ()

@property (nonatomic, copy) void(^block)(void(^block)());

@end

@implementation OSSExecutor

#pragma mark - Executor methods

+ (instancetype)defaultExecutor {
    static OSSExecutor *defaultExecutor = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultExecutor = [self executorWithBlock:^void(void(^block)()) {
            static const NSString *OSSTaskDepthKey = @"OSSTaskDepth";
            static const int OSSTaskDefaultExecutorMaxDepth = 20;

            // We prefer to run everything possible immediately, so that there is callstack information
            // when debugging. However, we don't want the stack to get too deep, so if the number of
            // recursive calls to this method exceeds a certain depth, we dispatch to another GCD queue.
            NSMutableDictionary *threadLocal = [[NSThread currentThread] threadDictionary];
            NSNumber *depth = threadLocal[OSSTaskDepthKey];
            if (!depth) {
                depth = @0;
            }
            if (depth.intValue > OSSTaskDefaultExecutorMaxDepth) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
            } else {
                NSNumber *previousDepth = depth;
                threadLocal[OSSTaskDepthKey] = @(previousDepth.intValue + 1);
                @try {
                    block();
                } @finally {
                    threadLocal[OSSTaskDepthKey] = previousDepth;
                }
            }
        }];
    });
    return defaultExecutor;
}

+ (instancetype)immediateExecutor {
    static OSSExecutor *immediateExecutor = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        immediateExecutor = [self executorWithBlock:^void(void(^block)()) {
            block();
        }];
    });
    return immediateExecutor;
}

+ (instancetype)mainThreadExecutor {
    static OSSExecutor *mainThreadExecutor = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mainThreadExecutor = [self executorWithBlock:^void(void(^block)()) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), block);
            } else {
                block();
            }
        }];
    });
    return mainThreadExecutor;
}

+ (instancetype)executorWithBlock:(void(^)(void(^block)()))block {
    return [[self alloc] initWithBlock:block];
}

+ (instancetype)executorWithDispatchQueue:(dispatch_queue_t)queue {
    return [self executorWithBlock:^void(void(^block)()) {
        dispatch_async(queue, block);
    }];
}

+ (instancetype)executorWithOperationQueue:(NSOperationQueue *)queue {
    return [self executorWithBlock:^void(void(^block)()) {
        [queue addOperation:[NSBlockOperation blockOperationWithBlock:block]];
    }];
}

#pragma mark - Initializer

- (instancetype)initWithBlock:(void(^)(void(^block)()))block {
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

#pragma mark - Execution

- (void)execute:(void(^)())block {
    self.block(block);
}

@end
