//
//  OSSUtilsTests.swift
//  OSSSwiftDemoTests
//
//  Created by 剑子 on 2019/12/20.
//  Copyright © 2019 aliyun. All rights reserved.
//

import XCTest

import AliyunOSSiOS
import AliyunOSSSwiftSDK


class OSSUtilsTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
     
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

       
    func testBucketName(){
        ///^[a-z0-9][a-z0-9\\-]{1,61}[a-z0-9]$"
        
        let result1 = OSSUtil.validateBucketName("123-456abc")
        XCTAssertTrue(result1)
        
        let result2 = OSSUtil.validateBucketName("123-456abc-")
        XCTAssertFalse(result2)
        
        let result3 = OSSUtil.validateBucketName("-123-456abc")
        XCTAssertFalse(result3)
        
        let str4 = String("123\\456abc")
        let result4 = OSSUtil.validateBucketName(str4)
        XCTAssertFalse(result4)
        
        let result5 = OSSUtil.validateBucketName("abc123")
        XCTAssertTrue(result5)
        
        let result6 = OSSUtil.validateBucketName("abc_123")
        XCTAssertFalse(result6)
        
        let result7 = OSSUtil.validateBucketName("a")
        XCTAssertFalse(result7)
        
        let str8 = String("abcdefghig-abcdefghig-abcdefghig-abcdefghig-abcdefghig-abcdefghig")
        let result8 = OSSUtil.validateBucketName(str8)
        XCTAssertFalse(result8)
             
    }
    
    func testEndpoint(){
        let bucketName = "test-image"
        
        let result1 = getResultEndpoint(endpoint: "http://123.test:8989/path?ooob")
        XCTAssertTrue((result1 == "http://123.test:8989"))
       
        let result2 = getResultEndpoint(endpoint: "http://192.168.0.1:8081")
        XCTAssertTrue((result2 == "http://192.168.0.1:8081/\(bucketName)"))
        
        let result3 = getResultEndpoint(endpoint: "http://192.168.0.1")
        XCTAssertTrue((result3 == "http://192.168.0.1/\(bucketName)"))
        
        let result4 = getResultEndpoint(endpoint: "http://oss-cn-region.aliyuncs.com")
        XCTAssertTrue((result4 == "http://\(bucketName).oss-cn-region.aliyuncs.com"))
    }
    
    func getResultEndpoint(endpoint : String) -> String {
        let bucketName = "test-image"
        let urlComs = URLComponents.init(string: endpoint)
        var temComs = URLComponents.init()
        temComs.scheme = urlComs?.scheme
        temComs.host = urlComs?.host
        temComs.port = urlComs?.port
        
        if (bucketName as NSString).oss_isNotEmpty() {
            let ipAdapter = OSSIPv6Adapter.getInstance()
            if OSSUtil.isOssOriginBucketHost(temComs.host!) {
                temComs.host = bucketName + "." + temComs.host!
                if (temComs.scheme?.lowercased() == "http") {
                    let dnsResult = OSSUtil.getIpByHost(temComs.host!)
                    temComs.host = dnsResult
                }
            }else if(ipAdapter!.isIPv4Address(temComs.host!) || ipAdapter!.isIPv6Address(temComs.host!) ){
                temComs.path = "/\(bucketName)"
            }
        }
        
        return temComs.string!
    }
}
