//
//  OSSTestUtils.swift
//  OSSSwiftDemoTests
//
//  Created by ws on 2022/2/14.
//  Copyright © 2022 aliyun. All rights reserved.
//

import UIKit
import AliyunOSSiOS

class OSSTestUtils: NSObject {
    public static func getSts() -> OSSFederationToken? {
        let url = URL(string: OSS_STSTOKEN_URL)
        let request = URLRequest(url: url!)
        let tcs = OSSTaskCompletionSource<NSData>()
        let session = URLSession.shared
        let sessionTask = session.dataTask(with: request,
                                           completionHandler: { (data, response, error) in
                                            if let _error = error {
                                                tcs.setError(_error)
                                                return;
                                            }
                                            tcs.setResult(data as NSData?);
                                           })
        sessionTask.resume();
        tcs.task.waitUntilFinished();
        if let _ = tcs.task.error {
            return nil;
        } else {
            guard let data = tcs.task.result as Data?,
                  let object = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as? Dictionary<String, Any> else {
                return nil
            }
            
            let statusCode = object?["StatusCode"] as! Int
            if statusCode == 200 {
                let token = OSSFederationToken();
                token.tAccessKey = object?["AccessKeyId"] as! String
                token.tSecretKey = object?["AccessKeySecret"] as! String
                token.tToken = object?["SecurityToken"] as! String
                token.expirationTimeInGMTFormat = object?["Expiration"] as? String
                return token
            } else {
                return nil
            }
        }

    }
    
//    public static func headObject() {
//        let requestDelegate = OSSNetworkingRequestDelegate();

//        let responseParser = OSSTestHttpResponseParser [[ alloc] initForOperationType:2];
        
//        requestDelegate.responseParser = responseParser;
//        OSSAllRequestNeededMessage *allNeededMessage = [[OSSAllRequestNeededMessage alloc] init];
//        allNeededMessage.endpoint = client.endpoint;
//        allNeededMessage.httpMethod = @"HEAD";
//        allNeededMessage.bucketName = bucket;
//        allNeededMessage.objectKey = key;
//        allNeededMessage.date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
//
//        requestDelegate.allNeededMessage = allNeededMessage;
//        requestDelegate.operType = 2;
//
//        return [client invokeRequest:requestDelegate requireAuthentication:YES];
//    }
}
