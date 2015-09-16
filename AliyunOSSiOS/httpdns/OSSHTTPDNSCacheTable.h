
#import <Foundation/Foundation.h>
#import "OSSHTTPDNSOrigin.h"
#import "OSSHTTPDNSTools.h"

@interface OSSHTTPDNSCacheTable : NSObject

+ (OSSHTTPDNSCacheTable* )sharedInstanceManage;


- (void)addOriginsToCache:(NSDictionary *)dictionary;

- (OSSHTTPDNSOrigin *)getOriginByHost:(NSString *)host;

- (BOOL)addHost:(NSString *)host;

- (NSMutableArray *)getQueryHosts;

- (NSMutableArray *)getAllHosts;

@end
