//
//  OSSSwiftGlobalDefines.swift
//  OSSSwiftDemo
//
//  Created by huaixu on 2018/1/3.
//  Copyright © 2018年 Aliyun. All rights reserved.
//

import Foundation

let OSS_ACCESSKEY_ID: String = "access_key_id"
let OSS_SECRETKEY_ID: String = "access_key_secret"
let OSS_BUCKET_PUBLIC: String = "public-bucket"
let OSS_BUCKET_PRIVATE: String = "private-bucket"
let OSS_ENDPOINT: String = "http://oss-cn-region.aliyuncs.com"
let OSS_MULTIPART_UPLOADKEY: String = "multipart"
let OSS_RESUMABLE_UPLOADKEY: String = "resumable"
let OSS_CALLBACK_URL: String = "http://oss-demo.aliyuncs.com:23450"
let OSS_CNAME_URL: String = "http://www.cnametest.com/"
let OSS_STSTOKEN_URL: String = "http://*.*.*.*.****/sts/getsts"
let OSS_IMAGE_KEY: String = "testImage.png"
let OSS_CRC64_ENABLE: Bool = true
let OSS_CONTENT_TYPE: String = "Content-Type"
let OSS_CONTENT_LENGTH: String = "Content-Length"
let OSS_TEST_CONTENT_TYPE: String = "application/special"
let OSS_APPEND_OBJECT_KEY: String = "appendObject"

let SCHEME = "https://"
let ENDPOINT = "oss-cn-hangzhou.aliyuncs.com"
let CNAME_ENDPOINT = "oss.custom.com"
let IP_ENDPOINT = "192.168.1.1:8080"
let BUCKET_NAME = "BucketName"
let OBJECT_KEY = "ObjectKey"


public protocol Error {
    var _domain: String { get }
    var _code: Int { get }
    var _userInfo: AnyObject? { get }
}

extension NSError : Error {
    @nonobjc
    public var _domain: String { return domain }
    
    @nonobjc
    public var _code: Int { return code }
    
    @nonobjc
    public var _userInfo: AnyObject? { return userInfo as NSDictionary }
}
