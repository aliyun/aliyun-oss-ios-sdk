//
//  OSSRootViewController.swift
//  OSSSwiftDemo
//
//  Created by 怀叙 on 2018/1/2.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import UIKit
import AliyunOSSSwiftSDK
import AliyunOSSiOS

let ourLogLevel = OSSDDLogLevel.verbose
class OSSRootViewController: UIViewController, URLSessionDelegate, URLSessionDataDelegate {
    
    let provider: OSSAuthCredentialProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
    var ossclient: OSSClient!
    @IBOutlet weak var testButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        我的类().打招呼(名字:"小明")
        
        OSSDDLog.removeAllLoggers();
        OSSLog.enable();
        
        defaultDebugLevel = .warning
        
        OSSLogVerbose("Verbose");
        OSSLogInfo("Info");
        OSSLogWarn("Warn");
        OSSLogError("Error");
        
        defaultDebugLevel = ourLogLevel
        
        OSSLogVerbose("Verbose");
        OSSLogInfo("Info");
        OSSLogWarn("Warn");
        OSSLogError("Error");
        
        defaultDebugLevel = .off
        
        OSSLogVerbose("Verbose", level: ourLogLevel);
        OSSLogInfo("Info", level: ourLogLevel);
        OSSLogWarn("Warn", level: ourLogLevel);
        OSSLogError("Error", level: ourLogLevel);
        
        OSSLogError("Error \(5)", level: ourLogLevel);
        
        defaultDebugLevel = .verbose
        
        let aDDLogInstance = OSSDDLog()
        aDDLogInstance.add(OSSNSLogger.sharedInstance)
        
        OSSLogVerbose("Verbose from aDDLogInstance", osslog: aDDLogInstance)
        OSSLogInfo("Info from aDDLogInstance", osslog: aDDLogInstance)
        OSSLogWarn("Warn from aDDLogInstance", osslog: aDDLogInstance)
        OSSLogError("Error from aDDLogInstance", osslog: aDDLogInstance)
        
        ossclient = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: self.provider)
    }

    @IBAction func getImageButtonClicked(_ sender: Any) {
        getImage()
    }
    @IBAction func getObjectButtonClicked(_ sender: UIButton) {
        getObject()
    }
    
    @IBAction func getStsTokenButtonClicked(_ sender: UIButton) {
        getStsToken()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getObject() -> Void {
        let getObjectReq: OSSGetObjectRequest = OSSGetObjectRequest()
        getObjectReq.bucketName = OSS_BUCKET_PUBLIC;
        getObjectReq.objectKey = "file1k";
        getObjectReq.downloadProgress = { (bytesWritten: Int64,totalBytesWritten : Int64, totalBytesExpectedToWrite: Int64) -> Void in
            print("bytesWritten:\(bytesWritten),totalBytesWritten:\(totalBytesWritten),totalBytesExpectedToWrite:\(totalBytesExpectedToWrite)");
        };
        let task: OSSTask = ossclient.getObject(getObjectReq);
        task.continue({(task: OSSTask) -> OSSTask<AnyObject>? in
            return nil;
        })
        task.waitUntilFinished()
        
        print("Error:\(String(describing: task.error))")
    }

    func getImage() -> Void {
        let getObjectReq: OSSGetObjectRequest = OSSGetObjectRequest()
        getObjectReq.bucketName = OSS_BUCKET_PUBLIC;
        getObjectReq.objectKey = OSS_IMAGE_KEY;
        getObjectReq.xOssProcess = "image/resize,m_lfit,w_100,h_100";
        getObjectReq.downloadProgress = { (bytesWritten: Int64,totalBytesWritten : Int64, totalBytesExpectedToWrite: Int64) -> Void in
            print("bytesWritten:\(bytesWritten),totalBytesWritten:\(totalBytesWritten),totalBytesExpectedToWrite:\(totalBytesExpectedToWrite)");
        };
        let task: OSSTask = ossclient.getObject(getObjectReq);
        task.continue({(task: OSSTask) -> OSSTask<AnyObject>? in
            return nil;
        })
        task.waitUntilFinished()
        
        print("Error:\(String(describing: task.error))")
    }
    
    func getStsToken() -> Void {
        let tcs = OSSTaskCompletionSource<AnyObject>()
        let federationProvider: OSSFederationCredentialProvider = OSSFederationCredentialProvider(federationTokenGetter: {() ->OSSFederationToken? in
            let url: URL = URL(string: OSS_STSTOKEN_URL)!
            let config: URLSessionConfiguration = URLSessionConfiguration.default;
            let session: URLSession = URLSession(configuration: config, delegate: self as URLSessionDelegate, delegateQueue: nil);
            
            let task = session.dataTask(with: url, completionHandler: { (data, response, error) -> Void in
                //把Data对象转换回JSON对象
                tcs.setResult(data as AnyObject)
            })
            task.resume()
            tcs.task.waitUntilFinished()
            
            let json = try? JSONSerialization.jsonObject(with: tcs.task.result as! Data,
                                                         options:.allowFragments) as! [String: Any]
            print("Json Object:", json as Any)
            //验证JSON对象可用性
            let accessKeyId = json?["AccessKeyId"]
            let accessKeySecret = json?["AccessKeySecret"]
            print("get Json Object:","accessKeyId: \(String(describing: accessKeyId)), accessKeySecret: \(String(describing: accessKeySecret))")
            
            let token = OSSFederationToken()
            token.tAccessKey = accessKeyId as! String
            token.tSecretKey = accessKeySecret as! String
            
            return token
        })
        
        do {
            try federationProvider.getToken()
        } catch{
            print("get Error")
        }
    }
}

