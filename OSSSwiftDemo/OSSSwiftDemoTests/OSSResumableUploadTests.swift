//
//  OSSResumableUploadTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/13.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSResumableUploadTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAPI_resumableUpload() {
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
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_abortResumableUpload() {
        let fileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")
        let request = OSSResumableUploadRequest()
        request.uploadingFileURL = fileURL!
        request.partSize = 307200
        request.bucketName = OSS_BUCKET_PUBLIC
        request.objectKey = OSS_RESUMABLE_UPLOADKEY
        request.deleteUploadIdOnCancelling = true
        request.uploadProgress = {[weak request](bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
            if totalByteSent > totalBytesExpectedToSend / 2 {
                request?.cancel()
            }
        }
        
        let task = client.resumableUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
}
