//
//  OSSCheckCRC64Tests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/12.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSCheckCRC64Tests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    override func setupClient() {
        let configuration = OSSClientConfiguration()
        configuration.crc64Verifiable = OSS_CRC64_ENABLE;
        let sts = OSSTestUtils.getSts()
        let provider = OSSStsTokenCredentialProvider.init(accessKeyId: sts!.tAccessKey, secretKeyId: sts!.tSecretKey, securityToken: sts!.tToken)
        
        client = OSSClient.init(endpoint: OSS_ENDPOINT,
                                credentialProvider: provider,
                                clientConfiguration: configuration)
    }
    
    func testAPI_putObject() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "oracle"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = fileName + "2." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
}
