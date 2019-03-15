//
//  OSSSwiftDemoTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/11.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSSwiftDemoTests: XCTestCase {
    var client: OSSClient!
    let fileNames: [String] = ["file1k", "file10k", "file100k", "file1m", "file5m", "file10m", "fileDirA/", "fileDirB/"]
    let fileSizes: [NSNumber] = [NSNumber.init(value: 1024),
                                 NSNumber.init(value: 10240),
                                 NSNumber.init(value: 102400),
                                 NSNumber.init(value: 1048576),
                                 NSNumber.init(value: 5242880),
                                 NSNumber.init(value: 10485760),
                                 NSNumber.init(value: 1024),
                                 NSNumber.init(value: 1024)]
    
    let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first;
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        OSSLog.enable()
        setupClient()
        setupLocalFiles()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func setupClient() -> Void {
        let configuration = OSSClientConfiguration()
        let provider = OSSAuthCredentialProvider.init(authServerUrl: OSS_STSTOKEN_URL)
        
        client = OSSClient.init(endpoint: OSS_ENDPOINT,
                                credentialProvider: provider,
                                clientConfiguration: configuration)
    }
    
    func setupLocalFiles() -> Void {
        let fm = FileManager.default
        for i in 0...7
        {
            let baseData = NSMutableData.init(capacity: 1024)
            for index in 1...256 {
                let stride = MemoryLayout<Int>.stride
                let alignment = MemoryLayout<Int>.alignment
                
                do {
                    let pointer = UnsafeMutableRawPointer.allocate(bytes: stride, alignedTo: alignment)
                    defer {
                        pointer.deallocate(bytes: stride, alignedTo: alignment)
                    }
                    
                    pointer.storeBytes(of: index, as: Int.self)
                    
                    baseData?.append(UnsafeRawPointer(pointer), length: 4)
                }
            }
            
            let fileName = fileNames[i]
            let fileSize = Int64.init(exactly: fileSizes[i])
            let filePath = (documentDirectory! as NSString).appendingPathComponent(fileName)
            print("filePath: \(filePath)")
            
            if fm.fileExists(atPath: filePath) {
                continue
            }
            fm.createFile(atPath: filePath, contents: nil, attributes: nil)
            let handler = FileHandle.init(forWritingAtPath: filePath)
            
            let unitLength: Int64 = 1024
            let maxium = fileSize!/unitLength
            
            for _ in 0...(maxium - 1) {
                handler?.write(baseData! as Data)
            }
            handler?.closeFile()
        }
    }
    
}
