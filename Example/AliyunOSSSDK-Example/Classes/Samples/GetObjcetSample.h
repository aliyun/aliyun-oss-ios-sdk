//
//  GetObjcetSample.h
//  AliyunOSSiOS
//

#import <Foundation/Foundation.h>
@class OSSClient;
@class OSSTask;
@class OSSGetObjectRequest;
@class OSSGetObjectResult;

@interface GetObjcetSample : NSObject

- (void)getObject:(void(^)(NSData *)) block;
- (instancetype)initWithOSSClient:(OSSClient*) client;

@end
