
#import "OSSHTTPDNSMini.h"
#import "OSSHTTPDNSCacheTable.h"

#include <pthread.h>

static int MAX_TABLE_SIZE = 50;

@implementation OSSHTTPDNSCacheTable
{
    NSMutableDictionary *originCacheTable;
    NSMutableArray *hostCacheTable;
    NSMutableArray *hostQueryTable;

    pthread_rwlock_t readWriteLock;
    int cnt;
}

- (id)init
{
    self = [super init];
    if (self) {
        originCacheTable = [[NSMutableDictionary alloc] init];
        hostCacheTable = [[NSMutableArray alloc] init];
        hostQueryTable = [[NSMutableArray alloc] init];
        cnt = 0;
        pthread_rwlock_init(&readWriteLock, NULL);
    }
    return self;
}

+ (OSSHTTPDNSCacheTable *)sharedInstanceManage
{
    static OSSHTTPDNSCacheTable *sharedInstance = Nil;
    @synchronized(self) {
        if (!sharedInstance) {
            sharedInstance = [[OSSHTTPDNSCacheTable alloc] init];
        }
    }
    return sharedInstance;
}

- (void)addOriginsToCache:(NSDictionary *)dictionary
{
    pthread_rwlock_wrlock(&readWriteLock);
    NSMutableArray *array = nil;
    for (NSString *host in dictionary)
    {
        array = dictionary[host];
        if (array)
        {
            [originCacheTable setValue:array forKey:host];
            if ([hostQueryTable containsObject:host])
            {
                [hostQueryTable removeObject:host];
                [hostCacheTable addObject:host];
            }
        }
    }
    pthread_rwlock_unlock(&readWriteLock);
}

- (OSSHTTPDNSOrigin *)getOriginByHost:(NSString *)host
{
    OSSHTTPDNSOrigin *origin = nil;
    NSMutableArray *array = nil;
    pthread_rwlock_rdlock(&readWriteLock);
    array = [originCacheTable objectForKey:host];
    if (array) {
        origin = array[0];
    }
    pthread_rwlock_unlock(&readWriteLock);
    return origin;
}

- (BOOL)containHost:(NSString *)host
{
    if ([hostCacheTable containsObject:host] || [hostQueryTable containsObject:host]) {
        return YES;
    }
    return NO;
}

- (BOOL)addHost:(NSString *)host
{
    BOOL flags = NO;
    pthread_rwlock_wrlock(&readWriteLock);
    if ([self matchAddCondition:host]) {
        flags = YES;
        cnt ++;
        [hostQueryTable addObject:host];
    }
    pthread_rwlock_unlock(&readWriteLock);
    return flags;
}

- (NSMutableArray *)getQueryHosts
{
    pthread_rwlock_wrlock(&readWriteLock);
    NSMutableArray  *array = [[NSMutableArray alloc] init];
    NSString *host=nil;
    for (int i = 0 ; i < [hostQueryTable count]; i ++) {
        host = hostQueryTable[i];
        if (host)
        {
            [array addObject:host];
        }
    }
    pthread_rwlock_unlock(&readWriteLock);
    return array;
}

- (NSMutableArray *)getAllHosts
{
    pthread_rwlock_wrlock(&readWriteLock);
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSString *host=nil;
    for (int i = 0 ; i < [hostCacheTable count]; i ++)
    {
        host = hostCacheTable[i];
        if (host) {
            [array addObject:host];
        }
    }
    for (int i = 0 ; i < [hostQueryTable count]; i ++)
    {
        host = hostQueryTable[i];
        if (host) {
            [array addObject:host];
        }
    }
    pthread_rwlock_unlock(&readWriteLock);
    return array;
}

- (BOOL)matchAddCondition:(NSString *)host
{
    BOOL match = (![self containHost:host] && [OSSHTTPDNSTools isLegalHost:host] && cnt < MAX_TABLE_SIZE);
    return match;
}
@end
