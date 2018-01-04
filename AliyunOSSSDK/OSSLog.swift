//
//  OSSLog.swift
//  AliyunOSSSDK
//
//  Created by 怀叙 on 2018/1/3.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import AliyunOSSiOS

extension OSSDDLogFlag {
    public static func from(_ logLevel: OSSDDLogLevel) -> OSSDDLogFlag {
        return OSSDDLogFlag(rawValue: logLevel.rawValue)
    }
    
    public init(_ logLevel: OSSDDLogLevel) {
        self = OSSDDLogFlag(rawValue: logLevel.rawValue)
    }
    
    ///returns the log level, or the lowest equivalant.
    public func toLogLevel() -> OSSDDLogLevel {
        if let ourValid = OSSDDLogLevel(rawValue: rawValue) {
            return ourValid
        } else {
            if contains(.verbose) {
                return .verbose
            } else if contains(.debug) {
                return .debug
            } else if contains(.info) {
                return .info
            } else if contains(.warning) {
                return .warning
            } else if contains(.error) {
                return .error
            } else {
                return .off
            }
        }
    }
}

public var defaultDebugLevel = OSSDDLogLevel.verbose

public func resetDefaultDebugLevel() {
    defaultDebugLevel = OSSDDLogLevel.verbose
}

public func _OSSLogMessage(_ message: @autoclosure () -> String, level: OSSDDLogLevel, flag: OSSDDLogFlag, context: Int, file: StaticString, function: StaticString, line: UInt, tag: Any?, asynchronous: Bool, osslog: OSSDDLog) {
    if level.rawValue & flag.rawValue != 0 {
        // Tell the OSSLogMessage constructor to copy the C strings that get passed to it.
        let logMessage = OSSDDLogMessage(message: message(), level: level, flag: flag, context: context, file: String(describing: file), function: String(describing: function), line: line, tag: tag, options: [.copyFile, .copyFunction], timestamp: nil)
        osslog.log(asynchronous: asynchronous, message: logMessage)
    }
}

public func OSSLogDebug(_ message: @autoclosure () -> String, level: OSSDDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, osslog: OSSDDLog = OSSDDLog.sharedInstance) {
    _OSSLogMessage(message, level: level, flag: .debug, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, osslog: osslog)
}

public func OSSLogInfo(_ message: @autoclosure () -> String, level: OSSDDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, osslog: OSSDDLog = OSSDDLog.sharedInstance) {
    _OSSLogMessage(message, level: level, flag: .info, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, osslog: osslog)
}

public func OSSLogWarn(_ message: @autoclosure () -> String, level: OSSDDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, osslog: OSSDDLog = OSSDDLog.sharedInstance) {
    _OSSLogMessage(message, level: level, flag: .warning, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, osslog: osslog)
}

public func OSSLogVerbose(_ message: @autoclosure () -> String, level: OSSDDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = true, osslog: OSSDDLog = OSSDDLog.sharedInstance) {
    _OSSLogMessage(message, level: level, flag: .verbose, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, osslog: osslog)
}

public func OSSLogError(_ message: @autoclosure () -> String, level: OSSDDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = false, osslog: OSSDDLog = OSSDDLog.sharedInstance) {
    _OSSLogMessage(message, level: level, flag: .error, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, osslog: osslog)
}

/// Returns a String of the current filename, without full path or extension.
///
/// Analogous to the C preprocessor macro `THIS_FILE`.
public func CurrentFileName(_ fileName: StaticString = #file) -> String {
    var str = String(describing: fileName)
    if let idx = str.range(of: "/", options: .backwards)?.upperBound {
        str = String(str[idx...])
    }
    if let idx = str.range(of: ".", options: .backwards)?.lowerBound {
        str = String(str[..<idx])
    }
    return str
}
