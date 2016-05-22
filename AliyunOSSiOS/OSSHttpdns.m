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

NSString * const HTTPDNS_SERVER_IP = @"203.107.1.1";
NSString * const HTTPDNS_SERVER_PORT = @"80";

NSString * const ACCOUNT_ID = @"181345";
NSTimeInterval const MAX_ENDURABLE_EXPIRED_TIME_IN_SECOND = 60; // 如果离TTL到期已经过去某个秒数，不再使用该解析结果
NSTimeInterval const PRERESOLVE_IN_ADVANCE_IN_SECOND = 10; // 如果发现距离TTL到期小于某个秒数，提前发起更新

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
 *  OSS SDK专用
 *
 *  @param host 需要严格遵守domain标准格式，如 oss-cn-hangzhou.aliyuncs.com
 *
 *  @return 解析host得到的ip列表中的某个ip
 */
- (NSString *)asynGetIpByHost:(NSString *)host {
    IpObject * ipObject = [gHostIpMap objectForKey:host];
    if (!ipObject) {

        // 如果还没解析过该host，发起解析，返回nil
        [self resolveHost:host];
        return nil;
    } else if ([[NSDate date] timeIntervalSince1970] - ipObject.expiredTime > MAX_ENDURABLE_EXPIRED_TIME_IN_SECOND) {

        // 如果该host的解析结果已经过期太久，发起解析，返回nil
        [self resolveHost:host];
        return nil;
    } else if (ipObject.expiredTime -[[NSDate date] timeIntervalSince1970] < PRERESOLVE_IN_ADVANCE_IN_SECOND) {

        // 如果该host的解析结果即将过期，或已经过期一段可以接受的时间，发起解析，并返回之前的结果
        [self resolveHost:host];
        return ipObject.ip;
    } else {

        // 还未过期，直接返回结果
        return ipObject.ip;
    }
}

/**
 *  发起对一个host的解析，异步执行

 *  如果该host已经在解析中，那么后续的请求都会被放弃，直到它解析完成
 *
 *  @param host 需要解析的ip
 */
- (void)resolveHost:(NSString *)host {

    @synchronized (self) {
        if ([penddingSet containsObject:host]) {
            return;
        } else {
            [penddingSet addObject:host];
        }
    }

    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/%@/d?host=%@", [[OSSIPv6Adapter getInstance] handleIpv4Address:HTTPDNS_SERVER_IP], ACCOUNT_ID, host]];
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
