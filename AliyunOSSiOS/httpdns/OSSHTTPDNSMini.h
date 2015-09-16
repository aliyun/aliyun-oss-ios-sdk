
#import <Foundation/Foundation.h>
#import "OSSHTTPDNSOrigin.h"
#include "OSSHTTPDNSTools.h"

@interface OSSHTTPDNSMini : NSObject

+ (OSSHTTPDNSMini *)sharedInstanceManage;


- (NSString *)getIpByHostAsync:(NSString *)host;

- (NSString *)getIpByHost:(NSString *)host;
@end
