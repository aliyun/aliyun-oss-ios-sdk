//
//  StstokenSample.h
//  AliyunOSSiOS
//

#import <Foundation/Foundation.h>

@interface StstokenSample : NSObject

- (void)getStsToken:(void(^)(NSDictionary *)) block;

@end
