//
//  OSSXMLDictionaryTests.swift
//  OSSSwiftDemoTests
//
//  Created by 怀叙 on 2018/1/14.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import XCTest
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSXMLDictionaryTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testForXMLDictionary() {
        let filePath = Bundle.main.path(forResource: "test", ofType: "xml")
        var dict = NSDictionary.oss_dictionary(withXMLFile: filePath)
        XCTAssertNotNil(dict)
        if dict != nil {
            let strings = (dict as! NSDictionary).oss_arrayValue(forKeyPath: "string-array")
            let titleString = (dict as! NSDictionary).oss_stringValue(forKeyPath: "title")
            let noteDict = (dict as! NSDictionary).oss_dictionaryValue(forKeyPath: "note")
            
            XCTAssertNotNil(strings)
            XCTAssertNotNil(titleString)
            XCTAssertNotNil(noteDict)
        }
        
        let data = NSData.init(contentsOfFile: filePath!)
        let parser = XMLParser.init(data: data! as Data)
        XCTAssertNotNil(parser)
        
        let ossXMLParser = OSSXMLDictionaryParser.sharedInstance()
        ossXMLParser?.preserveComments = true
        dict = ossXMLParser?.dictionary(with: parser)
        
        XCTAssertNotNil(dict)
    }
    
}
