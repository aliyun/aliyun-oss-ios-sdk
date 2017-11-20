//
//  OSSLogTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/15.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSLog.h"
#import "OSSUtil.h"
#import "OSSDDLog.h"


@interface OSSLogTests : XCTestCase

@end

@interface OSSDDTestLogger : NSObject <OSSDDLogger>
@end
@implementation OSSDDTestLogger
@synthesize logFormatter;

- (void)logMessage:(nonnull OSSDDLogMessage *)logMessage {
}

@end

@implementation OSSLogTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [OSSLog enableLog];
    [OSSDDLog removeAllLoggers];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [OSSDDLog removeAllLoggers];
    [super tearDown];
}

- (void)testAddLoggerAddsNewLoggerWithDDLogLevelAll
{
    OSSDDTestLogger *logger = [OSSDDTestLogger new];
    [OSSDDLog addLogger:logger];
    XCTAssertEqual([OSSDDLog allLoggers].count, 1);
}

- (void)testAddLoggerWithLevelAddLoggerWithSpecifiedLevelMask {
    OSSDDTestLogger *logger = [OSSDDTestLogger new];
    [OSSDDLog addLogger:logger withLevel:OSSDDLogLevelDebug | OSSDDLogLevelError];
    XCTAssertEqual([OSSDDLog allLoggers].count, 1);
}

- (void)testRemoveLoggerRemovesExistingLogger {
    OSSDDTestLogger *logger = [OSSDDTestLogger new];
    [OSSDDLog addLogger:logger];
    [OSSDDLog addLogger:[OSSDDTestLogger new]];
    [OSSDDLog removeLogger:logger];
    XCTAssertEqual([OSSDDLog allLoggers].count, 1);
    XCTAssertNotEqual([[OSSDDLog allLoggers] firstObject], logger);
}

- (void)testRemoveAllLoggersRemovesAllLoggers {
    [OSSDDLog addLogger:[OSSDDTestLogger new]];
    [OSSDDLog addLogger:[OSSDDTestLogger new]];
    [OSSDDLog removeAllLoggers];
    XCTAssertEqual([OSSDDLog allLoggers].count, 0);
}

- (void)testAllLoggersReturnsAllLoggers {
    [OSSDDLog addLogger:[OSSDDTestLogger new]];
    [OSSDDLog addLogger:[OSSDDTestLogger new]];
    
    XCTAssertEqual([OSSDDLog allLoggers].count, 2);
}

- (void)testAllLoggersWithLevelReturnsAllLoggersWithLevel {
    NSLog(@"%ld",OSSDDLogFlagInfo);
    [OSSDDLog addLogger:[OSSDDTestLogger new]];
    [OSSDDLog addLogger:[OSSDDTestLogger new] withLevel:OSSDDLogLevelInfo];
    [OSSDDLog addLogger:[OSSDDTestLogger new] withLevel:OSSDDLogLevelDebug];
    XCTAssertEqual([OSSDDLog allLoggers].count, 3);

    OSSDDLoggerInformation *logger0 = [[OSSDDLog allLoggersWithLevel] firstObject];
    OSSDDLoggerInformation *logger1 = [OSSDDLog allLoggersWithLevel][1];
    OSSDDLoggerInformation *logger2 = [[OSSDDLog allLoggersWithLevel] lastObject];

    XCTAssertEqual(logger0.level, OSSDDLogLevelAll);
    XCTAssertEqual(logger1.level, OSSDDLogLevelInfo);
    XCTAssertEqual(logger2.level, OSSDDLogLevelDebug);
}

- (void)testLogForAppTerminate{
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillTerminateNotification object:nil];
}

- (void)testLog
{
    [[OSSDDLog sharedInstance] log:NO level:OSSDDLogLevelVerbose flag:OSSDDLogFlagVerbose context:0 file:__FILE__ function:__PRETTY_FUNCTION__ line:__LINE__ tag:nil format:@"[Debug]: %@",@"test 1"];
    
    OSSDDFileLogger *fileLogger = [[OSSDDFileLogger alloc] init]; // File Logger
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    fileLogger.logFileManager.maximumNumberOfLogFiles = 8;
    
    fileLogger.logFileManager.logFilesDiskQuota = 1024 * 1024;
    fileLogger.logFileManager.logFilesDiskQuota = 1024 * 1024 * 2;
    
    [OSSDDLog addLogger:fileLogger];
    
    OSSDDLogMessage *message = [[OSSDDLogMessage alloc] init];
    [fileLogger logMessage:[message copy]];
    id<OSSDDLogFormatter> formatter = [fileLogger logFormatter];
    NSLog(@"OSSDDLogFormatter: %@",formatter);
    
    [OSSDDLog removeLogger:[[OSSDDLog allLoggers] firstObject]];
}

@end
