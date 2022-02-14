//
//  OSSClient.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSClient.h"
#import "OSSDefine.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"
#import "OSSExecutor.h"
#import "OSSNetworking.h"
#import "OSSXMLDictionary.h"

#import "OSSNetworkingRequestDelegate.h"
#import "OSSAllRequestNeededMessage.h"
#import "OSSURLRequestRetryHandler.h"
#import "OSSHttpResponseParser.h"

static NSString * const kClientRecordNameWithCommonPrefix = @"oss_partInfos_storage_name";
static NSString * const kClientRecordNameWithCRC64Suffix = @"-crc64";
static NSString * const kClientRecordNameWithSequentialSuffix = @"-sequential";
static NSUInteger const kClientMaximumOfChunks = 5000;   //max part number
static NSUInteger const kPartSizeAlign = 4 * 1024;   // part size byte alignment

static NSString * const kClientErrorMessageForEmptyFile = @"the length of file should not be 0!";
static NSString * const kClientErrorMessageForCancelledTask = @"This task has been cancelled!";

/**
 * extend OSSRequest to include the ref to networking request object
 */
@interface OSSRequest ()

@property (nonatomic, strong) OSSNetworkingRequestDelegate * requestDelegate;

@end

@interface OSSClient()

- (void)enableCRC64WithFlag:(OSSRequestCRCFlag)flag requestDelegate:(OSSNetworkingRequestDelegate *)delegate;

@end

@implementation OSSClient

static NSObject *lock;

- (instancetype)initWithEndpoint:(NSString *)endpoint credentialProvider:(id<OSSCredentialProvider>)credentialProvider {
    return [self initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:[OSSClientConfiguration new]];
}

- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>)credentialProvider
             clientConfiguration:(OSSClientConfiguration *)conf {
    if (self = [super init]) {
        if (!lock) {
            lock = [NSObject new];
        }

        NSOperationQueue * queue = [NSOperationQueue new];
        // using for resumable upload and compat old interface
        queue.maxConcurrentOperationCount = 3;
        _ossOperationExecutor = [OSSExecutor executorWithOperationQueue:queue];
        
        if (![endpoint oss_isNotEmpty]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"endpoint should not be nil or empty!"];
        }
        
        if ([endpoint rangeOfString:@"://"].location == NSNotFound) {
            endpoint = [@"https://" stringByAppendingString:endpoint];
        }
        
        NSURL *endpointURL = [NSURL URLWithString:endpoint];
        
        self.endpoint = [endpoint oss_trim];
        self.credentialProvider = credentialProvider;
        self.clientConfiguration = conf;

        OSSNetworkingConfiguration * netConf = [OSSNetworkingConfiguration new];
        if (conf) {
            netConf.maxRetryCount = conf.maxRetryCount;
            netConf.timeoutIntervalForRequest = conf.timeoutIntervalForRequest;
            netConf.timeoutIntervalForResource = conf.timeoutIntervalForResource;
            netConf.enableBackgroundTransmitService = conf.enableBackgroundTransmitService;
            netConf.backgroundSessionIdentifier = conf.backgroundSesseionIdentifier;
            netConf.proxyHost = conf.proxyHost;
            netConf.proxyPort = conf.proxyPort;
            netConf.maxConcurrentRequestCount = conf.maxConcurrentRequestCount;
        }
        self.networking = [[OSSNetworking alloc] initWithConfiguration:netConf];
    }
    return self;
}

- (OSSTask *)invokeRequest:(OSSNetworkingRequestDelegate *)request requireAuthentication:(BOOL)requireAuthentication {
    /* if content-type haven't been set, we set one */
    if (!request.allNeededMessage.contentType.oss_isNotEmpty
        && ([request.allNeededMessage.httpMethod isEqualToString:@"POST"] || [request.allNeededMessage.httpMethod isEqualToString:@"PUT"])) {

        request.allNeededMessage.contentType = [OSSUtil detemineMimeTypeForFilePath:request.uploadingFileURL.path               uploadName:request.allNeededMessage.objectKey];
    }

    // Checks if the endpoint is in the excluded CName list.
    [self.clientConfiguration.cnameExcludeList enumerateObjectsUsingBlock:^(NSString *exclude, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self.endpoint hasSuffix:exclude]) {
            request.allNeededMessage.isHostInCnameExcludeList = YES;
            *stop = YES;
        }
    }];

    id<OSSRequestInterceptor> uaSetting = [[OSSUASettingInterceptor alloc] initWithClientConfiguration:self.clientConfiguration];
    [request.interceptors addObject:uaSetting];

    /* check if the authentication is required */
    if (requireAuthentication) {
        id<OSSRequestInterceptor> signer = [[OSSSignerInterceptor alloc] initWithCredentialProvider:self.credentialProvider];
        [request.interceptors addObject:signer];
    }

    request.isPathStyleAccessEnable = self.clientConfiguration.isPathStyleAccessEnable;
    request.isCustomPathPrefixEnable = self.clientConfiguration.isCustomPathPrefixEnable;
    
    return [_networking sendRequest:request];
}


