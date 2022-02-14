//
//  OSSTestUtils.m
//  AliyunOSSiOSTests
//
//  Created by jingdan on 2018/2/24.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSTestUtils.h"
#import "OSSTestHttpResponseParser.h"
#import "OSSTestMacros.h"

@interface OSSClient(Test)

- (OSSTask *)invokeRequest:(OSSNetworkingRequestDelegate *)request requireAuthentication:(BOOL)requireAuthentication;

@end

@implementation OSSTestUtils

+ (void) putTestDataWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket
{
    NSString *objectKey = key;
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = bucket;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    OSSTask * task = [client putObject:request];
    [task waitUntilFinished];
}

+ (OSSTask *)getObjectWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket fileUrl:(NSURL *)url {
    OSSNetworkingRequestDelegate * requestDelegate = [OSSNetworkingRequestDelegate new];

    OSSTestHttpResponseParser *responseParser = [[OSSTestHttpResponseParser alloc] initForOperationType:1];
    responseParser.downloadingFileURL = url;
    
    requestDelegate.responseParser = responseParser;
    OSSAllRequestNeededMessage *allNeededMessage = [[OSSAllRequestNeededMessage alloc] init];
    allNeededMessage.endpoint = client.endpoint;
    allNeededMessage.httpMethod = @"GET";
    allNeededMessage.bucketName = bucket;
    allNeededMessage.objectKey = key;
    allNeededMessage.date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    
    requestDelegate.allNeededMessage = allNeededMessage;
    requestDelegate.operType = 1;

    return [client invokeRequest:requestDelegate requireAuthentication:YES];
}

+ (OSSTask *) headObjectWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket {
    OSSNetworkingRequestDelegate * requestDelegate = [OSSNetworkingRequestDelegate new];

    OSSTestHttpResponseParser *responseParser = [[OSSTestHttpResponseParser alloc] initForOperationType:2];
    
    requestDelegate.responseParser = responseParser;
    OSSAllRequestNeededMessage *allNeededMessage = [[OSSAllRequestNeededMessage alloc] init];
    allNeededMessage.endpoint = client.endpoint;
    allNeededMessage.httpMethod = @"HEAD";
    allNeededMessage.bucketName = bucket;
    allNeededMessage.objectKey = key;
    allNeededMessage.date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    
    requestDelegate.allNeededMessage = allNeededMessage;
    requestDelegate.operType = 2;

    return [client invokeRequest:requestDelegate requireAuthentication:YES];
}


+ (OSSFederationToken *)getSts {
    NSURL * url = [NSURL URLWithString:OSS_STSTOKEN_URL];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        [tcs setError:error];
                                                        return;
                                                    }
                                                    [tcs setResult:data];
                                                }];
    [sessionTask resume];
    [tcs.task waitUntilFinished];
    if (tcs.task.error) {
        return nil;
    } else {
        NSData* data = tcs.task.result;
        NSDictionary * object = [NSJSONSerialization JSONObjectWithData:data
                                                                options:kNilOptions
                                                                  error:nil];
        int statusCode = [[object objectForKey:@"StatusCode"] intValue];
        if (statusCode == 200) {
            OSSFederationToken * token = [OSSFederationToken new];
            // All the entries below are mandatory.
            token.tAccessKey = [object objectForKey:@"AccessKeyId"];
            token.tSecretKey = [object objectForKey:@"AccessKeySecret"];
            token.tToken = [object objectForKey:@"SecurityToken"];
            token.expirationTimeInGMTFormat = [object objectForKey:@"Expiration"];
            OSSLogDebug(@"token: %@ %@ %@ %@", token.tAccessKey, token.tSecretKey, token.tToken, [object objectForKey:@"Expiration"]);
            return token;
        }else{
            return nil;
        }
        
    }
}

@end
