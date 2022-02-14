//
//  OSSNormalObjectTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/11.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSNormalObjectTests: OSSSwiftDemoTests {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAPI_putObjectFromNSData() -> Void {
        for fileName in fileNames {
            let request = OSSPutObjectRequest()
            request.bucketName = OSS_BUCKET_PRIVATE
            request.objectKey = fileName
            request.objectMeta = ["x-oss-meta-name1": "value1"];
            request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
                print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
            }
            let filePath = (documentDirectory! as NSString).appendingPathComponent(fileName)
            request.uploadingData = try! NSData.init(contentsOfFile: filePath) as Data
            
            let task = client.putObject(request)
            task.continue({ (t) -> Any? in
                XCTAssertNil(t.error)
                return nil
            }).waitUntilFinished()
        }
    }
    
    func testAPI_putObjectFromFile() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "oracle"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
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
    
    func testAPI_putObjectWithContentType() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = fileNames[0]
        let filePath = (documentDirectory! as NSString).appendingPathComponent(fileName)
        request.bucketName = OSS_BUCKET_PRIVATE
        request.uploadingData = try! NSData.init(contentsOfFile: filePath) as Data
        let objectKey = fileName
        request.objectKey = objectKey
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = OSS_TEST_CONTENT_TYPE
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
        }).waitUntilFinished()
        
//        let headReq = OSSHeadObjectRequest()
//        headReq.bucketName = OSS_BUCKET_PRIVATE
//        headReq.objectKey = objectKey
//        task = client.headObject(headReq)
//        task.continue({ (t) -> Any? in
//            XCTAssertNotNil(t.result)
//            let result = t.result as! OSSHeadObjectResult
//            let contentType = result.objectMeta[OSS_CONTENT_TYPE] as! String
//            XCTAssertEqual(contentType, OSS_TEST_CONTENT_TYPE)
//            return nil
//        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithoutContentType() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "oracle"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = fileName + "1." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        request.contentType = ""
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
        }).waitUntilFinished()
        
//        let headReq = OSSHeadObjectRequest()
//        headReq.bucketName = OSS_BUCKET_PRIVATE
//        headReq.objectKey = request.objectKey
//        task = client.headObject(headReq)
//        task.continue({ (t) -> Any? in
//            XCTAssertNotNil(t.result)
//            let result = t.result as! OSSHeadObjectResult
//            XCTAssertNotNil(result.objectMeta[OSS_CONTENT_TYPE])
//            return nil
//        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithServerCallBack() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "oracle"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = fileName + "." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        request.callbackVar = ["key1": "value1",
                               "key2": "value2"]
        request.callbackParam = ["callbackUrl": OSS_CALLBACK_URL,
                                 "callbackBody": "test"]
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
}
