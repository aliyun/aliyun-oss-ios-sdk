//
//  OSSSignerBase.m
//  AliyunOSSSDK iOS
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import "OSSSignerBase.h"
#import "NSDate+OSS.h"
#import "OSSDefine.h"
#import "OSSV1Signer.h"
#import "OSSV4Signer.h"
#import "OSSLog.h"
#import "OSSAllRequestNeededMessage.h"
#import "OSSSignerParams.h"
#import "OSSConstants.h"
#import "NSMutableDictionary+OSS.h"

@interface OSSSignerBase()

@end

@implementation OSSSignerBase

- (instancetype)initWithSignerParams:(OSSSignerParams *)signerParams {
    self = [super init];
    if (self) {
        self.signerParams = signerParams;
    }
    return self;
}

- (void)addDateHeaderIfNeeded:(OSSAllRequestNeededMessage *)request {
    NSDate *date = [NSDate oss_clockSkewFixedDate];
    request.date = [date oss_asStringValue];
    request.headerParams[OSSHttpHeaderDate] = [date oss_asStringValue];
}

- (void)addSecurityTokenHeaderIfNeeded:(OSSAllRequestNeededMessage *)request
                       federationToken:(OSSFederationToken *)federationToken {
    if ([federationToken useSecurityToken] && !request.isUseUrlSignature) {
        request.headerParams[OSSHttpHeaderSecurityToken] = federationToken.tToken;
    }
}

- (void)addAuthorizationHeader:(OSSAllRequestNeededMessage *)request
               federationToken:(OSSFederationToken *)federationToken {
}

- (NSString *)buildStringToSign:(OSSAllRequestNeededMessage *)request {
    return nil;
}

- (OSSTask *)sign:(OSSAllRequestNeededMessage *)requestMessage {
    id<OSSCredentialProvider> credentialProvider = self.signerParams.credentialProvider;
    OSSFederationToken *federationToken;
    NSError *error;
    if ([credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
        federationToken = [(OSSFederationCredentialProvider *)credentialProvider getToken:&error];
    } else if ([credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
        federationToken = [((OSSStsTokenCredentialProvider *)credentialProvider) getToken];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    } else if ([credentialProvider isKindOfClass:[OSSPlainTextAKSKPairCredentialProvider class]]) {
        federationToken = [[OSSFederationToken alloc] init];
        federationToken.tAccessKey = ((OSSPlainTextAKSKPairCredentialProvider *)credentialProvider).accessKey;
        federationToken.tSecretKey = ((OSSPlainTextAKSKPairCredentialProvider *)credentialProvider).secretKey;
    }
#pragma clang diagnostic pop
    if (error) {
        [OSSTask taskWithError:error];
    }
    
    [self addDateHeaderIfNeeded:requestMessage];
    if ([credentialProvider isKindOfClass:[OSSCustomSignerCredentialProvider class]]) {
        OSSCustomSignerCredentialProvider *customSignerCredentialProvider = (OSSCustomSignerCredentialProvider *)credentialProvider;
        NSString *stringToSign = [self buildStringToSign:requestMessage];
        NSString *authorization = [customSignerCredentialProvider sign:stringToSign
                                                                 error:&error];
        [requestMessage.headerParams oss_setObject:authorization forKey:OSSHttpHeaderAuthorization];
    } else {
        if (federationToken == nil) {
            OSSLogError(@"Can't get a federation token");
            [OSSTask taskWithResult:[NSError errorWithDomain:OSSClientErrorDomain
                                                        code:OSSClientErrorCodeSignFailed
                                                    userInfo:@{OSSErrorMessageTOKEN: @"Can't get a federation token"}]];
        }
        [self addSecurityTokenHeaderIfNeeded:requestMessage federationToken:federationToken];
        [self addAuthorizationHeader:requestMessage federationToken:federationToken];
    }
    if (error) {
        [OSSTask taskWithError:error];
    }
    
    return [OSSTask taskWithResult:nil];
}

- (OSSTask *)presign:(OSSAllRequestNeededMessage *)requestMessage {
    return [OSSTask taskWithResult:nil];
}

+ (id<OSSRequestSigner>)createRequestSignerWithSignerVersion:(OSSSignVersion)signerVersion
                                                signerParams:(OSSSignerParams *)signerParams {
    if (signerVersion == OSSSignVersionV4) {
        return [[OSSV4Signer alloc] initWithSignerParams:signerParams];
    } else {
        return [[OSSV1Signer alloc] initWithSignerParams:signerParams];
    }
}

+ (id<OSSRequestPresigner>)createRequestPresignerWithSignerVersion:(OSSSignVersion)signerVersion
                                                      signerParams:(OSSSignerParams *)signerParams {
    if (signerVersion == OSSSignVersionV4) {
        return [[OSSV4Signer alloc] initWithSignerParams:signerParams];
    } else {
        return [[OSSV1Signer alloc] initWithSignerParams:signerParams];
    }
}

@end
