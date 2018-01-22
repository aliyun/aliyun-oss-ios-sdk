//
//  OSSHttpResponseParser.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSHttpResponseParser.h"

#import "NSMutableData+OSS_CRC.h"
#import "OSSXMLDictionary.h"
#import "OSSDefine.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"


@implementation OSSHttpResponseParser {
    
    OSSOperationType _operationTypeForThisParser;
    
    NSFileHandle * _fileHandle;
    NSMutableData * _collectingData;
    NSHTTPURLResponse * _response;
    uint64_t _crc64ecma;
}

- (void)reset {
    _collectingData = nil;
    _fileHandle = nil;
    _response = nil;
}

- (instancetype)initForOperationType:(OSSOperationType)operationType {
    if (self = [super init]) {
        _operationTypeForThisParser = operationType;
    }
    return self;
}

- (void)consumeHttpResponse:(NSHTTPURLResponse *)response {
    _response = response;
}

- (OSSTask *)consumeHttpResponseBody:(NSData *)data
{
    if (_crc64Verifiable&&(_operationTypeForThisParser == OSSOperationTypeGetObject))
    {
        NSMutableData *mutableData = [NSMutableData dataWithData:data];
        if (_crc64ecma != 0)
        {
            _crc64ecma = [OSSUtil crc64ForCombineCRC1:_crc64ecma
                                                 CRC2:[mutableData oss_crc64]
                                               length:mutableData.length];
        }else
        {
            _crc64ecma = [mutableData oss_crc64];
        }
    }
    
    if (self.onRecieveBlock) {
        self.onRecieveBlock(data);
        return [OSSTask taskWithResult:nil];
    }
    
    NSError * error;
    if (self.downloadingFileURL)
    {
        if (!_fileHandle)
        {
            NSFileManager * fm = [NSFileManager defaultManager];
            NSString * dirName = [[self.downloadingFileURL path] stringByDeletingLastPathComponent];
            if (![fm fileExistsAtPath:dirName])
            {
                [fm createDirectoryAtPath:dirName withIntermediateDirectories:YES attributes:nil error:&error];
            }
            if (![fm fileExistsAtPath:dirName] || error)
            {
                return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:@{OSSErrorMessageTOKEN: [NSString stringWithFormat:@"Can't create dir at %@", dirName]}]];
            }
            [fm createFileAtPath:[self.downloadingFileURL path] contents:nil attributes:nil];
            if (![fm fileExistsAtPath:[self.downloadingFileURL path]])
            {
                return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:@{OSSErrorMessageTOKEN: [NSString stringWithFormat:@"Can't create file at %@", [self.downloadingFileURL path]]}]];
            }
            _fileHandle = [NSFileHandle fileHandleForWritingToURL:self.downloadingFileURL error:&error];
            if (error)
            {
                return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:[error userInfo]]];
            }
            [_fileHandle writeData:data];
        } else
        {
            @try {
                [_fileHandle writeData:data];
            }
            @catch (NSException *exception) {
                return [OSSTask taskWithError:[NSError errorWithDomain:OSSServerErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:@{OSSErrorMessageTOKEN: [exception description]}]];
            }
        }
    } else
    {
        if (!_collectingData)
        {
            _collectingData = [[NSMutableData alloc] initWithData:data];
        }
        else
        {
            [_collectingData appendData:data];
        }
    }
    return [OSSTask taskWithResult:nil];
}

- (void)parseResponseHeader:(NSHTTPURLResponse *)response toResultObject:(OSSResult *)result
{
    result.httpResponseCode = [_response statusCode];
    result.httpResponseHeaderFields = [NSDictionary dictionaryWithDictionary:[_response allHeaderFields]];
    [[_response allHeaderFields] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString * keyString = (NSString *)key;
        if ([keyString isEqualToString:@"x-oss-request-id"])
        {
            result.requestId = obj;
        }
        else if ([keyString isEqualToString:@"x-oss-hash-crc64ecma"])
        {
            result.remoteCRC64ecma = obj;
        }
    }];
}

