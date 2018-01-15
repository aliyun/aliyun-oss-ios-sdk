//
//  OSSCheckMd5Tests.swift
//  OSSSwiftDemoTests
//
//  Created by 怀叙 on 2018/1/12.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSCheckMd5Tests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAPI_putObjectWithCheckingDataMd5() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        let fileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        request.uploadingData = try! NSData.init(contentsOf: fileURL!) as Data
        request.objectKey = fileName + "." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        request.contentMd5 = OSSUtil.base64Md5(for: request.uploadingData)
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithCheckingFileMd5() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        let fileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        request.uploadingFileURL = fileURL!
        request.objectKey = fileName + "." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        request.contentMd5 = OSSUtil.base64Md5(forFileURL: fileURL)
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithInvalidMd5() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        let fileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        request.uploadingFileURL = fileURL!
        request.objectKey = fileName + "." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        request.contentMd5 = "invliadmd5valuetotest"
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
}
