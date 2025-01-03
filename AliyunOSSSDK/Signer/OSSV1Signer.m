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
    NSMutableDictionary *params = requestMessage.params.mutableCopy;
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    } else if ([credentialProvider isKindOfClass:[OSSPlainTextAKSKPairCredentialProvider class]]) {
        federationToken = [[OSSFederationToken alloc] init];
        federationToken.tAccessKey = ((OSSPlainTextAKSKPairCredentialProvider *)credentialProvider).accessKey;
        federationToken.tSecretKey = ((OSSPlainTextAKSKPairCredentialProvider *)credentialProvider).secretKey;
    }
#pragma clang diagnostic pop

    NSString *canonicalResource = self.signerParams.resourcePath;
    NSString * expires = [@((int64_t)[[NSDate oss_clockSkewFixedDate] timeIntervalSince1970] + self.signerParams.expiration) stringValue];
    if (federationToken.useSecurityToken) {
        [params oss_setObject:federationToken.tToken forKey:@"security-token"];
    }
    requestMessage.params = params;
    requestMessage.headerParams[OSSHttpHeaderDate] = expires;
    
    NSString *canonicalString = [OSSSignUtils buildCanonicalString:requestMessage.httpMethod
                                                      resourcePath:canonicalResource
                                                           request:requestMessage
                                                           expires:expires];
    NSString *signature;
    NSString *accessKey = federationToken.tAccessKey;
    if ([credentialProvider isKindOfClass:[OSSCustomSignerCredentialProvider class]]) {
        NSString *wholeSign = [(OSSCustomSignerCredentialProvider *)credentialProvider sign:canonicalString
                                                                                      error:&error];
        NSArray * splitResult = [wholeSign componentsSeparatedByString:@":"];
        if ([splitResult count] != 2
            || ![((NSString *)[splitResult objectAtIndex:0]) hasPrefix:@"OSS "]) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeSignFailed
                                                          userInfo:@{OSSErrorMessageTOKEN: @"the returned signature is invalid"}]];
        }
        accessKey = [(NSString *)[splitResult objectAtIndex:0] substringFromIndex:4];
        signature = [splitResult objectAtIndex:1];
    } else {
        if (federationToken == nil) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeSignFailed
                                                          userInfo:@{OSSErrorMessageTOKEN: @"Can't get a federation token"}]];
        }
        signature = [[HmacSHA1Signature new] computeSignature:federationToken.tSecretKey
                                                         data:canonicalString];
    }
    if (error) {
        return [OSSTask taskWithError:error];
    }
    
    [params oss_setObject:expires forKey:OSSRequestParameterExpires];
    [params oss_setObject:accessKey forKey:OSSRequestParameterAccessKeyId];
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