- (NSDictionary *)parseResponseHeaderToGetMeta:(NSHTTPURLResponse *)response
{
    NSMutableDictionary * meta = [NSMutableDictionary new];
    
    /* define a constant array to contain all meta header name */
    static NSArray * OSSObjectMetaFieldNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OSSObjectMetaFieldNames = @[@"Content-Type", @"Content-Length", @"Etag", @"Last-Modified", @"x-oss-request-id", @"x-oss-object-type",
                                    @"If-Modified-Since", @"If-Unmodified-Since", @"If-Match", @"If-None-Match"];
    });
    /****************************************************************/
    
    [[_response allHeaderFields] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString * keyString = (NSString *)key;
        if ([OSSObjectMetaFieldNames containsObject:keyString] || [keyString hasPrefix:@"x-oss-meta"]) {
            [meta setObject:obj forKey:key];
        }
    }];
    return meta;
}

- (nullable id)constructResultObject
{
    if (self.onRecieveBlock)
    {
        return nil;
    }
    
    switch (_operationTypeForThisParser)
    {
        case OSSOperationTypeGetService:
        {
            OSSGetServiceResult * getServiceResult = [OSSGetServiceResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:getServiceResult];
            }
            if (_collectingData)
            {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"Get service dict: %@", parseDict);
                if (parseDict)
                {
                    getServiceResult.ownerId = [[parseDict objectForKey:OSSOwnerXMLTOKEN] objectForKey:OSSIDXMLTOKEN];
                    getServiceResult.ownerDispName = [[parseDict objectForKey:OSSOwnerXMLTOKEN] objectForKey:OSSDisplayNameXMLTOKEN];
                    getServiceResult.prefix = [parseDict objectForKey:OSSPrefixXMLTOKEN];
                    getServiceResult.marker = [parseDict objectForKey:OSSMarkerXMLTOKEN];
                    getServiceResult.maxKeys = [[parseDict objectForKey:OSSMaxKeysXMLTOKEN] intValue];
                    getServiceResult.isTruncated = [[parseDict objectForKey:OSSIsTruncatedXMLTOKEN] boolValue];
                    
                    id bucketObject = [[parseDict objectForKey:OSSBucketsXMLTOKEN] objectForKey:OSSBucketXMLTOKEN];
                    if ([bucketObject isKindOfClass:[NSArray class]]) {
                        getServiceResult.buckets = bucketObject;
                    } else if ([bucketObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:bucketObject];
                        getServiceResult.buckets = arr;
                    } else {
                        getServiceResult.buckets = nil;
                    }
                }
            }
            return getServiceResult;
        }
            
        case OSSOperationTypeCreateBucket:
        {
            OSSCreateBucketResult * createBucketResult = [OSSCreateBucketResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:createBucketResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Location"]) {
                        createBucketResult.location = obj;
                        *stop = YES;
                    }
                }];
            }
            return createBucketResult;
        }
            
        case OSSOperationTypeGetBucketACL:
        {
            OSSGetBucketACLResult * getBucketACLResult = [OSSGetBucketACLResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:getBucketACLResult];
            }
            if (_collectingData)
            {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"Get service dict: %@", parseDict);
                if (parseDict)
                {
                    getBucketACLResult.aclGranted = [[parseDict objectForKey:OSSAccessControlListXMLTOKEN] objectForKey:OSSGrantXMLTOKEN];
                }
            }
            return getBucketACLResult;
        }
            
        case OSSOperationTypeDeleteBucket:
        {
            OSSDeleteBucketResult * deleteBucketResult = [OSSDeleteBucketResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:deleteBucketResult];
            }
            return deleteBucketResult;
        }
            
        case OSSOperationTypeGetBucket:
        {
            OSSGetBucketResult * getBucketResult = [OSSGetBucketResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:getBucketResult];
            }
            if (_collectingData) {
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"Get bucket dict: %@", parsedDict);
                
                if (parsedDict) {
                    getBucketResult.bucketName = [parsedDict objectForKey:OSSNameXMLTOKEN];
                    getBucketResult.prefix = [parsedDict objectForKey:OSSPrefixXMLTOKEN];
                    getBucketResult.marker = [parsedDict objectForKey:OSSMarkerXMLTOKEN];
                    getBucketResult.nextMarker = [parsedDict objectForKey:OSSNextMarkerXMLTOKEN];
                    getBucketResult.maxKeys = (int32_t)[[parsedDict objectForKey:OSSMaxKeysXMLTOKEN] integerValue];
                    getBucketResult.delimiter = [parsedDict objectForKey:OSSDelimiterXMLTOKEN];
                    getBucketResult.isTruncated = [[parsedDict objectForKey:OSSIsTruncatedXMLTOKEN] boolValue];
                    
                    id contentObject = [parsedDict objectForKey:OSSContentsXMLTOKEN];
                    if ([contentObject isKindOfClass:[NSArray class]]) {
                        getBucketResult.contents = contentObject;
                    } else if ([contentObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:contentObject];
                        getBucketResult.contents = arr;
                    } else {
                        getBucketResult.contents = nil;
                    }
                    
                    NSMutableArray * commentPrefixesArr = [NSMutableArray new];
                    id commentPrefixes = [parsedDict objectForKey:OSSCommonPrefixesXMLTOKEN];
                    if ([commentPrefixes isKindOfClass:[NSArray class]]) {
                        for (NSDictionary * prefix in commentPrefixes) {
                            [commentPrefixesArr addObject:[prefix objectForKey:@"Prefix"]];
                        }
                    } else if ([commentPrefixes isKindOfClass:[NSDictionary class]]) {
                        [commentPrefixesArr addObject:[(NSDictionary *)commentPrefixes objectForKey:@"Prefix"]];
                    } else {
                        commentPrefixesArr = nil;
                    }
                    
                    getBucketResult.commentPrefixes = commentPrefixesArr;
                }
            }
            return getBucketResult;
        }
            
        case OSSOperationTypeHeadObject:
        {
            OSSHeadObjectResult * headObjectResult = [OSSHeadObjectResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:headObjectResult];
                headObjectResult.objectMeta = [self parseResponseHeaderToGetMeta:_response];
            }
            return headObjectResult;
        }
            
        case OSSOperationTypeGetObject:
        {
            OSSGetObjectResult * getObejctResult = [OSSGetObjectResult new];
            OSSLogDebug(@"GetObjectResponse: %@", _response);
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:getObejctResult];
                getObejctResult.objectMeta = [self parseResponseHeaderToGetMeta:_response];
                if (_crc64ecma != 0)
                {
                    getObejctResult.localCRC64ecma = [NSString stringWithFormat:@"%llu",_crc64ecma];
                }
            }
            if (_fileHandle) {
                [_fileHandle closeFile];
            }
            
            if (_collectingData) {
                getObejctResult.downloadedData = _collectingData;
            }
            return getObejctResult;
        }
            
        case OSSOperationTypePutObject:
        {
            OSSPutObjectResult * putObjectResult = [OSSPutObjectResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:putObjectResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Etag"]) {
                        putObjectResult.eTag = obj;
                        *stop = YES;
                    }
                }];
            }
            if (_collectingData) {
                putObjectResult.serverReturnJsonString = [[NSString alloc] initWithData:_collectingData encoding:NSUTF8StringEncoding];
            }
            return putObjectResult;
        }
            
        case OSSOperationTypeAppendObject:
        {
            OSSAppendObjectResult * appendObjectResult = [OSSAppendObjectResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:appendObjectResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Etag"]) {
                        appendObjectResult.eTag = obj;
                    }
                    if ([((NSString *)key) isEqualToString:@"x-oss-next-append-position"]) {
                        appendObjectResult.xOssNextAppendPosition = [((NSString *)obj) longLongValue];
                    }
                }];
            }
            return appendObjectResult;
        }
            
        case OSSOperationTypeDeleteObject: {
            OSSDeleteObjectResult * deleteObjectResult = [OSSDeleteObjectResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:deleteObjectResult];
            }
            return deleteObjectResult;
        }
            
        case OSSOperationTypePutObjectACL: {
            OSSPutObjectACLResult * putObjectACLResult = [OSSPutObjectACLResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:putObjectACLResult];
            }
            return putObjectACLResult;
        }
            
        case OSSOperationTypeCopyObject: {
            OSSCopyObjectResult * copyObjectResult = [OSSCopyObjectResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:copyObjectResult];
            }
            if (_collectingData) {
                OSSLogVerbose(@"copy object dict: %@", [NSDictionary oss_dictionaryWithXMLData:_collectingData]);
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parsedDict) {
                    copyObjectResult.lastModifed = [parsedDict objectForKey:OSSLastModifiedXMLTOKEN];
                    copyObjectResult.eTag = [parsedDict objectForKey:OSSETagXMLTOKEN];
                }
            }
            return copyObjectResult;
        }
            
        case OSSOperationTypeInitMultipartUpload: {
            OSSInitMultipartUploadResult * initMultipartUploadResult = [OSSInitMultipartUploadResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:initMultipartUploadResult];
            }
            if (_collectingData) {
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"init multipart upload result: %@", parsedDict);
                if (parsedDict) {
                    initMultipartUploadResult.uploadId = [parsedDict objectForKey:OSSUploadIdXMLTOKEN];
                }
            }
            return initMultipartUploadResult;
        }
            
        case OSSOperationTypeUploadPart: {
            OSSUploadPartResult * uploadPartResult = [OSSUploadPartResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:uploadPartResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Etag"]) {
                        uploadPartResult.eTag = obj;
                        *stop = YES;
                    }
                }];
            }
            return uploadPartResult;
        }
            
        case OSSOperationTypeCompleteMultipartUpload: {
            OSSCompleteMultipartUploadResult * completeMultipartUploadResult = [OSSCompleteMultipartUploadResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:completeMultipartUploadResult];
            }
            if (_collectingData) {
                if ([[[_response.allHeaderFields objectForKey:OSSHttpHeaderContentType] description] isEqual:@"application/xml"]) {
                    OSSLogVerbose(@"complete multipart upload result: %@", [NSDictionary oss_dictionaryWithXMLData:_collectingData]);
                    NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                    if (parsedDict) {
                        completeMultipartUploadResult.location = [parsedDict objectForKey:OSSLocationXMLTOKEN];
                        completeMultipartUploadResult.eTag = [parsedDict objectForKey:OSSETagXMLTOKEN];
                    }
                } else {
                    completeMultipartUploadResult.serverReturnJsonString = [[NSString alloc] initWithData:_collectingData encoding:NSUTF8StringEncoding];
                }
            }
            return completeMultipartUploadResult;
        }
            
        case OSSOperationTypeListMultipart: {
            OSSListPartsResult * listPartsReuslt = [OSSListPartsResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:listPartsReuslt];
            }
            if (_collectingData) {
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"list multipart upload result: %@", parsedDict);
                if (parsedDict) {
                    listPartsReuslt.nextPartNumberMarker = [[parsedDict objectForKey:OSSNextPartNumberMarkerXMLTOKEN] intValue];
                    listPartsReuslt.maxParts = [[parsedDict objectForKey:OSSMaxKeysXMLTOKEN] intValue];
                    listPartsReuslt.isTruncated = [[parsedDict objectForKey:OSSMaxKeysXMLTOKEN] boolValue];
                    
                    id partsObject = [parsedDict objectForKey:OSSPartXMLTOKEN];
                    if ([partsObject isKindOfClass:[NSArray class]]) {
                        listPartsReuslt.parts = partsObject;
                    } else if ([partsObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:partsObject];
                        listPartsReuslt.parts = arr;
                    } else {
                        listPartsReuslt.parts = nil;
                    }
                }
            }
            return listPartsReuslt;
        }
            
        case OSSOperationTypeAbortMultipartUpload: {
            OSSAbortMultipartUploadResult * abortMultipartUploadResult = [OSSAbortMultipartUploadResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:abortMultipartUploadResult];
            }
            return abortMultipartUploadResult;
        }
            
        default: {
            OSSLogError(@"unknown operation type");
            break;
        }
    }
    return nil;
}

@end
