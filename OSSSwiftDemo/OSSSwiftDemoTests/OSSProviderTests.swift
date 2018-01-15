//
//  OSSProviderTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/13.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSProviderTests: XCTestCase {
    
    var token: OSSFederationToken! = OSSFederationToken()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        setupFederationToken()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func setupFederationToken() {
        let stsURL = URL.init(string: OSS_STSTOKEN_URL)
        let request = URLRequest.init(url: stsURL!)
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            XCTAssertNil(error)
            tcs.setResult(data as AnyObject)
        }
        task.resume()
        tcs.task.waitUntilFinished()
        
        let result = try? JSONSerialization.jsonObject(with: tcs.task.result as! Data,
                                                       options: .allowFragments) as! [String: Any]
        token.tAccessKey = result!["AccessKeyId"] as! String
        token.tSecretKey = result!["AccessKeySecret"] as! String
        token.tToken = result!["SecurityToken"] as! String
        token.expirationTimeInGMTFormat = result?["Expiration"] as? String
    }
    
    func headObject(client: OSSClient) -> OSSTask<AnyObject> {
        let request = OSSHeadObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = OSS_IMAGE_KEY
        
        let task = client.headObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
        return task
    }
    
    func testForFederationCredentialProvider() {
        let provider = OSSFederationCredentialProvider.init { () -> OSSFederationToken? in
            return self.token
        }
        
        let tClient = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = headObject(client: tClient)
        task.waitUntilFinished()
        XCTAssertNil(task.error)
    }
    
    func testGetStsTokenCredentialProvider() {
        let provider = OSSStsTokenCredentialProvider(accessKeyId: token.tAccessKey,
                                                     secretKeyId: token.tSecretKey,
                                                     securityToken: token.tToken)
        let tClient = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = headObject(client: tClient)
        task.waitUntilFinished()
        XCTAssertNil(task.error)
    }
    
    func testCustomSignerCredentialProvider() {
        let provider = OSSCustomSignerCredentialProvider.init { (content, error) -> String? in
            
            let tToken = OSSFederationToken()
            tToken.tAccessKey = OSS_ACCESSKEY_ID
            tToken.tSecretKey = OSS_SECRETKEY_ID
            
            return OSSUtil.sign(content, with: tToken)
        }
        let tClient = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider!)
        let task = headObject(client: tClient)
        task.waitUntilFinished()
        XCTAssertNil(task.error)
    }
    
    func testPlainTextAKSKPairCredentialProvider() {
        let provider = OSSPlainTextAKSKPairCredentialProvider.init(plainTextAccessKey: OSS_ACCESSKEY_ID, secretKey: OSS_SECRETKEY_ID)
        let tClient = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = headObject(client: tClient)
        task.waitUntilFinished()
        XCTAssertNil(task.error)
    }
    
    func testAuthCredentialProvider() {
        let provider = OSSAuthCredentialProvider.init(authServerUrl: OSS_STSTOKEN_URL)
        let tClient = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = headObject(client: tClient)
        task.waitUntilFinished()
        XCTAssertNil(task.error)
    }
    
    func testAuthCredentialProviderWithDecoder() {
        let provider = OSSAuthCredentialProvider.init(authServerUrl: OSS_STSTOKEN_URL) { (data) -> Data? in
            let str = String.init(data: data, encoding: .utf8)
            let decodedData = str?.data(using: .utf8)
            if decodedData != nil {
                return decodedData
            }
            return data
        }
        let tClient = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = headObject(client: tClient)
        task.waitUntilFinished()
        XCTAssertNil(task.error)
    }
    
}
