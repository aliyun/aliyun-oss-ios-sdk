//
//  MyFirstSwiftClass.swift
//  OSSSwiftDemo
//
//  Created by 怀叙 on 2018/1/2.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import Foundation

@objc(MyFirstSwiftClass)

class 我的类: NSObject{
    func 打招呼(名字: String) -> Void {
        print("哈喽:\(名字)")
    }
}
