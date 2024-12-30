//
//  OSSV4Signer.h
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import "OSSSignerBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSSV4Signer : OSSSignerBase

- (NSData *)buildSigningKey:(OSSFederationToken *)federationToken;
- (void)initRequestDateTime;
@end

NS_ASSUME_NONNULL_END
