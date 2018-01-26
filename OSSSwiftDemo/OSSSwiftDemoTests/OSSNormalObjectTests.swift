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
        let fileName = "swift"
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
        
        var task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
        }).waitUntilFinished()
        
        let headReq = OSSHeadObjectRequest()
        headReq.bucketName = OSS_BUCKET_PRIVATE
        headReq.objectKey = objectKey
        task = client.headObject(headReq)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.result)
            let result = t.result as! OSSHeadObjectResult
            let contentType = result.objectMeta[OSS_CONTENT_TYPE] as! String
            XCTAssertEqual(contentType, OSS_TEST_CONTENT_TYPE)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithoutContentType() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = fileName + "1." + fileExtension
        request.objectMeta = ["x-oss-meta-name1": "value1"];
        request.uploadProgress = {(bytesSent, totalByteSent, totalBytesExpectedToSend) ->Void in
            print("bytesSent: \(bytesSent),totalByteSent: \(totalByteSent),totalBytesExpectedToSend: \(totalBytesExpectedToSend)")
        }
        request.contentType = ""
        
        var task = client.putObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
        }).waitUntilFinished()
        
        let headReq = OSSHeadObjectRequest()
        headReq.bucketName = OSS_BUCKET_PRIVATE
        headReq.objectKey = request.objectKey
        task = client.headObject(headReq)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.result)
            let result = t.result as! OSSHeadObjectResult
            XCTAssertNotNil(result.objectMeta[OSS_CONTENT_TYPE])
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_putObjectWithServerCallBack() -> Void {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
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

    func testAPI_putObjectACL() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[1]
        request.isAuthenticationRequired = false
        
        var task = client.getObject(request)
        task.continue({ (t) -> Any? in
            let error: NSError = t.error! as NSError
            XCTAssertNotNil(error)
            XCTAssertEqual(-403, error.code)
            return nil
        }).waitUntilFinished()
        
        let putACLReq = OSSPutObjectACLRequest()
        putACLReq.acl = "public-read-write"
        putACLReq.objectKey = request.objectKey
        putACLReq.bucketName = request.bucketName
        
        task = client.putObjectACL(putACLReq)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error);
            return nil
        }).waitUntilFinished()
        
        let otherReq = OSSGetObjectRequest()
        otherReq.bucketName = OSS_BUCKET_PRIVATE
        otherReq.objectKey = fileNames[1]
        otherReq.isAuthenticationRequired = false
        
        task = client.getObject(otherReq)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObject() -> Void {
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
    
    func testAPI_getObjectACL() -> Void {
        let request = OSSGetObjectACLRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectName = OSS_IMAGE_KEY
        
        let task = client.getObjectACL(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            if (t.result != nil)
            {
                let result = t.result! as! OSSGetObjectACLResult
                XCTAssertEqual(result.grant, "default")
            }
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithImage() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = OSS_IMAGE_KEY
        request.xOssProcess = "image/resize,m_lfit,w_100,h_100"
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithRecieveDataBlock() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = OSS_IMAGE_KEY
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        request.onRecieveData = { (data) -> Void in
            print("onRecieveData: \((data as NSData).length)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithRecieveDataBlockAndNoRetry() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "wrong-key"
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        request.onRecieveData = { (data) -> Void in
            print("onRecieveData: \((data as NSData).length)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectWithRange() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[0]
        request.range = OSSRange(start: 1, withEnd: 100)
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            let result = t.result as! OSSGetObjectResult
            XCTAssertEqual(206, result.httpResponseCode)
            XCTAssertEqual(100, (result.downloadedData as NSData).length);
            let length = (result.objectMeta["Content-Length"] as! NSString).integerValue
            XCTAssertEqual(100, length)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectByPartiallyRecieveData() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[0]
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        var receivedData: Data = Data()
        request.onRecieveData = { (data) -> Void in
            receivedData.append(data)
            print("onRecieveData: \((receivedData as NSData).length)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectFromPublicBucket() -> Void {
        let request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PUBLIC
        request.objectKey = OSS_IMAGE_KEY
        request.isAuthenticationRequired = false;
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        let task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getObjectOverwriteOldFile() -> Void {
        let localFileName = "test_overwrite"
        let localFilePath = (documentDirectory! as NSString).appendingPathComponent(localFileName)
        var request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[0]
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        request.downloadToFileURL = URL.init(fileURLWithPath: localFilePath)
        
        var task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            return nil
        }).waitUntilFinished()
        
        request = OSSGetObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = fileNames[2]
        request.downloadProgress = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            OSSLogVerbose("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        request.downloadToFileURL = URL.init(fileURLWithPath: localFilePath)
        
        task = client.getObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            let result = t.result as! OSSGetObjectResult
            let contentLength = result.objectMeta[OSS_CONTENT_LENGTH]
            let localFileSize = try! FileManager.default.attributesOfItem(atPath: localFilePath)[FileAttributeKey.size]
            XCTAssertEqual(String(describing: contentLength!), String(describing: localFileSize!))
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_headObject() {
        let request = OSSHeadObjectRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = OSS_IMAGE_KEY
        
        let task = client.headObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_deleteObject() {
        let request = OSSPutObjectRequest()
        let fileName = "swift"
        let fileExtension = "pdf"
        request.bucketName = OSS_BUCKET_PRIVATE
        request.uploadingFileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
        request.objectKey = "putanddelete"
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
        
        let otherRequest = OSSDeleteObjectRequest()
        otherRequest.bucketName = OSS_BUCKET_PRIVATE
        otherRequest.objectKey = "putanddelete"
        
        let otherTask = client.deleteObject(otherRequest)
        otherTask.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getService() {
        let request = OSSGetServiceRequest()
        request.prefix = "huaixu"
        let task = client.getService(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_copyObject() {
        let request = OSSCopyObjectRequest()
        request.bucketName = OSS_BUCKET_PUBLIC
        request.objectKey = fileNames[2]
        request.sourceCopyFrom = "/" + OSS_BUCKET_PRIVATE + "/" + fileNames[2]
        let task = client.copyObject(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_doesObjectExistInBucket() {
        let result = try? client.doesObjectExist(inBucket: OSS_BUCKET_PRIVATE, objectKey: OSS_IMAGE_KEY)
        XCTAssertTrue((result != nil) as Bool)
    }
    
    func testAPI_presignConstrainURLWithExpiration() {
        var presignedURL: String? = nil
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = client.presignConstrainURL(withBucketName: OSS_BUCKET_PRIVATE, withObjectKey: fileNames[4], withExpirationInterval: 1)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            presignedURL = t.result as? String
            
            return nil
        }).waitUntilFinished()
        
        DispatchQueue.global().asyncAfter(deadline: .now()+3) {
            let data = NSData.init(contentsOf: URL.init(string: presignedURL!)!)
            XCTAssertNil(data)
            tcs.setResult(nil)
        }
        tcs.task.waitUntilFinished()
    }
    
    func testAPI_presignConstrainURLWithParams() {
        let task = client.presignConstrainURL(withBucketName: OSS_BUCKET_PRIVATE,
                                              withObjectKey: fileNames[4],
                                              withExpirationInterval: 1,
                                              withParameters: ["x-oss-process": "image/resize,w_50"])
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_presignConstrainURL() {
        let task = client.presignPublicURL(withBucketName: OSS_BUCKET_PRIVATE,
                                           withObjectKey: fileNames[1])
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_presignPublicURLWithParams() {
        let task = client.presignPublicURL(withBucketName: OSS_BUCKET_PRIVATE,
                                           withObjectKey: fileNames[1],
                                           withParameters: ["x-oss-process": "image/resize,w_50"])
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
}
