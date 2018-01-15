//
//  OSSCnameTests.swift
//  OSSSwiftDemoTests
//
//  Created by 怀叙 on 2018/1/15.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSCnameTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    override func setupClient() {
        let provider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        client = OSSClient.init(endpoint: OSS_CNAME_URL, credentialProvider: provider)
    }
    
    func testAPI_putObjectWithCname() {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PUBLIC
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = fileName + "." + fileExtension
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
    
    func testAPI_getObjectWithCname() {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[0]
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_customExcludeCname() {
        let conf = OSSClientConfiguration.init()
        conf.cnameExcludeList = ["osstest.xxyycc.com", "vpc.sample.com"]
        let provider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        client = OSSClient.init(endpoint: OSS_CNAME_URL,
                                credentialProvider: provider,
                                clientConfiguration: conf)
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[0]
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
}


