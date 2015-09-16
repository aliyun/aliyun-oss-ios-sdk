
#import <Foundation/Foundation.h>

@interface OSSHTTPDNSOrigin : NSObject

- (id)initWithHost:(NSString *)ip
          liveTime:(long long)ttl;

- (NSString *)getIPString;

- (long long)getTimetoLive;

@end