# pragma mark - Private Methods

- (void)enableCRC64WithFlag:(OSSRequestCRCFlag)flag requestDelegate:(OSSNetworkingRequestDelegate *)delegate
{
    switch (flag) {
        case OSSRequestCRCOpen:
            delegate.crc64Verifiable = YES;
            break;
        case OSSRequestCRCClosed:
            delegate.crc64Verifiable = NO;
            break;
        default:
            delegate.crc64Verifiable = self.clientConfiguration.crc64Verifiable;
            break;
    }
}

#pragma mark - sequential multipart upload

- (OSSTask *)checkPutObjectFileURL:(OSSPutObjectRequest *)request {
    NSError *error = nil;
    if (!request.uploadingFileURL || ![request.uploadingFileURL.path oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"Please check your request's uploadingFileURL!"}];
    } else {
        NSFileManager *dfm = [NSFileManager defaultManager];
        NSDictionary *attributes = [dfm attributesOfItemAtPath:request.uploadingFileURL.path error:&error];
        unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
        if (!error && fileSize == 0) {
            error = [NSError errorWithDomain:OSSClientErrorDomain
                                        code:OSSClientErrorCodeInvalidArgument
                                    userInfo:@{OSSErrorMessageTOKEN: kClientErrorMessageForEmptyFile}];
        }
    }
    
    if (error) {
        return [OSSTask taskWithError:error];
    } else {
        return [OSSTask taskWithResult:nil];
    }
}

@end

@implementation OSSClient (Object)

- (OSSTask *)putObject:(OSSPutObjectRequest *)request
{
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    
    if (request.uploadingData) {
        requestDelegate.uploadingData = request.uploadingData;
        if (requestDelegate.crc64Verifiable)
        {
            NSMutableData *mutableData = [NSMutableData dataWithData:request.uploadingData];
            requestDelegate.contentCRC = [NSString stringWithFormat:@"%llu",[mutableData oss_crc64]];
        }
    }
    if (request.uploadingFileURL) {
        OSSTask *checkIfEmptyTask = [self checkPutObjectFileURL:request];
        if (checkIfEmptyTask.error) {
            return checkIfEmptyTask;
        }
        requestDelegate.uploadingFileURL = request.uploadingFileURL;
    }
    
    if (request.uploadProgress) {
        requestDelegate.uploadProgress = request.uploadProgress;
    }
    if (request.uploadRetryCallback) {
        requestDelegate.retryCallback = request.uploadRetryCallback;
    }
    
    [headerParams oss_setObject:[request.callbackParam base64JsonString] forKey:OSSHttpHeaderXOSSCallback];
    [headerParams oss_setObject:[request.callbackVar base64JsonString] forKey:OSSHttpHeaderXOSSCallbackVar];
    [headerParams oss_setObject:request.contentDisposition forKey:OSSHttpHeaderContentDisposition];
    [headerParams oss_setObject:request.contentEncoding forKey:OSSHttpHeaderContentEncoding];
    [headerParams oss_setObject:request.expires forKey:OSSHttpHeaderExpires];
    [headerParams oss_setObject:request.cacheControl forKey:OSSHttpHeaderCacheControl];
    
    OSSHttpResponseParser *responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObject];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    OSSAllRequestNeededMessage *neededMsg = [[OSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.contentMd5 = request.contentMd5;
    neededMsg.contentType = request.contentType;
    neededMsg.headerParams = headerParams;
    neededMsg.contentSHA1 = request.contentSHA1;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

@end
