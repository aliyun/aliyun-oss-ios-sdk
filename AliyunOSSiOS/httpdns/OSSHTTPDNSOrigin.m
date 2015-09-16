
#import "OSSHTTPDNSOrigin.h"

@interface OSSHTTPDNSOrigin ()
@property (nonatomic, strong) NSString *ip;
@property (nonatomic) long ttl;
@end

@implementation OSSHTTPDNSOrigin

- (id)initWithHost:(NSString *)ip
          liveTime:(long long)ttl
{
    self = [super init];
    if(self){
        _ip = ip;
        _ttl = (long)ttl;
    }
    return self;
}

- (NSString *) getIPString
{
    return _ip;
}

- (long long)getTimetoLive
{
    return _ttl;
}

@end
