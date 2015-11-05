/*
 *  Copyright (c) 2014, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "OSSCancellationTokenRegistration.h"

#import "OSSCancellationToken.h"

@interface OSSCancellationTokenRegistration ()

@property (nonatomic, weak) OSSCancellationToken *token;
@property (nonatomic, strong) OSSCancellationBlock cancellationObserverBlock;
@property (nonatomic, strong) NSObject *lock;
@property (nonatomic) BOOL disposed;

@end

@interface OSSCancellationToken (OSSCancellationTokenRegistration)

- (void)unregisterRegistration:(OSSCancellationTokenRegistration *)registration;

@end

@implementation OSSCancellationTokenRegistration

+ (instancetype)registrationWithToken:(OSSCancellationToken *)token delegate:(OSSCancellationBlock)delegate {
    OSSCancellationTokenRegistration *registration = [OSSCancellationTokenRegistration new];
    registration.token = token;
    registration.cancellationObserverBlock = delegate;
    return registration;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = [NSObject new];
    }
    return self;
}

- (void)dispose {
    @synchronized(self.lock) {
        if (self.disposed) {
            return;
        }
        self.disposed = YES;
    }

    OSSCancellationToken *token = self.token;
    if (token != nil) {
        [token unregisterRegistration:self];
        self.token = nil;
    }
    self.cancellationObserverBlock = nil;
}

- (void)notifyDelegate {
    @synchronized(self.lock) {
        [self throwIfDisposed];
        self.cancellationObserverBlock();
    }
}

- (void)throwIfDisposed {
    NSAssert(!self.disposed, @"Object already disposed");
}

@end
