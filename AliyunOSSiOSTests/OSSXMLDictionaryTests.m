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
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"xml"];
    NSDictionary *dict = [NSDictionary oss_dictionaryWithXMLFile:filePath];
    NSLog(@"xml: %@",[dict oss_XMLString]);
    NSArray *string_array = [dict oss_arrayValueForKeyPath:@"string-array"];
    NSString *title = [dict oss_stringValueForKeyPath:@"title"];
    NSDictionary *book= [dict oss_dictionaryValueForKeyPath:@"book"];
    
    NSLog(@"string_array:%@,title:%@,book:%@",string_array,title,book);
    
    XCTAssertNotNil(dict);
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[NSData dataWithContentsOfFile:filePath]];
    dict = [NSDictionary oss_dictionaryWithXMLParser:parser];
    
    OSSXMLDictionaryParser *ossParser = [OSSXMLDictionaryParser sharedInstance];
    ossParser.preserveComments = YES;
    dict = [ossParser dictionaryWithParser:parser];
}

@end
