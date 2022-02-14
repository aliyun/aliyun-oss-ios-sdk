//
//  OSSWrapper.h
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/10/23.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSSWrapper : NSObject


/**
 upload image asynchronously

 @param objectKey object's key
 @param filePath local file's path
 @param success success block
 @param failure failure block
 */
- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath
              success:(void (^_Nullable)(id))success
              failure:(void (^_Nullable)(NSError*))failure;

/**
 cancel normal upload/download request.
 */
- (void)normalRequestCancel;

@end

NS_ASSUME_NONNULL_END
