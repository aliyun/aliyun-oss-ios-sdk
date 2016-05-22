//
//  OSSIPv6PrefixResolver.m
//
//  Created by lingkun on 16/5/16.
//  Edit by zhouzhuo on 2016/5/22
//  Copyright © 2016年 Ali. All rights reserved.

#import "OSSIPv6PrefixResolver.h"
#import "OSSLog.h"

#import <Foundation/Foundation.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>

static const __uint8_t NS_PREFIX_32[4] = {0x20, 0x01, 0x0d, 0xb8};
static const __uint8_t NS_PREFIX_40[5] = {0x20, 0x01, 0x0d, 0xb8, 0x01};
static const __uint8_t NS_PREFIX_48[6] = {0x20, 0x01, 0x0d, 0xb8, 0x01, 0x22};
static const __uint8_t NS_PREFIX_56[7] = {0x20, 0x01, 0x0d, 0xb8, 0x01, 0x22, 0x03};
static const __uint8_t NS_PREFIX_64[8] = {0x20, 0x01, 0x0d, 0xb8, 0x01, 0x22, 0x03, 0x44};
static const __uint8_t NS_PREFIX_96[12] = {0x20, 0x01, 0x0d, 0xb8, 0x01, 0x22, 0x03, 0x44, 0x00, 0x00, 0x00, 0x00};
static const __uint8_t WK_PREFIX_96[12] = {0x00, 0x64, 0xff, 0x9b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

static const __uint8_t* V6_PREFIX_CONTENT_TABLE[7] = {
    WK_PREFIX_96,
    NS_PREFIX_32,
    NS_PREFIX_40,
    NS_PREFIX_48,
    NS_PREFIX_56,
    NS_PREFIX_64,
    NS_PREFIX_96};

static const __uint8_t V6_PREFIX_SIZE_TABLE[7] = {
    sizeof(WK_PREFIX_96)/sizeof(__uint8_t),
    sizeof(NS_PREFIX_32)/sizeof(__uint8_t),
    sizeof(NS_PREFIX_40)/sizeof(__uint8_t),
    sizeof(NS_PREFIX_48)/sizeof(__uint8_t),
    sizeof(NS_PREFIX_56)/sizeof(__uint8_t),
    sizeof(NS_PREFIX_64)/sizeof(__uint8_t),
    sizeof(NS_PREFIX_96)/sizeof(__uint8_t)};

static const __uint8_t V6_PREFIX_TABLE_SIZE = 7;

typedef enum {
    IPv6PrefixUnResolved = 0,
    IPv6PrefixResolving,
    IPv6PrefixResolved
} IPv6PrefixResolveStatus;

@implementation OSSIPv6PrefixResolver {
    IPv6PrefixResolveStatus ipv6PrefixResolveStatus;
    __uint8_t *ipv6Prefix;
    int prefixLen;
}

- (instancetype)init {
    if (self = [super init]) {
        ipv6PrefixResolveStatus = IPv6PrefixUnResolved;
        ipv6Prefix = (__uint8_t *)V6_PREFIX_CONTENT_TABLE[0];
        prefixLen = V6_PREFIX_SIZE_TABLE[0];
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

/**
 *	@brief	主动更新IPv6 Prefix
 */
- (void)updateIPv6Prefix {
    @synchronized(self) {
        ipv6PrefixResolveStatus = IPv6PrefixUnResolved;
        [self resolveIPv6Prefix:ipv6Prefix];
    }
}

- (BOOL)isIPv6Prefix:(__uint8_t *)v6Prefix
       withPrefixLen:(int)pLen
              withIP:(__uint8_t *)ip
           withIPLen:(int)ipLen {
    for (int i = 0; i < pLen && i < ipLen; i++) {
        if (*(v6Prefix + i) != *(ip + i)) {
            return NO;
        }
    }
    return YES;
}

- (__uint8_t)resolveIPv6Prefix:(__uint8_t *)prefix {
    if ( !prefix ) {
        return 0;
    }
    __uint8_t len = prefixLen;
    memcpy(prefix, ipv6Prefix, prefixLen);
    @synchronized(self) {
        if (ipv6PrefixResolveStatus==IPv6PrefixUnResolved ) {
            ipv6PrefixResolveStatus = IPv6PrefixResolving;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                struct addrinfo hints, *addr;
                memset(&hints, 0, sizeof(hints));
                hints.ai_family = PF_INET6;
                hints.ai_socktype = SOCK_STREAM;
                hints.ai_flags = AI_DEFAULT;
                
                if (0 != getaddrinfo("ipv4only.arpa", "http", &hints, &addr)) {
                    ipv6PrefixResolveStatus = IPv6PrefixUnResolved;
                    return;
                }
                
                if (addr && AF_INET6 == addr->ai_addr->sa_family) {
                    struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)(addr->ai_addr);
                    if ( !addr6 ) {
                        ipv6PrefixResolveStatus = IPv6PrefixUnResolved;
                        return;
                    }
                    
                    __uint8_t* u8 = addr6->sin6_addr.__u6_addr.__u6_addr8;
                    for (__uint8_t i=0; i < V6_PREFIX_TABLE_SIZE; i++) {
                        if ([self isIPv6Prefix:(__uint8_t *)V6_PREFIX_CONTENT_TABLE[i]
                                 withPrefixLen:V6_PREFIX_SIZE_TABLE[i]
                                        withIP:u8
                                     withIPLen:16]) {
                            
                            ipv6Prefix = (__uint8_t *)V6_PREFIX_CONTENT_TABLE[i];
                            prefixLen = V6_PREFIX_SIZE_TABLE[i];
                            ipv6PrefixResolveStatus = IPv6PrefixResolved;
                            break;
                        }
                    }
                    ipv6PrefixResolveStatus = IPv6PrefixUnResolved;
                }
                
            });
        }
    }
    
    return len;
}

