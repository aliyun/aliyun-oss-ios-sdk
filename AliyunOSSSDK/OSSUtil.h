//
//  OSSUtil.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSFileLogger.h"

#import "NSMutableDictionary+OSS.h"
#import "NSMutableData+OSS_CRC.h"
#import "NSDate+OSS.h"

@class OSSFederationToken;

@interface OSSUtil : NSObject

+ (BOOL)isIncludeCnameExcludeList:(NSArray *)cnameExcludeList host:(NSString *)host;
+ (NSString *)calBase64Sha1WithData:(NSString *)data withSecret:(NSString *)key;
+ (NSString *)calBase64WithData:(uint8_t *)data;
+ (NSString *)encodeURL:(NSString *)url;
+ (NSData *)constructHttpBodyFromPartInfos:(NSArray *)partInfos;
+ (NSData *)constructHttpBodyForDeleteMultipleObjects:(NSArray<NSString *> *)keys quiet:(BOOL)quiet;
+ (NSData *)constructHttpBodyForCreateBucketWithLocation:(NSString *)location __attribute__((deprecated("deprecated!")));
+ (BOOL)validateBucketName:(NSString *)bucketName;
+ (BOOL)validateObjectKey:(NSString *)objectKey;
+ (BOOL)isOssOriginBucketHost:(NSString *)host;
+ (NSString *)getIpByHost:(NSString *)host;
+ (BOOL)isNetworkDelegateState;

+ (NSData *)fileMD5:(NSString *)path;
+ (NSString *)dataMD5String:(NSData *)data;
+ (NSString *)fileMD5String:(NSString *)path;
+ (NSString *)base64Md5ForData:(NSData *)data;
+ (NSString *)base64Md5ForFilePath:(NSString *)filePath;
+ (NSString *)base64Md5ForFileURL:(NSURL *)fileURL;
+ (NSString *)base64ForData:(uint8_t *)input length:(int32_t)length;
+ (NSString *)dataMD5String:(NSData *)data error:(NSError **)error;
+ (NSString *)fileMD5String:(NSString *)path error:(NSError **)error;

+ (NSString *)populateSubresourceStringFromParameter:(NSDictionary *)parameters;
+ (NSString *)populateQueryStringFromParameter:(NSDictionary *)parameters;
+ (BOOL)isSubresource:(NSString *)param;
+ (NSString *)sign:(NSString *)content withToken:(OSSFederationToken *)token;
+ (NSString *)getRelativePath:(NSString *)fullPath;
+ (NSString *)detemineMimeTypeForFilePath:(NSString *)filePath uploadName:(NSString *)uploadName;
+ (BOOL)hasPhoneFreeSpace;

+ (uint64_t)crc64ecma:(uint64_t)crc1 buffer:(void *)buffer length:(size_t)len;

/**
 * @brief: combine crc1 and crc2
 */

+ (uint64_t)crc64ForCombineCRC1:(uint64_t)crc1 CRC2:(uint64_t)crc2 length:(size_t)len2;

+ (NSString *)sha1WithString:(NSString *)string;
+ (NSString *)sha1WithData:(NSData *)data;
+ (NSString *)sha1WithFilePath:(NSString *)filePath;

+ (NSData *)constructHttpBodyForTriggerCallback:(NSString *)callbackParams callbackVaribles:(NSString *)callbackVaribles;

+ (NSData *)constructHttpBodyForImagePersist:(NSString *)action toBucket:(NSString *)toBucket toObjectKey:(NSString *)toObjectKey;

@end

@interface NSString (OSS)

- (NSString *)oss_trim;
- (BOOL)oss_isNotEmpty;
- (NSString *)oss_stringByAppendingPathComponentForURL:(NSString *)path;
+ (NSString *)oss_documentDirectory;
- (NSString *)oss_urlEncodedString;

@end
