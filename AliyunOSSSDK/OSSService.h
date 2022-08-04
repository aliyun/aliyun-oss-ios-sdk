//
//  OSSService.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/20/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#define OSS_IOS_SDK_VERSION OSSSDKVersion

#import "OSSDefine.h"
#import "OSSConstants.h"

#import "OSSNetworking.h"
#import "OSSNetworkingRequestDelegate.h"
#import "OSSAllRequestNeededMessage.h"
#import "OSSURLRequestRetryHandler.h"
#import "OSSHttpResponseParser.h"
#import "OSSRequest.h"
#import "OSSGetObjectACLRequest.h"
#import "OSSGetObjectACLResult.h"
#import "OSSDeleteMultipleObjectsRequest.h"
#import "OSSDeleteMultipleObjectsResult.h"
#import "OSSGetBucketInfoRequest.h"
#import "OSSGetBucketInfoResult.h"
#import "OSSPutSymlinkRequest.h"
#import "OSSPutSymlinkResult.h"
#import "OSSGetSymlinkRequest.h"
#import "OSSGetSymlinkResult.h"
#import "OSSRestoreObjectRequest.h"
#import "OSSRestoreObjectResult.h"
#import "OSSGetObjectTaggingRequest.h"
#import "OSSGetObjectTaggingResult.h"
#import "OSSPutObjectTaggingRequest.h"
#import "OSSPutObjectTaggingResult.h"
#import "OSSDeleteObjectTaggingRequest.h"
#import "OSSDeleteObjectTaggingResult.h"

#import "OSSClient.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"

#import "OSSBolts.h"
