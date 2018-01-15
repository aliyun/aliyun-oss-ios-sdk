//
//  OSSBucketTests.swift
//  OSSSwiftDemoTests
//
//  Created by 怀叙 on 2018/1/13.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSBucketTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAPI_createBucket() {
        let request = OSSCreateBucketRequest()
        request.bucketName = "oss-testcase-bucket"
        request.xOssACL = "public-read-write"
        
        let task = client.createBucket(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getBucket() {
        let request = OSSGetBucketRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        
        let task = client.getBucket(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_getBucketACL() {
        let request = OSSGetBucketACLRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        
        let task = client.getBucketACL(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            let result = t.result as! OSSGetBucketACLResult
            XCTAssertEqual("private", result.aclGranted)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_deleteBucket() {
        let request = OSSDeleteBucketRequest()
        request.bucketName = "oss-testcase-bucket"
        
        let task = client.deleteBucket(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
    func testAPI_createBucketWithErrorOfInvalidName() {
        let request = OSSCreateBucketRequest()
        request.bucketName = "oss_testcase_bucket"
        request.xOssACL = "public-read-write"
        
        let task = client.createBucket(request)
        task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error as! NSError
            XCTAssertEqual(error.code, -400)
            
            return nil
        }).waitUntilFinished()
    }
    
}
