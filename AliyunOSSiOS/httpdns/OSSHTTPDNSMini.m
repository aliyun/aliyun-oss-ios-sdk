
#import "OSSHTTPDNSMini.h"
#import "OSSHTTPDNSCacheTable.h"
#import "OSSHTTPDNSTools.h"
#include <pthread.h>

//线上环境数据
static int alreadyTimeout = 10*60;
//测试环境数据
//static int alreadyTimeout = 3;


@interface OSSHTTPDNSMini()
@property (strong, nonatomic) NSOperationQueue *downloadQueue;
@end

@implementation OSSHTTPDNSMini
{
    OSSHTTPDNSCacheTable *cacheTable;
    OSSHTTPDNSTools *tools;
}

- (id)init
{
    self = [super init];
    if (self) {
        cacheTable = [OSSHTTPDNSCacheTable sharedInstanceManage];
        _downloadQueue = NSOperationQueue.new;
        _downloadQueue.maxConcurrentOperationCount = 1;
        tools = [OSSHTTPDNSTools sharedInstanceManage];
    }
    return self;
}

+ (OSSHTTPDNSMini *)sharedInstanceManage
{
    static OSSHTTPDNSMini *sharedInstance = Nil;
    @synchronized(self) {
        if (!sharedInstance) {
            sharedInstance = [[OSSHTTPDNSMini alloc] init];
        }
    }
    return sharedInstance;
}

- (void)addOperationToQueue:(ArgType)type
{
    NSInvocationOperation *operation =[[NSInvocationOperation alloc] initWithTarget:tools selector:@selector(httpDnsRequest:) object:[[NSNumber alloc] initWithInt:type]];
    [_downloadQueue addOperation:operation];
}

- (BOOL)setHost:(NSString *) host
{
    if ([OSSHTTPDNSTools isLegalHost:host]) {
        return [cacheTable addHost:host];
    }
    return NO;
}

- (void)addHost:(NSString *)host
{
    BOOL set_flag= [self setHost:host];
    if (set_flag) {
        [self addOperationToQueue:ADDSINGLEHOST];
    }
}

- (NSString *)getIpByHostAsync:(NSString *)host
{
    if (![OSSHTTPDNSTools isLegalHost:host]) {
        return nil;
    }
    OSSHTTPDNSOrigin *origin = [cacheTable getOriginByHost:host];
    if (origin == nil) {
        [self addHost:host];
    } else {
        long long now = [OSSHTTPDNSTools currentTimeInSec];
        long long last= [origin getTimetoLive];
        if (now >= last) {
            if ([tools setTimeoutTaskFlags]) {
                [self addOperationToQueue:TTL];
            }
            if ((origin.getTimetoLive + alreadyTimeout) <= [OSSHTTPDNSTools currentTimeInSec]) {
                return nil;
            }
        }
    }
    NSString *ip = [origin getIPString];
    return ip;
}

- (NSString *)getIpByHost:(NSString *)host
{
    if (![OSSHTTPDNSTools isLegalHost:host]) {
        return nil;
    }
    OSSHTTPDNSOrigin *origin = [cacheTable getOriginByHost:host];
    if (origin == nil) {
        BOOL set_flag= [self setHost:host];
        if (set_flag) {
            [tools httpDnsRequest:[[NSNumber alloc] initWithInt:ADDSINGLEHOST]];
        }
        origin = [cacheTable getOriginByHost:host];
    } else {
        long long now = [OSSHTTPDNSTools currentTimeInSec];
        long long last= [origin getTimetoLive];
        if (now >= last)   {
            if ([tools setTimeoutTaskFlags]) {
                [self addOperationToQueue:TTL];
            }
        }
    }
    NSString *ip = [origin getIPString];
    return ip;
}

@end
