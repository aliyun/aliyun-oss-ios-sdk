//
//  OSSIPv6Adapter.m
//
//  Created by lingkun on 16/5/16.
//  Copyright © 2016 Ali. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSIPv6Adapter.h"
#import "OSSIPv6PrefixResolver.h"
#import "OSSLog.h"

#include <arpa/inet.h>
#include <dns.h>
#include <err.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <resolv.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#if TARGET_OS_IOS
#import <UIKit/UIApplication.h>
#elif TARGET_OS_OSX
#import <AppKit/NSApplication.h>
#endif

#define UNKNOWN_STACK         0
#define SUPPORT_IPV4_STACK    1
#define SUPPORT_IPV6_STACK    2
#define ROUNDUP_LEN(a) \
((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))
#define TypeEN    "en0"

#define IOS_9_VERSION     @"9.0"

@implementation OSSIPv6Adapter
{
    BOOL isIPv6Only;
    BOOL isIPv6OnlyResolved;
}

- (instancetype)init {
    if (self = [super init]) {
        isIPv6Only = NO;
        isIPv6OnlyResolved = NO;
        
        NSString *notificationName;
#if TARGET_OS_IOS
        notificationName = UIApplicationDidBecomeActiveNotification;
#elif TARGET_OS_OSX
        notificationName = NSApplicationDidBecomeActiveNotification;
#endif

        // When App switches to active status, refresh the IPv6-only check.
        NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
        [defaultCenter addObserver:self
                          selector:@selector(appDidBecomeActiveFunc)
                              name:notificationName
                            object:nil];
    }
    return self;
}

+ (instancetype)getInstance {
    static id singletonInstance = nil;
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        if (!singletonInstance) {
            singletonInstance = [[super allocWithZone:NULL] init];
        }
    });
    return singletonInstance;
}

- (BOOL)isIPv6OnlyNetwork {
    @synchronized(self) {
        if (isIPv6OnlyResolved) {
            return isIPv6Only;
        }
        
        OSSLogDebug(@"Start resolved network to see if in IPv6-Only env.");
        int localStack = 0;
        
        localStack = SUPPORT_IPV4_STACK | SUPPORT_IPV6_STACK;
        localStack &= [self getDNSServersIpStack];
        
        if (localStack & SUPPORT_IPV4_STACK) {
            // support IPv4
            isIPv6Only = NO;
        } else if (localStack & SUPPORT_IPV6_STACK) {
            // IPv6-Only
            isIPv6Only = YES;
            [[OSSIPv6PrefixResolver getInstance] updateIPv6Prefix];
        } else {
            OSSLogDebug(@"[%s]: Error.", __FUNCTION__);
            isIPv6Only = NO;
        }
        isIPv6OnlyResolved = YES;
        if (isIPv6Only) {
            OSSLogDebug(@"[%s]: IPv6-Only network now.", __FUNCTION__);
        } else {
            OSSLogDebug(@"[%s]: Not IPv6-Only network now.", __FUNCTION__);
        }
        return isIPv6Only;
    }
}

- (void)appDidBecomeActiveFunc {
    OSSLogDebug(@"[%s]: App become active, refresh IPv6-Only status.", __FUNCTION__);
    [self reResolveIPv6OnlyStatus];
}

- (BOOL)reResolveIPv6OnlyStatus {
    isIPv6OnlyResolved = NO;
    return [self isIPv6OnlyNetwork];
}

- (NSString *)handleIpv4Address:(NSString *)addr {
    if (addr == nil || addr.length == 0) {
        return nil;
    }
    
    if ([self isIPv6Address:addr]) return [NSString stringWithFormat:@"[%@]", addr];
    
    NSString *convertedAddr;
    if ([self isIPv6OnlyNetwork]) {
        convertedAddr = [[OSSIPv6PrefixResolver getInstance] convertIPv4toIPv6:addr];
        return [NSString stringWithFormat:@"[%@]", convertedAddr];
    } else  {
        convertedAddr = addr;
    }
    return convertedAddr;
}

/**
 *	@brief	Looks up the DNS server stack and returns the flag combinations of SUPPORT_IPV4_STACK and SUPPORT_IPV6_STACK.
 *
 *	@return the flag combinations of SUPPORT_IPV4_STACK and SUPPORT_IPV6_STACK
 */
- (int)getDNSServersIpStack {
    int dns_stack = 0;
    res_state res = malloc(sizeof(struct __res_state));
    int result = res_ninit(res);
    if (result == 0) {
        union res_9_sockaddr_union *addr_union = malloc(res->nscount * sizeof(union res_9_sockaddr_union));
        res_getservers(res, addr_union, res->nscount);
        for (int i = 0; i < res->nscount; i++) {
            if (addr_union[i].sin.sin_family == AF_INET) {
                char ip[INET_ADDRSTRLEN];
                if (inet_ntop(AF_INET, &(addr_union[i].sin.sin_addr), ip, INET_ADDRSTRLEN)) {
                    dns_stack |= SUPPORT_IPV4_STACK;
                }
            } else if (addr_union[i].sin6.sin6_family == AF_INET6) {
                char ip[INET6_ADDRSTRLEN];
                if (inet_ntop(AF_INET6, &(addr_union[i].sin6.sin6_addr), ip, INET6_ADDRSTRLEN)) {
                    dns_stack |= SUPPORT_IPV6_STACK;
                }
            } else {
                OSSLogDebug(@"%s: Undefined family.", __FUNCTION__);
            }
        }
        free(addr_union);
    }
    res_ndestroy(res);
    free(res);
    return dns_stack;
}

- (BOOL)isIPv4Address:(NSString *)addr {
    if (addr == nil) {
        return NO;
    }
    const char *utf8 = [addr UTF8String];
    // Check valid IPv4.
    struct in_addr dst;
    int success = inet_pton(AF_INET, utf8, &(dst.s_addr));
    return success == 1;
}

- (BOOL)isIPv6Address:(NSString *)addr {
    if (addr == nil) {
        return NO;
    }
    const char *utf8 = [addr UTF8String];
    // Check valid IPv6.
    struct in6_addr dst6;
    int success = inet_pton(AF_INET6, utf8, &dst6);
    return (success == 1);
}

@end
