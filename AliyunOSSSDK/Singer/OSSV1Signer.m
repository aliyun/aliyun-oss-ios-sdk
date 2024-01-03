//
//  OSSV1Signer.m
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import "OSSV1Signer.h"
#import "OSSModel.h"
#import "OSSAllRequestNeededMessage.h"
#import "OSSSignUtils.h"
#import "OSSSignerParams.h"
#import "OSSServiceSignature.h"
#import "OSSDefine.h"
#import "NSDate+OSS.h"
#import "NSMutableDictionary+OSS.h"

@implementation OSSV1Signer

- (void)addAuthorizationHeader:(OSSAllRequestNeededMessage *)request
               federationToken:(OSSFederationToken *)federationToken {
    NSString *canonicalString = [self buildStringToSign:request];
    NSString *signature = [[HmacSHA1Signature new] computeSignature:federationToken.tSecretKey
                                                               data:canonicalString];
    request.headerParams[OSSHttpHeaderAuthorization] = [OSSSignUtils composeRequestAuthorization:federationToken.tAccessKey
                                                                                       signature:signature];
}

- (OSSTask *)presign:(OSSAllRequestNeededMessage *)requestMessage {
    id<OSSCredentialProvider> credentialProvider = self.signerParams.credentialProvider;
    OSSFederationToken *federationToken;
    NSError * error = nil;
    if ([credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
        federationToken = [(OSSFederationCredentialProvider *)credentialProvider getToken:&error];
        if (error) {
            return [OSSTask taskWithError:error];
        }
    } else if ([credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
        federationToken = [(OSSStsTokenCredentialProvider *)credentialProvider getToken];
    }
    
    NSString *canonicalResource = self.signerParams.resourcePath;
    NSString * expires = [@((int64_t)[[NSDate oss_clockSkewFixedDate] timeIntervalSince1970] + self.signerParams.expiration) stringValue];
    if (federationToken.useSecurityToken) {
        [requestMessage.headerParams oss_setObject:federationToken.tToken forKey:OSSHttpHeaderSecurityToken];
    }
    requestMessage.headerParams[OSSHttpHeaderDate] = expires;
    
    NSString *canonicalString = [OSSSignUtils buildCanonicalString:requestMessage.httpMethod
                                                      resourcePath:canonicalResource
                                                           request:requestMessage
                                                           expires:expires];
    NSString *signature;
    if ([credentialProvider isKindOfClass:[OSSCustomSignerCredentialProvider class]]) {
        signature = [(OSSCustomSignerCredentialProvider *)credentialProvider sign:canonicalString
                                                                            error:&error];
    } else {
        signature = [[HmacSHA1Signature new] computeSignature:federationToken.tSecretKey
                                                         data:canonicalString];
    }
    if (error) {
        return [OSSTask taskWithError:error];
    }
    
    NSMutableDictionary *params = requestMessage.params.mutableCopy;
    [params oss_setObject:expires forKey:OSSRequestParameterExpires];
    [params oss_setObject:federationToken.tAccessKey forKey:OSSRequestParameterAccessKeyId];
    [params oss_setObject:signature forKey:OSSRequestParameterSignature];
    requestMessage.params = params;

    return [OSSTask taskWithResult:nil];
}

- (NSString *)buildStringToSign:(OSSAllRequestNeededMessage *)request {
    NSString *canonicalString = [OSSSignUtils buildCanonicalString:request.httpMethod
                                                      resourcePath:self.signerParams.resourcePath
                                                           request:request
                                                           expires:nil];
    return canonicalString;
}

@end