- (NSString *)convertIPv4toIPv6:(NSString *)ipv4 {
    if ([ipv4 length] <= 0) {
        return nil;
    }
    
    __uint8_t ipv6[16] = {0x00};
    __uint8_t length = [self resolveIPv6Prefix:ipv6];
    
    if (length <= 0) {
        return nil;
    }
    
    in_addr_t addr_v4 = inet_addr([ipv4 UTF8String]);
    
    // 按length的不同情况进行处理
    if (length==4 || length==12) { //32 bits or 96 bits
        ipv6[length+0] |= (__uint8_t)(addr_v4>>0 & 0xff);
        ipv6[length+1] |= (__uint8_t)(addr_v4>>8 & 0xff);
        ipv6[length+2] |= (__uint8_t)(addr_v4>>16 & 0xff);
        ipv6[length+3] |= (__uint8_t)(addr_v4>>24 & 0xff);
    }
    else if (length == 5) { //40 bits  :a.b.c.0.d
        ipv6[length+0] |= (__uint8_t)(addr_v4>>0 & 0xff);
        ipv6[length+1] |= (__uint8_t)(addr_v4>>8 & 0xff);
        ipv6[length+2] |= (__uint8_t)(addr_v4>>16 & 0xff);
        ipv6[length+4] |= (__uint8_t)(addr_v4>>24 & 0xff);
    }
    else if (length == 6) { //48 bits   :a.b.0.c.d
        ipv6[length+0] |= (__uint8_t)(addr_v4>>0 & 0xff);
        ipv6[length+1] |= (__uint8_t)(addr_v4>>8 & 0xff);
        ipv6[length+3] |= (__uint8_t)(addr_v4>>16 & 0xff);
        ipv6[length+4] |= (__uint8_t)(addr_v4>>24 & 0xff);
    }
    else if (length == 7) { //56 bits   :a.0.b.c.d
        ipv6[length+0] |= (__uint8_t)(addr_v4>>0 & 0xff);
        ipv6[length+2] |= (__uint8_t)(addr_v4>>8 & 0xff);
        ipv6[length+3] |= (__uint8_t)(addr_v4>>16 & 0xff);
        ipv6[length+4] |= (__uint8_t)(addr_v4>>24 & 0xff);
    }
    else if (length == 8) { //64 bits   :0.a.b.c.d
        ipv6[length+1] |= (__uint8_t)(addr_v4>>0 & 0xff);
        ipv6[length+2] |= (__uint8_t)(addr_v4>>8 & 0xff);
        ipv6[length+3] |= (__uint8_t)(addr_v4>>16 & 0xff);
        ipv6[length+4] |= (__uint8_t)(addr_v4>>24 & 0xff);
    }
    
    // 构造IPv6的结构
    char addr_text[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
    if(inet_ntop(AF_INET6, ipv6, addr_text, INET6_ADDRSTRLEN)) {
        NSString *ret = [NSString stringWithUTF8String:addr_text];
        return ret;
    }
    return nil;
}

@end