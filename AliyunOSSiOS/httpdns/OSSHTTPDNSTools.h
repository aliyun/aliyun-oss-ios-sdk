
#import <Foundation/Foundation.h>

#define OSSHTTPDNS_LOGER 0

typedef enum {
    ADDSINGLEHOST,
    TTL
}ArgType;

@interface OSSHTTPDNSTools : NSObject

+ (OSSHTTPDNSTools *)sharedInstanceManage;

+ (BOOL)isLegalIP:(NSString *)ip;

+ (BOOL)isLegalHost:(NSString *)host;

+ (long long)currentTimeInSec;


- (void)httpDnsRequest:(NSNumber *) typeNumber;

- (BOOL)setTimeoutTaskFlags;

- (NSString *)getHttpDnsURL;

@end
