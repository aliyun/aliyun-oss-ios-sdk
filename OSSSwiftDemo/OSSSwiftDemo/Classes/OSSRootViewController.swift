//
//  OSSRootViewController.swift
//  OSSSwiftDemo
//
//  Created by huaixu on 2018/1/2.
//  Copyright © 2018年 aliyun. All rights reserved.
//

import UIKit
import AliyunOSSSwiftSDK
import AliyunOSSiOS

let ourLogLevel = OSSDDLogLevel.verbose
class OSSRootViewController: UIViewController, URLSessionDelegate, URLSessionDataDelegate, UINavigationControllerDelegate,UIImagePickerControllerDelegate {
    
    var mProvider: OSSCredentialProvider!;
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
        
        mProvider = OSSStsTokenCredentialProvider(accessKeyId: "", secretKeyId: "", securityToken: "")
        mClient = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: mProvider)
        serverURLTF.text = OSS_STSTOKEN_URL
        bucketNameTF.text = OSS_BUCKET_PRIVATE
        objectKeyTF.text = nil
    }

    @IBAction func getStsTokenButtonClicked(_ sender: UIButton) {
        getStsToken()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getStsToken() -> Void {
        let tcs = OSSTaskCompletionSource<AnyObject>()
//        let federationProvider: OSSFederationCredentialProvider = OSSFederationCredentialProvider(federationTokenGetter: {() ->OSSFederationToken? in
//            let url: URL = URL(string: OSS_STSTOKEN_URL)!
//            let config: URLSessionConfiguration = URLSessionConfiguration.default;
//            let session: URLSession = URLSession(configuration: config, delegate: self as URLSessionDelegate, delegateQueue: nil);
//
//            let task = session.dataTask(with: url, completionHandler: { (data, response, error) -> Void in
//
//                //Convert Data to Jsons
//                tcs.setResult(data as AnyObject)
//            })
//            task.resume()
//            tcs.task.waitUntilFinished()
//
//            let json = try? JSONSerialization.jsonObject(with: tcs.task.result as! Data,
//                                                         options:.allowFragments) as! [String: Any]
//            print("Json Object:", json as Any)
//
//            //verify json
//            let accessKeyId = json?["AccessKeyId"]
//            let accessKeySecret = json?["AccessKeySecret"]
//
//            self.ossAlert(title: "notice", message: json?.description)
//
//
//            let token = OSSFederationToken()
//            token.tAccessKey = accessKeyId as! String
//            token.tSecretKey = accessKeySecret as! String
//
//            return token
//        })
        
//        do {
//            try federationProvider.getToken()
//        } catch{
//            print("get Error")
//        }
    }
    
    func ossAlert(title: String?,message:String?) -> Void {
        DispatchQueue.main.async {
            let alertCtrl = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
            alertCtrl.addAction(UIAlertAction(title: "confirm", style: UIAlertActionStyle.default, handler: { (action) in
                print("\(action.title!) has been clicked");
                alertCtrl.dismiss(animated: true, completion: nil)
            }))
            self.present(alertCtrl, animated: true, completion: nil)
        }
    }
    
    func showResult(task: OSSTask<AnyObject>?) -> Void {
        if (task?.error != nil) {
            let error: NSError = (task?.error)! as NSError
            self.ossAlert(title: "error", message: error.description)
        }else
        {
            let result = task?.result
            self.ossAlert(title: "notice", message: result?.description)
        }
    }
    
    @IBAction func uploadButtonClicked(_ sender: UIButton) {
        let imagePickerCtrl = UIImagePickerController();
        imagePickerCtrl.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate;
        self.present(imagePickerCtrl, animated: true, completion: nil);
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: {
            let selectedImage = info[UIImagePickerControllerOriginalImage];
            self.putObject(image: selectedImage as! UIImage)
        })
    }
    
    func putObject(image: UIImage) -> Void {
        let request = OSSPutObjectRequest()
        request.uploadingData = UIImagePNGRepresentation(image)!
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "landscape-painting.jpeg"
        request.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
            print("bytesSent:\(bytesSent),totalBytesSent:\(totalBytesSent),totalBytesExpectedToSend:\(totalBytesExpectedToSend)");
        };
        
        let sts = OSSTestUtils.getSts()
        let provider = OSSStsTokenCredentialProvider.init(accessKeyId: sts!.tAccessKey, secretKeyId: sts!.tSecretKey, securityToken: sts!.tToken)
        let client = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
        }).waitUntilFinished()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

