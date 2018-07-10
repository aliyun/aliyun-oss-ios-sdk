//
//  OSSHttpdns.m
//  AliyunOSSiOS
//
//  Created by zhouzhuo on 5/1/16.
//  Copyright © 2016 zhouzhuo. All rights reserved.
//

#import "OSSLog.h"
#import "OSSHttpdns.h"
#import "OSSIPv6Adapter.h"

NSString * const OSS_HTTPDNS_SERVER_IP = @"203.107.1.1";
NSString * const OSS_HTTPDNS_SERVER_PORT = @"80";

NSString * const ACCOUNT_ID = @"181345";
NSTimeInterval const MAX_ENDURABLE_EXPIRED_TIME_IN_SECOND = 60; // The DNS entry's expiration time in seconds. After it expires, the entry is invalid.
NSTimeInterval const PRERESOLVE_IN_ADVANCE_IN_SECOND = 10; // Once the remaining valid time of an DNS entry is less than this number, issue a DNS request to prefetch the data.

@interface IpObject : NSObject

@property (nonatomic, copy) NSString * ip;
@property (nonatomic, assign) NSTimeInterval expiredTime;

@end

@implementation IpObject
@end


@implementation OSSHttpdns {
    NSMutableDictionary * gHostIpMap;
    NSMutableSet * penddingSet;
}

+ (instancetype)sharedInstance {
    static OSSHttpdns * sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [OSSHttpdns new];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        gHostIpMap = [NSMutableDictionary new];
        penddingSet = [NSMutableSet new];
    }
    return self;
}

/**
 *  OSS SDK specific
 *
 *  @param host it needs strictly follow the domain's format, such as oss-cn-hangzhou.aliyuncs.com
 *
 *  @return an ip in the ip list of the resolved host.
 */
- (NSString *)asynGetIpByHost:(NSString *)host {
    IpObject * ipObject = [gHostIpMap objectForKey:host];
    if (!ipObject) {

        // if the host is not resolved, asynchronously resolve it and return nil
        [self resolveHost:host];
        return nil;
    } else if ([[NSDate date] timeIntervalSince1970] - ipObject.expiredTime > MAX_ENDURABLE_EXPIRED_TIME_IN_SECOND) {

        // If the entry is expired, asynchronously resolve it and return nil.
        [self resolveHost:host];
        return nil;
    } else if (ipObject.expiredTime -[[NSDate date] timeIntervalSince1970] < PRERESOLVE_IN_ADVANCE_IN_SECOND) {

        // If the entry is about to expire, asynchronously resolve it and return the current value.
        [self resolveHost:host];
        return ipObject.ip;
    } else {

        // returns the current result.
        return ipObject.ip;
    }
}

/**
 *  resolve the host asynchronously

 *  If the host is being resolved, the call will be skipped.
 *
 *  @param host the host to resolve
 */
- (void)resolveHost:(NSString *)host {

    @synchronized (self) {
        if ([penddingSet containsObject:host]) {
            return;
        } else {
            [penddingSet addObject:host];
        }
    }

    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/d?host=%@", [[OSSIPv6Adapter getInstance] handleIpv4Address:OSS_HTTPDNS_SERVER_IP], ACCOUNT_ID, host]];
    NSURLSession * session = [NSURLSession sharedSession];

    NSURLSessionDataTask * dataTask = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        IpObject * ipObject = nil;
        NSUInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        if (statusCode != 200) {
            OSSLogError(@"Httpdns resolve host: %@ failed, responseCode: %lu", host, (unsigned long)statusCode);
        } else {
            NSError *error = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];

            NSTimeInterval expiredTime = [[NSDate new] timeIntervalSince1970] + [[json objectForKey:@"ttl"] longLongValue];

            NSArray *ips = [json objectForKey:@"ips"];
            if (ips == nil || [ips count] == 0) {
                OSSLogError(@"Httpdns resolve host: %@ failed, ip list empty.", host);
            } else {
                NSString * ip = ips[0];
                ipObject = [IpObject new];
                ipObject.expiredTime = expiredTime;
                ipObject.ip = ip;
                OSSLogDebug(@"Httpdns resolve host: %@ success, ip: %@, expiredTime: %lf", host, ipObject.ip, ipObject.expiredTime);
            }
        }

        @synchronized (self) {
            if (ipObject) {
                gHostIpMap[host] = ipObject;
            }

            [penddingSet removeObject:host];
        }
    }];

    [dataTask resume];
}

@end
