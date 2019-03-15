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
        let provider = OSSAuthCredentialProvider.init(authServerUrl: OSS_STSTOKEN_URL)
        
        client = OSSClient.init(endpoint: OSS_ENDPOINT,
                                credentialProvider: provider,
                                clientConfiguration: configuration)
    }
    
    func testAPI_putObject() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
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
    
    func testAPI_appendObject() -> Void {
        var request = OSSAppendObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = OSS_APPEND_OBJECT_KEY
        request.uploadingFileURL = Bundle.main.url(forResource: "swift", withExtension: "pdf")!
        
        var result: OSSAppendObjectResult? = nil
        var task = client.appendObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            result = t.result as? OSSAppendObjectResult
            return nil
        }).waitUntilFinished()
        
        request = OSSAppendObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = OSS_APPEND_OBJECT_KEY
        request.appendPosition = (result?.xOssNextAppendPosition)!
        request.uploadingFileURL = Bundle.main.url(forResource: "swift", withExtension: "pdf")!
        
        task = client.appendObject(request, withCrc64ecma: result?.remoteCRC64ecma)
        task.waitUntilFinished()
        XCTAssertNil(task.error)
    }
    
    func testAPI_resumableUpload() {
        
        var result: OSSResumableUploadResult? = nil
        
        let fileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")
        let request = OSSResumableUploadRequest()
        request.uploadingFileURL = fileURL!
        request.partSize = 307200
        request.bucketName = OSS_BUCKET_PUBLIC
        request.objectKey = OSS_RESUMABLE_UPLOADKEY
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = client.resumableUpload(request)
        task.continue({ (t) -> Any? in
            result = t.result as? OSSResumableUploadResult
            print("===remoteCRC64ecma=== \(result?.httpResponseHeaderFields["x-oss-hash-crc64ecma"])")
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
}
