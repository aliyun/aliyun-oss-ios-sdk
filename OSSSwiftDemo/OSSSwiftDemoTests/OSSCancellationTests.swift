//
//  OSSCancellationTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/14.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSCancellationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCancel() {
        let cts = OSSCancellationTokenSource()
        
        XCTAssertFalse(cts.isCancellationRequested, "Source should not be cancelled")
        XCTAssertFalse(cts.token.isCancellationRequested, "Token should not be cancelled")
        cts.cancel()
        
        XCTAssertTrue(cts.isCancellationRequested, "Source should be cancelled")
        XCTAssertTrue(cts.token.isCancellationRequested, "Token should be cancelled")
    }
    
    func testCancelMultipleTimes() {
        let cts = OSSCancellationTokenSource()
        
        XCTAssertFalse(cts.isCancellationRequested)
        XCTAssertFalse(cts.token.isCancellationRequested)
        
        cts.cancel()

        XCTAssertTrue(cts.isCancellationRequested)
        XCTAssertTrue(cts.token.isCancellationRequested)
        
        cts.cancel()
        
        XCTAssertTrue(cts.isCancellationRequested)
        XCTAssertTrue(cts.token.isCancellationRequested)
    }
    
    func testCancellationBlock() {
        var cancelled = false
        let cts = OSSCancellationTokenSource()
        cts.token .registerCancellationObserver {
            cancelled = true
        }
        
        XCTAssertFalse(cts.isCancellationRequested, "Source should not be cancelled")
        XCTAssertFalse(cts.token.isCancellationRequested, "Token should not be cancelled")
        
        cts.cancel()
        
        XCTAssertTrue(cancelled, "Source should be cancelled")
    }
    
    func testCancellationAfterDelay() {
        let cts = OSSCancellationTokenSource()
        XCTAssertFalse(cts.isCancellationRequested, "Source should not be cancelled")
        XCTAssertFalse(cts.token.isCancellationRequested, "Token should not be cancelled")
        
        cts.cancel(afterDelay: 200)
        
        XCTAssertFalse(cts.isCancellationRequested, "Source should be cancelled");
        XCTAssertFalse(cts.token.isCancellationRequested, "Token should be cancelled")
        
        // Spin the run loop for half a second, since `delay` is in milliseconds, not seconds.
        RunLoop.current.run(until: Date.init(timeIntervalSinceNow: 0.5))
        
        XCTAssertTrue(cts.isCancellationRequested, "Source should be cancelled");
        XCTAssertTrue(cts.token.isCancellationRequested, "Token should be cancelled")
    }
    
    func testCancellationAfterDelayValidation() {
        let cts = OSSCancellationTokenSource()
        
        XCTAssertFalse(cts.isCancellationRequested)
        XCTAssertFalse(cts.token.isCancellationRequested)
        
        XCTAssertThrowsError(cts.cancel(afterDelay: -2), NSExceptionName.internalInconsistencyException.rawValue) { (error) in
            XCTAssertNotNil(error)
        }
    }
    
    func testCancellationAfterZeroDelay() {
        let cts = OSSCancellationTokenSource()
        
        XCTAssertFalse(cts.isCancellationRequested)
        XCTAssertFalse(cts.token.isCancellationRequested)
        
        cts.cancel(afterDelay: 0)
        
        XCTAssertTrue(cts.isCancellationRequested);
        XCTAssertTrue(cts.token.isCancellationRequested)
    }
    
    func testCancellationAfterDelayOnCancelled() {
        let cts = OSSCancellationTokenSource()
        
        cts.cancel()
        XCTAssertTrue(cts.isCancellationRequested);
        XCTAssertTrue(cts.token.isCancellationRequested)
        
        cts.cancel(afterDelay: 1)
        
        XCTAssertTrue(cts.isCancellationRequested);
        XCTAssertTrue(cts.token.isCancellationRequested)
    }
    
    func testDispose() {
        var cts = OSSCancellationTokenSource()
        cts.dispose()
        
        XCTAssertThrowsError(cts.cancel(), NSExceptionName.internalInconsistencyException.rawValue) { (error) in
            XCTAssertNotNil(error)
        }
        XCTAssertThrowsError(cts.isCancellationRequested, NSExceptionName.internalInconsistencyException.rawValue) { (error) in
            XCTAssertNotNil(error)
        }
        XCTAssertThrowsError(cts.token.isCancellationRequested, NSExceptionName.internalInconsistencyException.rawValue) { (error) in
            XCTAssertNotNil(error)
        }
        
        cts = OSSCancellationTokenSource()
        cts.cancel()
        
        XCTAssertTrue(cts.isCancellationRequested, "Source should be cancelled")
        XCTAssertTrue(cts.token.isCancellationRequested, "Token should be cancelled")
        
        cts.dispose()
        
        XCTAssertThrowsError(cts.isCancellationRequested, NSExceptionName.internalInconsistencyException.rawValue) { (error) in
            XCTAssertNotNil(error)
        }
        XCTAssertThrowsError(cts.token.isCancellationRequested, NSExceptionName.internalInconsistencyException.rawValue) { (error) in
            XCTAssertNotNil(error)
        }
    }
    
    func testDisposeMultipleTimes() {
        let cts = OSSCancellationTokenSource()
        cts.dispose()
        XCTAssertNoThrow(cts.dispose())
    }
    
    func testDisposeRegistration() {
        let cts = OSSCancellationTokenSource()
        let registration = cts.token.registerCancellationObserver {
            XCTFail()
        }
        XCTAssertNoThrow(registration.dispose())
        cts.cancel()
    }
    
    func testDisposeRegistrationMultipleTimes() {
        let cts = OSSCancellationTokenSource()
        let registration = cts.token.registerCancellationObserver {
            XCTFail()
        }
        
        XCTAssertNoThrow(registration.dispose())
        XCTAssertNoThrow(registration.dispose())
        
        cts.cancel()
    }
    
    func testDisposeRegistrationAfterCancellationToken() {
        let cts = OSSCancellationTokenSource()
        let registration = cts.token.registerCancellationObserver {}
        registration.dispose()
        cts.dispose()
    }
    
    func testDisposeRegistrationBeforeCancellationToken() {
        let cts = OSSCancellationTokenSource()
        let registration = cts.token.registerCancellationObserver {}
        cts.dispose()
        XCTAssertNoThrow(registration.dispose())
    }
}
