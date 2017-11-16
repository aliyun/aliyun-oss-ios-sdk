//
//  OSSXMLDictionaryTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/16.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSXMLDictionary.h"

@interface OSSXMLDictionaryTests : XCTestCase

@end

@implementation OSSXMLDictionaryTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testForXMLDictionary{
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"runsheng" ofType:@"xml"];
    NSDictionary *dict = [NSDictionary dictionaryWithXMLFile:filePath];
    NSLog(@"xml: %@",[dict XMLString]);
    NSArray *array = [dict arrayValueForKeyPath:@"string-array"];
    NSString *string = [dict stringValueForKeyPath:@"item"];
    NSDictionary *dict1= [dict dictionaryValueForKeyPath:@"title"];
    
    NSLog(@"array:%@,string:%@,dict1:%@",array,string,dict1);
    
    XCTAssertNotNil(dict);
}

@end
