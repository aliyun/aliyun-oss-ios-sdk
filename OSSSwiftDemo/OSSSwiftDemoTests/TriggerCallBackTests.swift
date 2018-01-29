//
//  TriggerCallBackTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/29.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class TriggerCallBackTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testForTriggeringCallback() {
        let request = OSSCallBackRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectName = "landscape-painting.jpeg"
        request.callbackVar = ["key1": "value1",
                               "key2": "value2"]
        request.callbackParam = ["callbackUrl": "121.43.113.8",
                                 "callbackBody": "test"]
        
        let task = client.triggerCallBack(request)
        task.continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            
            return nil
        }).waitUntilFinished()
    }
    
}
