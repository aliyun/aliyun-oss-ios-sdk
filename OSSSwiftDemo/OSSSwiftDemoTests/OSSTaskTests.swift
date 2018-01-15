//
//  OSSTaskTests.swift
//  OSSSwiftDemoTests
//
//  Created by 怀叙 on 2018/1/13.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSTaskTests: OSSSwiftDemoTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBasicOnSuccess() {
        OSSTask<AnyObject>.init(result: "foo" as AnyObject).continue(successBlock: { (t) -> Any? in
            XCTAssertEqual("foo", t.result as! String)
            return nil
        }).waitUntilFinished()
    }
    
    func testBasicOnSuccessWithExecutor() {
        var completed = false
        let task = (OSSTask<AnyObject>.init(delay: 100)).continue(with: OSSExecutor.immediate(), withSuccessBlock: { (t) -> Any? in
            completed = true
            
            return nil
        })
        task.waitUntilFinished()
        XCTAssertTrue(completed)
        XCTAssertTrue(task.isCompleted)
        XCTAssertFalse(task.isFaulted)
        XCTAssertFalse(task.isCancelled)
        XCTAssertNil(task.result)
    }
    
    func testBasicOnSuccessWithToken() {
        let cts = OSSCancellationTokenSource()
        var task = OSSTask<AnyObject>.init(delay: 100)
        task = task.continue(successBlock: { (t) -> Any? in
            XCTFail("Success block should not be triggered")
            return nil
        }, cancellationToken: cts.token)
        
        cts.cancel()
        task.waitUntilFinished()
        
        XCTAssertTrue(task.isCancelled)
    }
    
    func testBasicOnSuccessWithExecutorToken() {
        let cts = OSSCancellationTokenSource()
        var task = OSSTask<AnyObject>.init(delay: 100)
        task = task.continue(with: OSSExecutor.immediate(),
                             successBlock: { (t) -> Any? in
                                XCTFail("Success block should not be triggered")
                                
                                return nil
        }, cancellationToken: cts.token)
        cts.cancel()
        task.waitUntilFinished()
        
        XCTAssertTrue(task.isCancelled)
    }
    
    func testBasicOnSuccessWithCancelledToken() {
        let cts = OSSCancellationTokenSource()
        var task = OSSTask<AnyObject>.init(result: nil)
        cts.cancel()
        
        task = task .continue(with: OSSExecutor.immediate(),
                              successBlock: { (t) -> Any? in
                                XCTFail("Success block should not be triggered")
                                
                                return nil
        }, cancellationToken: cts.token)
        XCTAssertTrue(task.isCancelled)
    }
    
    func testBasicContinueWithError() {
        let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 22, userInfo: nil)
        OSSTask<AnyObject>.init(error: error).continue({ (t) -> Any? in
            XCTAssertNotNil(t.error, "Task should have failed.");
            let finalError = t.error! as NSError
            XCTAssertEqual(22, finalError.code);
            
            return nil
        }).waitUntilFinished()
    }
    
    func testBasicContinueWithToken() {
        let cts = OSSCancellationTokenSource()
        var task = OSSTask<AnyObject>.init(delay: 100)
        task = task.continue(with: OSSExecutor.immediate(),
                      block: { (t) -> Any? in
                        XCTFail("Continuation block should not be triggered");
                        
                        return nil;
        }, cancellationToken: cts.token)
        cts.cancel()
        task.waitUntilFinished()
        
        XCTAssertTrue(task.isCancelled)
    }
    
    func testBasicContinueWithCancelledToken() {
        let cts = OSSCancellationTokenSource()
        var task = OSSTask<AnyObject>.init(result: nil)
        cts.cancel()
        task = task.continue(with: OSSExecutor.immediate(),
                             block: { (t) -> Any? in
                        XCTFail("Continuation block should not be triggered");
                        
                        return nil;
                                
        }, cancellationToken: cts.token)
        
        XCTAssertTrue(task.isCancelled)
    }
    
    func testFinishLaterWithSuccess() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertEqual("bar", t.result as! String)
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setResult("bar" as AnyObject)
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testFinishLaterWithError() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(23, error.code)
            
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setError(NSError.init(domain: "OSS-SWIFT-SDK", code: 23, userInfo: nil))
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testTransformConstantToConstant() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertEqual("foo", t.result as! String)
            
            return "bar"
        }).continue({ (t) -> Any? in
            XCTAssertEqual("bar", t.result as! String)
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setResult("foo" as AnyObject)
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testTransformErrorToConstant() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            
            let error = t.error! as NSError
            XCTAssertEqual(23, error.code)
            
            return "bar"
        }).continue({ (t) -> Any? in
            XCTAssertEqual("bar", t.result as! String)
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setError(NSError.init(domain: "OSS-SWIFT-SDK", code: 23, userInfo: nil))
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testReturnSuccessfulTaskFromContinuation() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertEqual("foo", t.result as! String)
            
            return OSSTask<AnyObject>.init(result: "bar" as AnyObject)
        }).continue({ (t) -> Any? in
            XCTAssertEqual("bar", t.result as! String)
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setResult("foo" as Any as AnyObject)
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testReturnSuccessfulTaskFromContinuationAfterError() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let finalError = t.error! as NSError
            XCTAssertEqual(23, finalError.code)
            
            return OSSTask<AnyObject>.init(result: "bar" as AnyObject)
        }).continue({ (t) -> Any? in
            XCTAssertEqual("bar", t.result as! String)
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setError(NSError.init(domain: "OSS-SWIFT-SDK", code: 23, userInfo: nil))
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testReturnErrorTaskFromContinuation() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertEqual("foo", t.result as! String)
            let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 24, userInfo: nil)
            
            return OSSTask<AnyObject>.init(error: error)
        }).continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(24, error.code)
            
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setResult("foo" as AnyObject)
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testReturnErrorTaskFromContinuationAfterError() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = tcs.task.continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 24, userInfo: nil)
            
            return OSSTask<AnyObject>.init(error: error)
        }).continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(24, error.code)
            
            return nil
        })
        
        OSSTask<AnyObject>.init(delay: 0).continue({ (t) -> Any? in
            tcs.setError(NSError.init(domain: "OSS-SWIFT-SDK", code: 23, userInfo: nil))
            
            return nil
        })
        
        task.waitUntilFinished()
    }
    
    func testPassOnError() {
        let orignalError = NSError.init(domain: "OSS-SWIFT-SDK", code: 30, userInfo: nil)
        OSSTask<AnyObject>.init(error: orignalError).continue(successBlock: { (t) -> Any? in
            XCTFail("This callback should be skipped.")
            return nil
        }).continue(successBlock: { (t) -> Any? in
            XCTFail("This callback should be skipped.")
            return nil
        }).continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(30, error.code)
            
            let otherError = NSError.init(domain: "OSS-SWIFT-SDK", code: 31, userInfo: nil)
            
            return OSSTask<AnyObject>.init(error: otherError)
        }).continue(successBlock: { (t) -> Any? in
            XCTFail("This callback should be skipped.")
            return nil
        }).continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            let error = t.error! as NSError
            XCTAssertEqual(31, error.code)
            
            return OSSTask<AnyObject>.init(result: "okay" as AnyObject)
        }).continue(successBlock: { (t) -> Any? in
            XCTAssertEqual("okay", t.result as! String)
            return nil
        }).waitUntilFinished()
    }
    
    func testCancellation() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let task = OSSTask<AnyObject>.init(delay: 100).continue({ (t) -> Any? in
            return tcs.task
            
            return nil
        })
        tcs .cancel()
        task.waitUntilFinished()
        
        XCTAssertTrue(task.isCancelled)
    }
    
    func testTaskForCompletionOfAllTasksSuccess() {
        var tasks: [OSSTask<AnyObject>] = [] as! [OSSTask<AnyObject>]
        for index in 0...19 {
            let task = OSSTask<AnyObject>.init(delay: Int32(arc4random() % 100)).continue({ (t) -> Any? in
                return index
            })
            tasks.append(task)
        }
        
        OSSTask<AnyObject>.init(forCompletionOfAllTasks: tasks).continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            XCTAssertFalse(t.isCancelled)
            for index in 0...19 {
                XCTAssertEqual(index, (tasks[index].result as! Int))
            }
            
            return nil
        }).waitUntilFinished()
    }
    
    func testTaskForCompletionOfAllTasksOneError() {
        var tasks: [OSSTask<AnyObject>] = [] as! [OSSTask<AnyObject>]
        for index in 0...19 {
            let task = OSSTask<AnyObject>.init(delay: Int32(arc4random() % 100)).continue({ (t) -> Any? in
                if index == 10 {
                    let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 35, userInfo: nil)
                    return OSSTask<AnyObject>.init(error: error)
                }
                return index
            })
            tasks.append(task)
        }
        
        OSSTask<AnyObject>.init(forCompletionOfAllTasks: tasks).continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            XCTAssertFalse(t.isCancelled)
            let error = t.error! as NSError
            XCTAssertEqual("OSS-SWIFT-SDK", error.domain)
            XCTAssertEqual(35, error.code)
            
            for index in 0...19 {
                if index == 10 {
                    XCTAssertNotNil(tasks[index].error);
                } else {
                    XCTAssertEqual(index, (tasks[index].result as! Int))
                }
            }
            
            return nil
        }).waitUntilFinished()
    }
    
    func testTaskForCompletionOfAllTasksTwoErrors() {
        var tasks: [OSSTask<AnyObject>] = [] as! [OSSTask<AnyObject>]
        for index in 0...19 {
            let task = OSSTask<AnyObject>.init(delay: Int32(arc4random() % 100)).continue({ (t) -> Any? in
                if index == 10 || index == 11 {
                    let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 35, userInfo: nil)
                    return OSSTask<AnyObject>.init(error: error)
                }
                return index
            })
            tasks.append(task)
        }
        
        OSSTask<AnyObject>.init(forCompletionOfAllTasks: tasks).continue({ (t) -> Any? in
            XCTAssertNotNil(t.error)
            XCTAssertFalse(t.isCancelled)
            let error = t.error! as NSError
            XCTAssertEqual("bolts", error.domain)
            XCTAssertEqual(kOSSMultipleErrorsError, error.code)
            let errors = (t.error! as NSError).userInfo[OSSTaskMultipleErrorsUserInfoKey] as! [NSError]
            XCTAssertEqual("OSS-SWIFT-SDK", errors[0].domain)
            XCTAssertEqual(35, errors[0].code)
            
            XCTAssertEqual("OSS-SWIFT-SDK", errors[1].domain)
            XCTAssertEqual(35, errors[1].code)
            
            for index in 0...19 {
                if index == 10 || index == 11 {
                    XCTAssertNotNil(tasks[index].error);
                } else {
                    XCTAssertEqual(index, (tasks[index].result as! Int))
                }
            }
            
            return nil
        }).waitUntilFinished()
    }
    
    func testTaskForCompletionOfAllTasksCancelled() {
        var tasks: [OSSTask<AnyObject>] = [] as! [OSSTask<AnyObject>]
        for index in 0...19 {
            let task = OSSTask<AnyObject>.init(delay: Int32(arc4random() % 100)).continue({ (t) -> Any? in
                if index == 10 {
                    return OSSTask<AnyObject>.cancelled()
                }
                return index
            })
            tasks.append(task)
        }
        
        OSSTask<AnyObject>.init(forCompletionOfAllTasks: tasks).continue({ (t) -> Any? in
            XCTAssertNil(t.error)
            XCTAssertTrue(t.isCancelled)
            
            for index in 0...19 {
                if index == 10 {
                    XCTAssertNotNil(tasks[index].isCancelled);
                } else {
                    XCTAssertEqual(index, (tasks[index].result as! Int))
                }
            }
            
            return nil
        }).waitUntilFinished()
    }
    
    func testTaskForCompletionOfAllTasksNoTasksImmediateCompletion() {
        let tasks: [OSSTask<AnyObject>] = [] as! [OSSTask<AnyObject>]
        let task = OSSTask<AnyObject>.init(forCompletionOfAllTasks: tasks)
        
        XCTAssertTrue(task.isCompleted)
        XCTAssertFalse(task.isCancelled)
        XCTAssertFalse(task.isFaulted)
        
    }
    
    func testTaskForCompletionOfAllTasksWithResultsSuccess() {
        var tasks: [OSSTask<AnyObject>] = [] as! [OSSTask<AnyObject>]
        for index in 0...19 {
            let task = OSSTask<AnyObject>.init(delay: Int32(index * 10)).continue({ (t) -> Any? in
                
                return (index + 1)
            })
            tasks.append(task)
        }
        OSSTask<AnyObject>.init(forCompletionOfAllTasksWithResults: tasks).continue({ (t) -> Any? in
            XCTAssertFalse(t.isCancelled)
            XCTAssertFalse(t.isFaulted)
            
            let results = t.result! as! [Int]
            for index in 0...19 {
                XCTAssertEqual(results[index], tasks[index].result as! Int)
            }
            
            return nil
        }).waitUntilFinished()
    }
    
    func testTaskForCompletionOfAllTasksErrorCancelledSuccess() {
        let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 8, userInfo: nil)
        let errorTask = OSSTask<AnyObject>.init(error: error)
        let cancelledTask = OSSTask<AnyObject>.cancelled()
        let successfulTask = OSSTask<AnyObject>.init(result: "2" as AnyObject)
        let allTasks = OSSTask<AnyObject>.init(forCompletionOfAllTasks: [successfulTask, cancelledTask, errorTask])
        XCTAssertTrue(allTasks.isFaulted,"Task should be faulted")
    }
    
    func testTaskForCompletionOfAllTasksExceptionErrorCancelledSuccess() {
        let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 8, userInfo: nil)
        let errorTask = OSSTask<AnyObject>.init(error: error)
        let cancelledTask = OSSTask<AnyObject>.cancelled()
        let successfulTask = OSSTask<AnyObject>.init(result: "2" as AnyObject)
        let allTasks = OSSTask<AnyObject>.init(forCompletionOfAllTasks: [successfulTask, cancelledTask, errorTask])
        
        XCTAssertTrue(allTasks.isFaulted, "Task should be faulted")
        XCTAssertNotNil(allTasks.error, "Task should have error")
    }
    
    func testTaskForCompletionOfAllTasksErrorCancelled() {
        let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 8, userInfo: nil)
        let errorTask = OSSTask<AnyObject>.init(error: error)
        let cancelledTask = OSSTask<AnyObject>.cancelled()
        let allTasks = OSSTask<AnyObject>.init(forCompletionOfAllTasks: [cancelledTask, errorTask])
        
        XCTAssertTrue(allTasks.isFaulted, "Task should be faulted")
    }
    
    func testTaskForCompletionOfAllTasksSuccessCancelled() {
        let cancelledTask = OSSTask<AnyObject>.cancelled()
        let successfulTask = OSSTask<AnyObject>.init(result: "2" as AnyObject)
        let allTasks = OSSTask<AnyObject>.init(forCompletionOfAllTasks: [successfulTask, cancelledTask])
        
        XCTAssertTrue(allTasks.isCancelled, "Task should be cancelled")
    }
    
    func testTaskForCompletionOfAllTasksSuccessError() {
        let error = NSError.init(domain: "OSS-SWIFT-SDK", code: 8, userInfo: nil)
        let errorTask = OSSTask<AnyObject>.init(error: error)
        let successfulTask = OSSTask<AnyObject>.init(result: "2" as AnyObject)
        let allTasks = OSSTask<AnyObject>.init(forCompletionOfAllTasks: [successfulTask, errorTask])
        
        XCTAssertTrue(allTasks.isFaulted, "Task should be faulted")
    }
    
    func testTaskForCompletionOfAllTasksWithResultsNoTasksImmediateCompletion() {
        let tasks: [OSSTask<AnyObject>] = [] as [OSSTask<AnyObject>]
        let task = OSSTask<AnyObject>.init(forCompletionOfAllTasksWithResults: tasks)
        
        XCTAssertTrue(task.isCompleted)
        XCTAssertFalse(task.isCancelled)
        XCTAssertFalse(task.isFaulted)
        XCTAssertNotNil(task.result)
    }
    
    func testTasksForTaskForCompletionOfAnyTasksWithSuccess() {
        let task = OSSTask<AnyObject>.init(forCompletionOfAnyTask: [OSSTask<AnyObject>.init(delay: 20),OSSTask<AnyObject>.init(result: "success" as AnyObject)])
        task.waitUntilFinished()
        
        XCTAssertEqual("success", task.result as! String)
    }
    
    func testTasksForTaskForCompletionOfAnyTasksWithRacing() {
        let semaphore = DispatchSemaphore(value: 0)
        let executor = OSSExecutor.init(dispatchQueue: DispatchQueue.global())
        let first = OSSTask<AnyObject>.init(from: executor) { () -> Any in
            
            return "first"
        }
        
        let second = OSSTask<AnyObject>.init(from: executor) { () -> Any in
            semaphore.wait(timeout: DispatchTime.distantFuture)
            return "second"
        }
        
        let task = OSSTask<AnyObject>.init(forCompletionOfAnyTask: [first, second])
        task.waitUntilFinished()
        semaphore.signal()
        
        XCTAssertEqual("first", task.result as! String)
    }
    
    func testTasksForTaskForCompletionOfAnyTasksWithErrorAndSuccess() {
        let error = NSError.init(domain: "OSS-SWIFT_SDK", code: 35, userInfo: nil)
        let task = OSSTask<AnyObject>.init(forCompletionOfAnyTask: [OSSTask<AnyObject>.init(error: error), OSSTask<AnyObject>.init(result: "success" as AnyObject)])
        task.waitUntilFinished()
        
        XCTAssertEqual("success", task.result as! String)
        XCTAssertNil(task.error)
    }
    
    func testTasksForTaskForCompletionOfAnyTasksWithError() {
        let error = NSError.init(domain: "OSS-SWIFT_SDK", code: 35, userInfo: nil)
        let task = OSSTask<AnyObject>.init(forCompletionOfAnyTask: [OSSTask<AnyObject>.init(error: error)])
        task.waitUntilFinished()
        
        XCTAssertEqual(error, task.error as! NSError)
        XCTAssertNotNil(task.error)
    }
    
    func testTasksForTaskForCompletionOfAnyTasksWithNilArray() {
        let task = OSSTask<AnyObject>.init(forCompletionOfAnyTask: nil)
        task.waitUntilFinished()
        
        XCTAssertNil(task.result)
        XCTAssertNil(task.error)
    }
    
    func testTasksForTaskForCompletionOfAnyTasksAllErrors() {
        let error = NSError.init(domain: "OSS-SWIFT_SDK", code: 35, userInfo: nil)
        let task = OSSTask<AnyObject>.init(forCompletionOfAnyTask: [OSSTask<AnyObject>.init(error: error), OSSTask<AnyObject>.init(error: error)])
        task.waitUntilFinished()
        
        XCTAssertNil(task.result)
        XCTAssertNotNil(task.error)
        XCTAssertNotNil((task.error! as NSError).userInfo)
        XCTAssertEqual("bolts", (task.error! as NSError).domain)
        XCTAssertTrue((task.error! as NSError).userInfo["errors"] is Array<Any>)
        XCTAssertEqual(2, ((task.error! as NSError).userInfo["errors"] as! Array<Any>).count)
    }
    
    func testWaitUntilFinished() {
        let task = OSSTask<AnyObject>.init(delay: 50).continue({ (t) -> Any? in
            return "foo"
        })
        task.waitUntilFinished()
        
        XCTAssertEqual("foo", task.result as! String)
    }
    
    func testDelayWithToken() {
        let cts = OSSCancellationTokenSource()
        let task = OSSTask<AnyObject>.init(delay: 100, cancellationToken: cts.token)
        cts.cancel()
        task.waitUntilFinished()
        
        XCTAssertTrue(task.isCancelled, "Task should be cancelled immediately")
    }
    
    func testDelayWithCancelledToken() {
        let cts = OSSCancellationTokenSource()
        cts.cancel()
        let task = OSSTask<AnyObject>.init(delay: 100, cancellationToken: cts.token)
        cts.cancel()
        task.waitUntilFinished()
        
        XCTAssertTrue(task.isCancelled, "Task should be cancelled immediately")
    }
    
    func testTaskFromExecutor() {
        
        let testQueueLabel = "com.example.my-test-queue"
        let testQueue = DispatchQueue(label: testQueueLabel, attributes: [])
        let testQueueKey = DispatchSpecificKey<Void>()
        
        testQueue.setSpecific(key: testQueueKey, value: ())
        
        XCTAssertNil(DispatchQueue.getSpecific(key: testQueueKey))
        
        let queueExecutor = OSSExecutor.init(dispatchQueue: testQueue)
        let task = OSSTask<AnyObject>.init(from: queueExecutor) { () -> Any in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey), "callback should be called on specified queue")
        
            return "foo"
        }
        task.waitUntilFinished()
        XCTAssertEqual("foo", task.result as! String)
        XCTAssertNil(DispatchQueue.getSpecific(key: testQueueKey))
    }
    
    func testDescription() {
        let task = OSSTask<AnyObject>.init(result: nil)
        let expected = String.init(format: "<OSSTask: %p; completed = YES; cancelled = NO; faulted = NO; result = (null)>", task)
        let description = task.description
        XCTAssertEqual(expected, description)
    }
    
    func testReturnTaskFromContinuationWithCancellation() {
        let cts = OSSCancellationTokenSource()
        let expectation = self.expectation(description: "task")
        OSSTask<AnyObject>.init(delay: 1).continue({ (t) -> Any? in
            cts.cancel()
            
            return OSSTask<AnyObject>.init(delay: 10)
        }, cancellationToken: cts.token).continue({ (t) -> Any? in
            XCTAssertTrue(t.isCancelled);
            expectation.fulfill()
            
            return nil
        })
        
        self.waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testSetResult() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        tcs.setResult("a" as Any as AnyObject)
        XCTAssertThrowsError(tcs.setResult("b" as AnyObject), NSExceptionName.internalInconsistencyException.rawValue) { (e) in
            XCTAssertNotNil(e)
        }
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertEqual(tcs.task.result as! String, "a")
    }
    
    func testTrySetResult() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        tcs.trySetResult("a" as Any as AnyObject)
        tcs.trySetResult("b" as Any as AnyObject)
        
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertEqual(tcs.task.result as! String, "a")
    }
    
    func testSetError() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let error = NSError.init(domain: "TestDomain", code: 100500, userInfo: nil)
        tcs.setError(error)
        XCTAssertThrowsError(tcs.setError(error), NSExceptionName.internalInconsistencyException.rawValue) { (e) in
            XCTAssertNotNil(e)
        }
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertTrue(tcs.task.isFaulted)
        XCTAssertEqual(tcs.task.error! as NSError, error)
    }
    
    func testTrySetError() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let error = NSError.init(domain: "TestDomain", code: 100500, userInfo: nil)
        tcs.trySetError(error)
        tcs.trySetError(error)
        
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertTrue(tcs.task.isFaulted)
        XCTAssertEqual(tcs.task.error! as NSError, error)
    }
    
    func testSetException() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let exception = NSException.init(name: NSExceptionName(rawValue: "testExceptionName"), reason: "testExceptionReason", userInfo: nil)
        tcs.setException(exception)
        XCTAssertThrowsError(tcs.setException(exception), NSExceptionName.internalInconsistencyException.rawValue) { (e) in
            XCTAssertNotNil(e)
        }
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertTrue(tcs.task.isFaulted)
        XCTAssertEqual(tcs.task.exception, exception)
    }
    
    func testTrySetException() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let exception = NSException.init(name: NSExceptionName(rawValue: "testExceptionName"), reason: "testExceptionReason", userInfo: nil)
        tcs.trySetException(exception)
        tcs.trySetException(exception)
        
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertTrue(tcs.task.isFaulted)
        XCTAssertEqual(tcs.task.exception, exception)
    }
    
    func testSetCancelled() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        tcs.cancel()
        XCTAssertThrowsError(tcs.cancel(), NSExceptionName.internalInconsistencyException.rawValue) { (e) in
            XCTAssertNotNil(e)
        }
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertTrue(tcs.task.isCancelled)
    }
    
    func testTrySetCancelled() {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        tcs.trySetCancelled()
        tcs.trySetCancelled()
        
        XCTAssertTrue(tcs.task.isCompleted)
        XCTAssertTrue(tcs.task.isCancelled)
    }
    
    func testMultipleWaitUntilFinished() {
        let task = OSSTask<AnyObject>.init(delay: 50).continue({ (t) -> Any? in
            return "foo"
        })
        task.waitUntilFinished()
        
        let expectation = self.expectation(description: "testMultipleWaitUntilFinished")
        DispatchQueue.global().async {
            task.waitUntilFinished()
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testMultipleThreadsWaitUntilFinished() {
        let task = OSSTask<AnyObject>.init(delay: 500).continue({ (t) -> Any? in
            return "foo"
        })
        
        let queue = DispatchQueue.init(label: "com.bolts.tests.wait")
        let group = DispatchGroup.init()
        
        let expectation = self.expectation(description: "testMultipleThreadsWaitUntilFinished")
        DispatchQueue.global().async {
            queue.async(group: group, execute: DispatchWorkItem.init(block: {
                task.waitUntilFinished()
            }))
            queue.async(group: group, execute: DispatchWorkItem.init(block: {
                task.waitUntilFinished()
            }))
            task.waitUntilFinished()
            group.wait(timeout: .distantFuture)
            
            expectation.fulfill()
        }
        
        
        self.waitForExpectations(timeout: 10, handler: nil)
    }
}
