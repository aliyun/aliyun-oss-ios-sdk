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
    @IBOutlet weak var objectKeyTF: UITextField!
    @IBOutlet weak var serverURLTF: UITextField!
    @IBOutlet weak var bucketNameTF: UITextField!
    var mClient: OSSClient!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
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
        
        mClient = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: self.provider)
        serverURLTF.text = OSS_STSTOKEN_URL
        bucketNameTF.text = OSS_BUCKET_PUBLIC
        objectKeyTF.text = nil
    }
    
    @IBAction func getImageButtonClicked(_ sender: Any) {
        if (objectKeyTF.text?.isEmpty)! {
            ossAlert(title: "错误", message: "请输入Object名称之后重试!")
            return;
        }
        if (bucketNameTF.text?.isEmpty)! {
            ossAlert(title: "错误", message: "请输入BUCKET名称之后重试!")
            return;
        }
        getImage()
    }
    @IBAction func getObjectButtonClicked(_ sender: UIButton) {
        if (objectKeyTF.text?.isEmpty)! {
            ossAlert(title: "错误", message: "请输入Object名称之后重试!")
            return;
        }
        if (bucketNameTF.text?.isEmpty)! {
            ossAlert(title: "错误", message: "请输入BUCKET名称之后重试!")
            return;
        }
        getObject()
    }
    @IBAction func getBucketButtonClicked(_ sender: Any) {
        getBucket()
    }
    
    @IBAction func getBucketACLButtonClicked(_ sender: Any) {
        getBucketACL()
    }
    @IBAction func createButtonClicked(_ sender: Any) {
        createBucket()
    }
    @IBAction func deleteBucketButtonClicked(_ sender: UIButton) {
        deleteBucket()
    }
    @IBAction func getStsTokenButtonClicked(_ sender: UIButton) {
        getStsToken()
    }
    @IBAction func headObjectButtonClicked(_ sender: Any) {
        if (objectKeyTF.text?.isEmpty)! {
            ossAlert(title: "错误", message: "请输入Object名称之后重试!")
            return;
        }
        if (bucketNameTF.text?.isEmpty)! {
            ossAlert(title: "错误", message: "请输入BUCKET名称之后重试!")
            return;
        }
        headObject()
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
        let task: OSSTask = mClient.getObject(getObjectReq);
        task.continue({(t) -> OSSTask<AnyObject>? in
            self.showResult(task: t)
            return nil
        })
        task.waitUntilFinished()
        
        print("Error:\(String(describing: task.error))")
    }

    func getImage() -> Void {
        let getObjectReq: OSSGetObjectRequest = OSSGetObjectRequest()
        getObjectReq.bucketName = OSS_BUCKET_PUBLIC;
        getObjectReq.objectKey = objectKeyTF.text!;
        getObjectReq.xOssProcess = "image/resize,m_lfit,w_100,h_100";
        getObjectReq.downloadProgress = { (bytesWritten: Int64,totalBytesWritten : Int64, totalBytesExpectedToWrite: Int64) -> Void in
            print("bytesWritten:\(bytesWritten),totalBytesWritten:\(totalBytesWritten),totalBytesExpectedToWrite:\(totalBytesExpectedToWrite)");
        };
        let task: OSSTask = mClient.getObject(getObjectReq);
        task.continue({(t) -> OSSTask<AnyObject>? in
            self.showResult(task: t)
            return nil
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
            
            self.ossAlert(title: "提示", message: json?.description)
            
            
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
    func headObject() -> Void {
        if (objectKeyTF.text?.isEmpty)! {
            ossAlert(title: nil, message: "objectKey can not be empty!")
        }
        
        let request = OSSHeadObjectRequest()
        request.bucketName = OSS_BUCKET_PUBLIC
        request.objectKey = objectKeyTF.text!
    
        let task: OSSTask = mClient.headObject(request)
        task.continue({(task) -> OSSTask<AnyObject>? in
            self.showResult(task: task)
            return nil
        })
        task.waitUntilFinished()
    }
    
    func ossAlert(title: String?,message:String?) -> Void {
        let alertCtrl = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alertCtrl.addAction(UIAlertAction(title: "确定", style: UIAlertActionStyle.default, handler: { (action) in
            print("\(action.title!) has been clicked");
            alertCtrl.dismiss(animated: true, completion: nil)
        }))
        
        DispatchQueue.main.async {
            self.present(alertCtrl, animated: true, completion: nil)
        }
    }
    
    func showResult(task: OSSTask<AnyObject>?) -> Void {
        if (task?.error != nil) {
            self.ossAlert(title: "错误", message: task?.error?.localizedDescription)
        }else
        {
            let result = task?.result
            self.ossAlert(title: "提示", message: result?.description)
        }
    }
    
    func getBucket() -> Void {
        let request = OSSGetBucketRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        
        let task = mClient.getBucket(request)
        task.continue( { (t) -> Any? in
            if let result = t.result as? OSSGetBucketResult {
                self.showResult(task: OSSTask(result: result.contents as AnyObject))
            }else
            {
                self.showResult(task: t)
            }
            return nil
        })
    }
    
    func getBucketACL() -> Void {
        let request = OSSGetBucketACLRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        
        let task = mClient.getBucketACL(request)
        task.continue( { (t) -> Any? in
            if let result = t.result as? OSSGetBucketACLResult {
                self.showResult(task: OSSTask(result: result.aclGranted as AnyObject))
            }else
            {
                self.showResult(task: t)
            }
            return nil
        })
    }
    
    func createBucket() -> Void {
        let request = OSSCreateBucketRequest()
        request.bucketName = "com-dhc-test"
        
        let task = mClient.createBucket(request)
        task.continue( { (t) -> Any? in
            self.showResult(task: t)
            return nil
        })
    }
    
    func deleteBucket() -> Void {
        let request = OSSDeleteBucketRequest()
        request.bucketName = "com-dhc-test"
        
        let task = mClient.deleteBucket(request)
        task.continue( { (t) -> Any? in
            self.showResult(task: t)
            return nil
        })
    }
}

