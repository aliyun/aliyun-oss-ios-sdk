//
//  SequentialMultipartUploadTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/18.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class SequentialMultipartUploadTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    override func setupClient() {
        let provider = OSSPlainTextAKSKPairCredentialProvider.init(plainTextAccessKey: OSS_ACCESSKEY_ID, secretKey: OSS_SECRETKEY_ID)
        client = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider)
    }
    
    func testAPI_testAPI_sequentialMultipartUpload_crcClosed() {
        let request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = false
        request.crcFlag = OSSRequestCRCFlag.open
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        let task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil;
        }).waitUntilFinished()
    }
    
    func testAPI_sequentialMultipartUpload_crcOpen() {
        let request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = false
        request.crcFlag = OSSRequestCRCFlag.closed
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        let task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error);
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_sequentialMultipartUpload_cancel_withoutDeleteRecord() {
        let request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = false
        request.crcFlag = OSSRequestCRCFlag.open
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {[weak request](bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesSent > totalBytesExpectedToSend / 2 {
                request?.cancel()
            }
        }
        
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        let task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(error.code, OSSClientErrorCODE.codeTaskCancelled.rawValue)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_sequentialMultipartUpload_cancel_deleteRecord() {
        let request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = true
        request.crcFlag = OSSRequestCRCFlag.open
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {[weak request](bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesSent > totalBytesExpectedToSend / 2 {
                request?.cancel()
            }
        }
        
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        let task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error);
            let error = t.error! as NSError
            XCTAssertEqual(error.code, OSSClientErrorCODE.codeTaskCancelled.rawValue)
            
            return nil;
        }).waitUntilFinished()
    }
    
    func testAPI_sequentialMultipartUpload_cancel_and_resume_crcClosed() {
        var request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = false
        request.crcFlag = OSSRequestCRCFlag.closed
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {[weak request](bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesSent > totalBytesExpectedToSend / 2 {
                request?.cancel()
            }
        }
        
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        var task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(error.code, OSSClientErrorCODE.codeTaskCancelled.rawValue)
            
            return nil;
        }).waitUntilFinished()
        
        request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = true
        request.crcFlag = OSSRequestCRCFlag.closed
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            print("bytesSent: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_sequentialMultipartUpload_cancel_and_resume_crcOpened() {
        var request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = false
        request.crcFlag = OSSRequestCRCFlag.open
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {[weak request](bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesSent > totalBytesExpectedToSend / 2 {
                request?.cancel()
            }
        }
        
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        var task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(error.code, OSSClientErrorCODE.codeTaskCancelled.rawValue)
            
            return nil;
        }).waitUntilFinished()
        
        request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = true
        request.crcFlag = OSSRequestCRCFlag.open
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            print("bytesSent: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_sequentialMultipartUpload_cancel_and_resume_lastCrcOpened() {
        var request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = false
        request.crcFlag = OSSRequestCRCFlag.closed
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {[weak request](bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            if totalBytesSent > totalBytesExpectedToSend / 2 {
                request?.cancel()
            }
        }
        
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        var task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(error.code, OSSClientErrorCODE.codeTaskCancelled.rawValue)
            
            return nil;
        }).waitUntilFinished()
        
        request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = true
        request.crcFlag = OSSRequestCRCFlag.open
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        request.recordDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        request.uploadProgress = {(bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            print("bytesSent: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        task = client.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
}
