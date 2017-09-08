//
//  GetObjcetSample.m
//  AliyunOSSiOS
//

#import "GetObjcetSample.h"
#import "OSSClient.h"
#import "OSSModel.h"
#import "OSSTask.h"

OSSClient* _client;

@implementation GetObjcetSample

- (instancetype)initWithOSSClient:(OSSClient *)client{
    if(self = [self init]){
        _client = client;
    }
    return self;
}

- (void)getObject:(void (^)(NSData *))block{
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = BUCKET_NAME;
    request.objectKey = DOWNLOAD_OBJECT_KEY;
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        OSSGetObjectResult * result = task.result;
        NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
              result.requestId,
              result.httpResponseHeaderFields,
              (unsigned long)[result.downloadedData length]);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData *data;
            if(result != nil){
                data = result.downloadedData;
            }
            block(data);
        });

        return nil;
    }] waitUntilFinished];
}

@end
