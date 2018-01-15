//
//  OSSLogTests.swift
//  OSSSwiftDemoTests
//
//  Created by 怀叙 on 2018/1/13.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSLogTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        OSSLog.enable()
        OSSDDLog.removeAllLoggers()
        resetDefaultDebugLevel()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testtestAddLoggerAddsNewLoggerWithDDLogLevelAll() {
        let logger = OSSDDAbstractLogger()
        OSSDDLog.add(logger)
        XCTAssertEqual(OSSDDLog.allLoggers.count, 1)
    }
    
    func testAddLoggerWithLevelAddLoggerWithSpecifiedLevelMask() {
        let logger = OSSDDAbstractLogger()
        OSSDDLog.add(logger, with: .debug)
        XCTAssertEqual(OSSDDLog.allLoggers.count, 1)
    }
    
    func testRemoveLoggerRemovesExistingLogger() {
        let logger = OSSDDAbstractLogger()
        OSSDDLog.add(logger, with: .debug)
        let other = OSSDDAbstractLogger()
        OSSDDLog.add(other, with: .debug)
        OSSDDLog.remove(logger)
        XCTAssertEqual(OSSDDLog.allLoggers.count, 1)
        XCTAssertNotEqual(OSSDDLog.allLoggers.first as! OSSDDAbstractLogger, logger)
    }
    
    func testRemoveAllLoggersRemovesAllLoggers() {
        let logger = OSSDDAbstractLogger()
        OSSDDLog.add(logger, with: .debug)
        let other = OSSDDAbstractLogger()
        OSSDDLog.add(other, with: .debug)
        OSSDDLog.removeAllLoggers()
        XCTAssertEqual(OSSDDLog.allLoggers.count, 0)
    }
    
    func testAllLoggersReturnsAllLoggers() {
        let logger = OSSDDAbstractLogger()
        OSSDDLog.add(logger, with: .debug)
        let other = OSSDDAbstractLogger()
        OSSDDLog.add(other, with: .debug)
        XCTAssertEqual(OSSDDLog.allLoggers.count, 2)
    }
    
    func testAllLoggersWithLevelReturnsAllLoggersWithLevel() {
        let logger = OSSDDAbstractLogger()
        OSSDDLog.add(logger, with: .verbose)
        let other = OSSDDAbstractLogger()
        OSSDDLog.add(other, with: .debug)
        let third = OSSDDAbstractLogger()
        OSSDDLog.add(third, with: .info)
        
        XCTAssertEqual(OSSDDLog.allLoggers.count, 3)
        
        XCTAssertEqual((OSSDDLog.allLoggersWithLevel.first)?.level.rawValue, OSSDDLogLevel.verbose.rawValue)
        XCTAssertEqual((OSSDDLog.allLoggersWithLevel[1]).level.rawValue, OSSDDLogLevel.debug.rawValue)
        XCTAssertEqual((OSSDDLog.allLoggersWithLevel.last)?.level.rawValue, OSSDDLogLevel.info.rawValue)
    }
    
    func testLogForAppTerminate() {
        NotificationCenter.default.post(name: .UIApplicationWillTerminate, object: nil)
    }
    
    func testLog() {
        OSSLogVerbose("OSSLogVerbose")
        OSSLogInfo("OSSLogInfo")
        OSSLogWarn("OSSLogWarn")
        OSSLogError("OSSLogError")
        OSSLogDebug("OSSLogDebug")
        let fileName = CurrentFileName()
        XCTAssertNotNil(fileName)
    }
    
}
