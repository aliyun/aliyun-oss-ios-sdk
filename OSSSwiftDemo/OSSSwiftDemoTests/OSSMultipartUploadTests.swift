//
//  OSSMultipartUploadTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/13.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSMultipartUploadTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAPI_multipartUpload() {
        let fileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")
        let request = OSSMultipartUploadRequest()
        request.uploadingFileURL = fileURL!
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "wangwangForSwift.zip"
        request.partSize = 412000
        request.uploadProgress = { (bytesSend, totoalBytesSend, totalBytesExpectedToSend) -> Void in
            OSSLogVerbose("bytesSend: \(bytesSend), totoalBytesSend: \(totoalBytesSend), totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let task = client.multipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
        
    }
    
    func testAPI_abortMultipartUpload() {
        let request = OSSInitMultipartUploadRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = OSS_MULTIPART_UPLOADKEY
        request.contentType = "application/octet-stream"
        request.objectMeta = ["x-oss-meta-name1": "value1"]
        
        let task = client.multipartUploadInit(request)
        var uploadId: String? = nil
        
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            let result = t.result as! OSSInitMultipartUploadResult
            uploadId = result.uploadId
            
            return nil
        }).waitUntilFinished()
        
        let otherRequest = OSSAbortMultipartUploadRequest()
        otherRequest.bucketName = OSS_BUCKET_PRIVATE
        otherRequest.objectKey = OSS_MULTIPART_UPLOADKEY
        otherRequest.uploadId = uploadId!
        
        let otherTask = client.abortMultipartUpload(otherRequest)
        otherTask.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            let result = t.result as! OSSAbortMultipartUploadResult
            
            XCTAssertEqual(204, result.httpResponseCode)
            return nil
        }).waitUntilFinished()
        
    }
    
    func testAPI_cancelMultipartUpload() {
        let fileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")
        let request = OSSMultipartUploadRequest()
        request.uploadingFileURL = fileURL!
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "wangwangForSwift.zip"
        request.partSize = 512000
        request.uploadProgress = { (bytesSend, totoalBytesSend, totalBytesExpectedToSend) -> Void in
            OSSLogVerbose("bytesSend: \(bytesSend), totoalBytesSend: \(totoalBytesSend), totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = client.multipartUpload(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(OSSClientErrorCODE.codeTaskCancelled.rawValue, error.code)
            tcs.setError(error)
            
            return nil
        })
        
        // 3秒后取消上传请求
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            request.cancel()
        }
        
        tcs.task.waitUntilFinished()
    }
    
}
