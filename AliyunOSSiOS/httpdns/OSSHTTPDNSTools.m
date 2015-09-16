
#import "OSSHTTPDNSTools.h"
#import "OSSHTTPDNSCacheTable.h"
#import <CommonCrypto/CommonDigest.h>
#include <pthread.h>

static NSRegularExpression *hostExpression;
static NSRegularExpression *ipExpression;
static const NSString *httpdnsServerIP = @"140.205.143.143";
static const NSString *schema        = @"http://";
static const NSString *path          = @"/d?host=";

@implementation OSSHTTPDNSTools
{
    BOOL ttlInQueue;
    pthread_rwlock_t lock;
}

+ (void)initialize
{
    hostExpression = [[NSRegularExpression alloc] initWithPattern:@"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$" options:NSRegularExpressionCaseInsensitive error:nil];
    ipExpression = [[NSRegularExpression alloc] initWithPattern:@"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$" options:NSRegularExpressionCaseInsensitive error:nil];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        ttlInQueue = NO;
        pthread_rwlock_init(&lock, NULL);
    }
    return self;
}

+ (OSSHTTPDNSTools *)sharedInstanceManage
{
    static OSSHTTPDNSTools *sharedInstance = Nil;
    @synchronized(self) {
        if (!sharedInstance) {
            sharedInstance = [[OSSHTTPDNSTools alloc] init];
        }
    }
    return sharedInstance;
}
- (void)httpDnsRequest:(NSNumber *)typeNumber
{
    ArgType type = [typeNumber intValue];
    NSMutableArray *hostArray = [self getQueryBody:type];
    for (NSString *hostInArray in hostArray) {
        NSString *URL = [NSString stringWithFormat:@"%@%@", [self getHttpDnsURL], hostInArray];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15];
        NSHTTPURLResponse *response;
        NSError *error = nil;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (error) {
            responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        }
        if (!error) {
            [self getIpFromJson:responseData];
        }
        if (type == TTL) {
            [self resetTimeoutTaskFlags];
        }
    }
}

- (void)getIpFromJson:(NSData *)response
{
    NSError *error=nil;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableLeaves error:&error];
#if OSSHTTPDNS_LOGER == 1
    NSLog(@"[OSSHTTPDNSTools getIpFromJson]--Json from httpdns server is:%@", dic);
#endif
    if (error) {
        return;
    }
    long long now = [OSSHTTPDNSTools currentTimeInSec];
    if (!dic.count) {
        return;
    }
    OSSHTTPDNSCacheTable *cacheTable = [OSSHTTPDNSCacheTable sharedInstanceManage];
    NSMutableDictionary *dicionary = [[NSMutableDictionary alloc] init];
    long long ttl = 0;
    id object = nil;
    NSString *host = dic[@"host"];
    if (!host) {
        return;
    }
    object = dic[@"ttl"];
    if (object) {
        ttl = [object longLongValue] + now;
    }
    NSArray *ips = dic[@"ips"];
    if (ips.count) {
        NSMutableArray *hostArray = [[NSMutableArray alloc] init];
        for (NSString *ip in ips) {
            if (ip == nil || object == nil) {
                continue;
            }
            if (![OSSHTTPDNSTools isLegalIP:ip]) {
                continue;
            }
            OSSHTTPDNSOrigin *origin = [[OSSHTTPDNSOrigin alloc] initWithHost:ip liveTime:ttl];
            [hostArray addObject:origin];
        }
        dicionary[host] = hostArray;
    }
    [cacheTable addOriginsToCache:dicionary];
}

+ (BOOL)isLegalIP:(NSString *)ip
{
    if (!ip.length) {
        return NO;
    }
    NSTextCheckingResult *checkResult = [ipExpression firstMatchInString:ip options:0 range:NSMakeRange(0, [ip length])];
    if (checkResult.range.length == [ip length]) {
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)isLegalHost:(NSString *)host
{
    if (!host.length) {
        return NO;
    }
    NSTextCheckingResult *checkResult = [hostExpression firstMatchInString:host options:0 range:NSMakeRange(0, [host length])];
    if (checkResult.range.length == [host length]) {
        return YES;
    } else {
        return NO;
    }
}

+ (long long)currentTimeInSec
{
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    long long second = (long long)(time);
    return second;
}

- (NSMutableArray *)getQueryBody:(ArgType) type
{
    OSSHTTPDNSCacheTable *cacheTable = [OSSHTTPDNSCacheTable sharedInstanceManage];
    if (type == ADDSINGLEHOST) {
        return [cacheTable getQueryHosts];
    } else if (type == TTL) {
        return [cacheTable getAllHosts];
    }
    return nil;
}

- (BOOL)setTimeoutTaskFlags
{
    BOOL flags = NO;
    pthread_rwlock_wrlock(&lock);
    if (!ttlInQueue) {
        ttlInQueue = YES;
        flags = YES;
    }
    pthread_rwlock_unlock(&lock);
    return flags;
}

- (void)resetTimeoutTaskFlags
{
    pthread_rwlock_wrlock(&lock);
    ttlInQueue = NO;
    pthread_rwlock_unlock(&lock);
}

- (NSString *)getHttpDnsURL
{
    NSString *URL = [NSString stringWithFormat:@"%@%@%@",schema,httpdnsServerIP,path];
    return URL;
}

@end
