//
//  OSSExceptionalTests.swift
//  OSSSwiftDemoTests
//
//  Created by 怀叙 on 2018/1/13.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSExceptionalTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAPI_putObjectWithErrorOfInvalidKey() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = "/file1m"
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(OSSClientErrorCODE.codeInvalidArgument.rawValue, error.code);
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithErrorOfNoSource() -> Void {
        let request = OSSPutObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "noresource"
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(OSSClientErrorCODE.codeInvalidArgument.rawValue, error.code);
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithErrorOfInvalidBucketName() {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = "oss-testcase-unexist-bucket"
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = fileName + "." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(-404, error.code);
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithErrorOfNoCredentialProvier() -> Void {
        let provider = OSSAuthCredentialProvider(authServerUrl: "")
        let wrongClient = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = "oss-testcase-unexist-bucket"
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = fileName + "." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.contentType = "application/pdf"
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = wrongClient.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(OSSClientErrorCODE.codeSignFailed.rawValue, error.code)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithServerErrorNotExistObject() -> Void {
        let localFileName = "test_overwrite"
        let localFilePath = (documentDirectory! as NSString).appendingPathComponent(localFileName)
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "unexist-object"
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        request.downloadToFileURL = URL.init(fileURLWithPath: localFilePath)
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(-404, error.code)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithServerErrorNotExistBucket() -> Void {
        let localFileName = "test_overwrite"
        let localFilePath = (documentDirectory! as NSString).appendingPathComponent(localFileName)
        let request = OSSGetObjectRequest()
        request.bucketName = "unexist-bucket"
        request.objectKey = fileNames[0]
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        request.downloadToFileURL = URL.init(fileURLWithPath: localFilePath)
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(-404, error.code)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithErrorOfAccessDenied() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[0]
        request.isAuthenticationRequired = false
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(-403, error.code)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithErrorOfInvalidParam() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[0]
        request.range = OSSRange(start: -10, withEnd: 0)
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(-416, error.code)
            
            return nil
        }).waitUntilFinished()
    }
    
}
