//
//  OSSConfigurationTest.swift
//  OSSSwiftDemoTests
//
//  Created by ws on 2021/3/29.
//  Copyright © 2021 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS

class OSSConfigurationTest: XCTestCase {

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
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testDefault() {
        let config = OSSClientConfiguration()
        let credentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: ENDPOINT, credentialProvider: credentialProvider, clientConfiguration: config)
        let get = OSSGetObjectRequest()
        get.bucketName = OSS_BUCKET_PUBLIC
        get.objectKey = OSS_MULTIPART_UPLOADKEY
        client.getObject(get).continue({ (task) -> Any? in
            if let user = task.error?._userInfo as? [String: String] {
                XCTAssertTrue(user["HostId"] == "\(OSS_BUCKET_PUBLIC).\(ENDPOINT)")
                XCTAssertTrue(user["BucketName"] == OSS_BUCKET_PUBLIC)
            } else {
                XCTAssertTrue(false)
            }
            
            return task
        }).waitUntilFinished()
    }

    func testPathStyleAccessEnable() {
        let config = OSSClientConfiguration()
        config.maxRetryCount = 0
        config.isPathStyleAccessEnable = true
        config.cnameExcludeList = [CNAME_ENDPOINT]
        let credentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: "https://\(CNAME_ENDPOINT)", credentialProvider: credentialProvider, clientConfiguration: config)
        let get = OSSGetObjectRequest()
        get.bucketName = OSS_BUCKET_PUBLIC
        get.objectKey = OSS_MULTIPART_UPLOADKEY
        client.getObject(get).continue({ (task) -> Any? in
            XCTAssertNotNil(task.error);
            if let user = task.error?._userInfo as? [String: Any],
               let urlString = user["NSErrorFailingURLStringKey"] as? String {
                let url = "\(SCHEME)\(CNAME_ENDPOINT)/\(OSS_BUCKET_PUBLIC)/\(OSS_MULTIPART_UPLOADKEY)"
                XCTAssertTrue(urlString == url)
            } else {
                XCTAssertTrue(false)
            }
            return task
        }).waitUntilFinished()
    }
    
    func testSupportCnameEnable() {
        var config = OSSClientConfiguration()
        config.maxRetryCount = 0
        config.cnameExcludeList = [CNAME_ENDPOINT]
        var credentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        var client = OSSClient(endpoint: "https://\(CNAME_ENDPOINT)", credentialProvider: credentialProvider, clientConfiguration: config)
        var get = OSSGetObjectRequest()
        get.bucketName = OSS_BUCKET_PUBLIC
        get.objectKey = OSS_MULTIPART_UPLOADKEY
        client.getObject(get).continue({ (task) -> Any? in
            XCTAssertNotNil(task.error);
            if let user = task.error?._userInfo as? [String: Any],
               let urlString = user["NSErrorFailingURLStringKey"] as? String {
                let url = "\(SCHEME)\(OSS_BUCKET_PUBLIC).\(CNAME_ENDPOINT)/\(OSS_MULTIPART_UPLOADKEY)"
                XCTAssertTrue(urlString == url)
            } else {
                XCTAssertTrue(false)
            }
            return task
        }).waitUntilFinished()
        
        config = OSSClientConfiguration()
        config.maxRetryCount = 0
        credentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        client = OSSClient(endpoint: "https://\(CNAME_ENDPOINT)", credentialProvider: credentialProvider, clientConfiguration: config)
        get = OSSGetObjectRequest()
        get.bucketName = OSS_BUCKET_PUBLIC
        get.objectKey = OSS_MULTIPART_UPLOADKEY
        client.getObject(get).continue({ (task) -> Any? in
            XCTAssertNotNil(task.error);
            if let user = task.error?._userInfo as? [String: Any],
               let urlString = user["NSErrorFailingURLStringKey"] as? String {
                let url = "\(SCHEME)\(CNAME_ENDPOINT)/\(OSS_MULTIPART_UPLOADKEY)"
                XCTAssertTrue(urlString == url)
            } else {
                XCTAssertTrue(false)
            }
            return task
        }).waitUntilFinished()
    }
    
    func testCustomPathPrefixEnable() {
        let endpointPath = "https://\(CNAME_ENDPOINT)/path"
        let config = OSSClientConfiguration()
        config.maxRetryCount = 0
        config.isCustomPathPrefixEnable = true
        config.cnameExcludeList = [CNAME_ENDPOINT]
        let credentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: endpointPath, credentialProvider: credentialProvider, clientConfiguration: config)
        let get = OSSGetObjectRequest()
        get.bucketName = OSS_BUCKET_PUBLIC
        get.objectKey = OSS_MULTIPART_UPLOADKEY
        client.getObject(get).continue({ (task) -> Any? in
            XCTAssertNotNil(task.error);
            if let user = task.error?._userInfo as? [String: Any],
               let urlString = user["NSErrorFailingURLStringKey"] as? String {
                let url = "\(endpointPath)/\(OSS_MULTIPART_UPLOADKEY)"
                XCTAssertTrue(urlString == url)
            } else {
                XCTAssertTrue(false)
            }
            return task
        }).waitUntilFinished()
    }
    
    func testCustomPathPrefixEnableWithNoPathEndpont() {
        let config = OSSClientConfiguration()
        config.maxRetryCount = 0
        config.isCustomPathPrefixEnable = true
        let credentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: "https://\(CNAME_ENDPOINT)", credentialProvider: credentialProvider, clientConfiguration: config)
        let get = OSSGetObjectRequest()
        get.bucketName = OSS_BUCKET_PUBLIC
        get.objectKey = OSS_MULTIPART_UPLOADKEY
        client.getObject(get).continue({ (task) -> Any? in
            XCTAssertNotNil(task.error);
            if let user = task.error?._userInfo as? [String: Any],
               let urlString = user["NSErrorFailingURLStringKey"] as? String {
                let url = "\(SCHEME)\(CNAME_ENDPOINT)/\(OSS_MULTIPART_UPLOADKEY)"
                XCTAssertTrue(urlString == url)
            } else {
                XCTAssertTrue(false)
            }
            return task
        }).waitUntilFinished()
    }
    
    func testCustomPathPrefixEnableWithNullObject() {
        let config = OSSClientConfiguration()
        config.maxRetryCount = 0
        let credentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: "https://\(CNAME_ENDPOINT)", credentialProvider: credentialProvider, clientConfiguration: config)
        let get = OSSGetBucketRequest()
        get.bucketName = OSS_BUCKET_PUBLIC
        client.getBucket(get).continue({ (task) -> Any? in
            XCTAssertNotNil(task.error);
            if let user = task.error?._userInfo as? [String: Any],
               let urlString = user["NSErrorFailingURLStringKey"] as? String {
                let url = "\(SCHEME)\(CNAME_ENDPOINT)/"
                XCTAssertTrue(urlString == url)
            } else {
                XCTAssertTrue(false)
            }
            return task
        }).waitUntilFinished()
    }
}
