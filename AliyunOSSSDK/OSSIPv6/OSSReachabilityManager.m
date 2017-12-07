//
//  OSSReachabilityManager.m
//
//  Created by 亿刀 on 14-1-9.
//  Edited by junmo on 15-5-16
//  Edited by zhouzhuo on 2016/5/22
//  Copyright (c) 2014 Twitter. All rights reserved.
//

#import "OSSReachabilityManager.h"
#import "OSSIPv6Adapter.h"
#import "OSSLog.h"

#import <arpa/inet.h>
#import <CommonCrypto/CommonDigest.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <sys/socket.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>

static char *const OSSReachabilityQueueIdentifier = "com.alibaba.oss.network.ReachabilityQueue";
static dispatch_queue_t reachabilityQueue;
static NSString *const CHECK_HOSTNAME = @"www.taobao.com";

@implementation OSSReachabilityManager {
    SCNetworkReachabilityRef            _reachabilityRef;
}

+ (OSSReachabilityManager *)shareInstance
{
    static OSSReachabilityManager *s_SPDYNetworkStatusManager = nil;
    
    @synchronized([self class])
    {
        if (!s_SPDYNetworkStatusManager)
        {
            s_SPDYNetworkStatusManager = [[OSSReachabilityManager alloc] init];
        }
    }
    
    return s_SPDYNetworkStatusManager;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _reachabilityRef =  SCNetworkReachabilityCreateWithName(NULL, [CHECK_HOSTNAME UTF8String]);

        // Start network monitor
        [self _startNotifier];
    }

    return self;
}

- (BOOL)_startNotifier
{
    if (!_reachabilityRef)
    {
        _reachabilityRef =  SCNetworkReachabilityCreateWithName(NULL, [CHECK_HOSTNAME UTF8String]);
    }

    if (_reachabilityRef)
    {
        SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        
        if(SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context))
        {
            reachabilityQueue = dispatch_queue_create(OSSReachabilityQueueIdentifier, DISPATCH_QUEUE_SERIAL);
            SCNetworkReachabilitySetDispatchQueue(_reachabilityRef, reachabilityQueue);

            return YES;
        }
    }
    return NO;
}

// Callback of Network change 
static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    if ([[OSSIPv6Adapter getInstance] isIPv6OnlyNetwork]) {
        OSSLogDebug(@"[AlicloudReachabilityManager]: Network changed, Pre network status is IPv6-Only.");
    } else {
        OSSLogDebug(@"[AlicloudReachabilityManager]: Network changed, Pre network status is not IPv6-Only.");
    }

    [[OSSIPv6Adapter getInstance] reResolveIPv6OnlyStatus];
}

@end
