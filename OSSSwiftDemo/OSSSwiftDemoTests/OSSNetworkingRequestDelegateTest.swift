//
//  OSSNetworkingRequestDelegateTest.swift
//  OSSSwiftDemoTests
//
//  Created by ws on 2021/3/29.
//  Copyright © 2021 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS

class OSSNetworkingRequestDelegateTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
    }

    func testBuildUrlWithCname() {
        let message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(CNAME_ENDPOINT)"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        message.isHostInCnameExcludeList = false
        
        let delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.buildInternalHttpRequest()
        let url = delete.internalRequest.url?.absoluteString
        let canonicalUrl = "\(SCHEME)\(CNAME_ENDPOINT)/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
    }
    
    func testBuildUrlWithoutCname() {
        let message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(CNAME_ENDPOINT)"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        message.isHostInCnameExcludeList = true
        
        let delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.buildInternalHttpRequest()
        let url = delete.internalRequest.url?.absoluteString
        let canonicalUrl = "\(SCHEME)\(BUCKET_NAME).\(CNAME_ENDPOINT)/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
    }
    
    func testBuildUrlWithCnameAndPathStyleAccessEnable() {
        let message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(CNAME_ENDPOINT)"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        message.isHostInCnameExcludeList = true
        
        let delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.isPathStyleAccessEnable = true
        delete.buildInternalHttpRequest()
        let url = delete.internalRequest.url?.absoluteString
        let canonicalUrl = "\(SCHEME)\(CNAME_ENDPOINT)/\(BUCKET_NAME)/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
    }
    
    func testBuildUrlWithPathStyleAccessEnable() {
        var message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(ENDPOINT)"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        
        var delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.isPathStyleAccessEnable = true
        delete.buildInternalHttpRequest()
        var url = delete.internalRequest.url?.absoluteString
        var canonicalUrl = "\(SCHEME)\(BUCKET_NAME).\(ENDPOINT)/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
        
        message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(CNAME_ENDPOINT)"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        
        delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.isPathStyleAccessEnable = true
        delete.buildInternalHttpRequest()
        url = delete.internalRequest.url?.absoluteString
        canonicalUrl = "\(SCHEME)\(CNAME_ENDPOINT)/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
    }
    
    func testBuildUrlWithCustomPathPrefixEnable() {
        let message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(CNAME_ENDPOINT)/path"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        
        let delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.isCustomPathPrefixEnable = true
        delete.buildInternalHttpRequest()
        let url = delete.internalRequest.url?.absoluteString
        let canonicalUrl = "\(SCHEME)\(CNAME_ENDPOINT)/path/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
    }
    
    func testBuildUrlWithCustomPathPrefixEnableAndPathStyleAccessEnable() {
        let message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(CNAME_ENDPOINT)/path"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        message.isHostInCnameExcludeList = true
        
        let delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.isCustomPathPrefixEnable = true
        delete.isPathStyleAccessEnable = true
        delete.buildInternalHttpRequest()
        let url = delete.internalRequest.url?.absoluteString
        let canonicalUrl = "\(SCHEME)\(CNAME_ENDPOINT)/path/\(BUCKET_NAME)/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
    }
    
    func testBuildUrlWithIp() {
        let message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(IP_ENDPOINT)"
        message.bucketName = BUCKET_NAME
        message.objectKey = OBJECT_KEY
        
        let delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.buildInternalHttpRequest()
        let url = delete.internalRequest.url?.absoluteString
        let canonicalUrl = "\(SCHEME)\(IP_ENDPOINT)/\(BUCKET_NAME)/\(OBJECT_KEY)"
        XCTAssertTrue(url == canonicalUrl)
    }
    
    func testBuildUrlWithNullObjectKey() {
        let message = OSSAllRequestNeededMessage()
        message.endpoint = "\(SCHEME)\(ENDPOINT)"
        message.bucketName = BUCKET_NAME
        
        let delete = OSSNetworkingRequestDelegate()
        delete.allNeededMessage = message
        delete.isPathStyleAccessEnable = true
        delete.buildInternalHttpRequest()
        let url = delete.internalRequest.url?.absoluteString
        let canonicalUrl = "\(SCHEME)\(BUCKET_NAME).\(ENDPOINT)"
        XCTAssertTrue(url == canonicalUrl)
    }

}
