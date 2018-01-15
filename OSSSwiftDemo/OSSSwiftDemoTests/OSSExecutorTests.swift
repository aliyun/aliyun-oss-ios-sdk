//
//  OSSExecutorTests.swift
//  OSSSwiftDemoTests
//
//  Created by huaixu on 2018/1/14.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSExecutorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExecuteImmediately() {
        var task = OSSTask<AnyObject>.init(result: nil)
        let expectation = self.expectation(description: "test immediate executor")
        DispatchQueue.global().async {
            task = task.continue(with: OSSExecutor.immediate(), with: { (t) -> Any? in
                return nil
            })
            XCTAssertTrue(task.isCompleted)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testExecuteOnDispatchQueue() {
        
        let testQueueLabel = "com.example.my-test-queue"
        let testQueue = DispatchQueue(label: testQueueLabel, attributes: [])
        let testQueueKey = DispatchSpecificKey<Void>()

        testQueue.setSpecific(key: testQueueKey, value: ())
        
        XCTAssertNil(DispatchQueue.getSpecific(key: testQueueKey))
        
        let queueExecutor = OSSExecutor.init(dispatchQueue: testQueue)
        var task = OSSTask<AnyObject>.init(result: nil)
        task = task.continue(with: queueExecutor, with: { (t) -> Any? in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey), "callback should be called on specified queue")

            return nil
        })
        task.waitUntilFinished()
        
        XCTAssertNil(DispatchQueue.getSpecific(key: testQueueKey))
    }
    
    func testMainThreadExecutor() {
        let executor = OSSExecutor.mainThread()
        let immediateExpectation = self.expectation(description: "test main thread executor on main thread")
        executor.execute {
            XCTAssertTrue(Thread.isMainThread)
            immediateExpectation.fulfill()
        }
        
        // Behaviour is different when running on main thread (runs immediately) vs running on the background queue.
        let backgroundExpectation = self.expectation(description: "test main thread executor on background thread")
        DispatchQueue.global().async {
            executor.execute {
                XCTAssertTrue(Thread.isMainThread)
                backgroundExpectation.fulfill()
            }
        }
        self.waitForExpectations(timeout: 10, handler: nil)
    }
}
