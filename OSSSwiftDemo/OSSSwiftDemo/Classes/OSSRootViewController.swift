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
    
    var mProvider: OSSAuthCredentialProvider!;
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
        
        mProvider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        mClient = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: mProvider)
        serverURLTF.text = OSS_STSTOKEN_URL
        bucketNameTF.text = OSS_BUCKET_PUBLIC
        objectKeyTF.text = nil
    }
    
    @IBAction func getImageButtonClicked(_ sender: Any) {
        if (objectKeyTF.text?.isEmpty)! {
            ossAlert(title: "error", message: "Please input object name!")
            return;
        }
        if (bucketNameTF.text?.isEmpty)! {
            ossAlert(title: "error", message: "Please input bucket name!")
            return;
        }
        getImage()
    }
    @IBAction func getObjectButtonClicked(_ sender: UIButton) {
        if (objectKeyTF.text?.isEmpty)! {
            ossAlert(title: "error", message: "Please input object name!")
            return;
        }
        if (bucketNameTF.text?.isEmpty)! {
            ossAlert(title: "error", message: "Please input bucket name!")
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
            ossAlert(title: "error", message: "Please input object name!")
            return;
        }
        if (bucketNameTF.text?.isEmpty)! {
            ossAlert(title: "error", message: "Please input bucket name!")
            return;
        }
        headObject()
    }
    @IBAction func sequentialUpload(_ sender: Any) {
        sequentialMultipartUpload()
    }
    @IBAction func deleteMultipleObjectsClicked(_ sender: Any) {
        deleteMultipleObjects()
    }
    @IBAction func triggerCallbackClicked(_ sender: Any) {
        triggerCallBack()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func getObjectACLButtonClicked(_ sender: Any) {
        getObjectACL()
    }
    
    func getObject() -> Void {
        let getObjectReq: OSSGetObjectRequest = OSSGetObjectRequest()
        getObjectReq.bucketName = OSS_BUCKET_PUBLIC;
        getObjectReq.objectKey = OSS_IMAGE_KEY;
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
                
                //Convert Data to Jsons
                tcs.setResult(data as AnyObject)
            })
            task.resume()
            tcs.task.waitUntilFinished()
            
            let json = try? JSONSerialization.jsonObject(with: tcs.task.result as! Data,
                                                         options:.allowFragments) as! [String: Any]
            print("Json Object:", json as Any)
            
            //verify json
            let accessKeyId = json?["AccessKeyId"]
            let accessKeySecret = json?["AccessKeySecret"]
            
            self.ossAlert(title: "notice", message: json?.description)
            
            
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
        alertCtrl.addAction(UIAlertAction(title: "confirm", style: UIAlertActionStyle.default, handler: { (action) in
            print("\(action.title!) has been clicked");
            alertCtrl.dismiss(animated: true, completion: nil)
        }))
        
        DispatchQueue.main.async {
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
    
    @IBAction func uploadButtonClicked(_ sender: UIButton) {
        let imagePickerCtrl = UIImagePickerController();
        imagePickerCtrl.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate;
        self.present(imagePickerCtrl, animated: true, completion: nil);
    }
    @IBAction func multipartUploadButtonClicked(_ sender: Any) {
        multipartUpload()
    }
    @IBAction func resumableButtonClicked(_ sender: Any) {
        resumableUpload()
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
        
        let provider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
        }).waitUntilFinished()
    }
    
    func multipartUpload() -> Void {
        let request = OSSMultipartUploadRequest()
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "wangwang(swift).zip"
        request.partSize = 102400;
        request.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
            print("bytesSent:\(bytesSent),totalBytesSent:\(totalBytesSent),totalBytesExpectedToSend:\(totalBytesExpectedToSend)");
        };
        
        let provider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = client.multipartUpload(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
        }).waitUntilFinished()
    }
    
    func resumableUpload() -> Void {
        var request = OSSResumableUploadRequest()
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.bucketName = OSS_BUCKET_PRIVATE
        request.deleteUploadIdOnCancelling = false;
        request.objectKey = "wangwang(swift).zip"
        let cacheDir =  NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
        request.recordDirectoryPath = cacheDir!
        request.partSize = 102400;
        request.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
            print("bytesSent:\(bytesSent),totalBytesSent:\(totalBytesSent),totalBytesExpectedToSend:\(totalBytesExpectedToSend)");
            if totalBytesSent > (totalBytesExpectedToSend / 2) {
                request.cancel()
            }
        }
        
        var task = mClient.resumableUpload(request)
        task.continue({ (t) -> Any? in
            print("Error: \(String(describing: t.error))")
            return nil
        }).waitUntilFinished()
        
        request = OSSResumableUploadRequest()
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "wangwang(swift).zip"
        request.partSize = 102400;
        request.deleteUploadIdOnCancelling = false;
        request.recordDirectoryPath = cacheDir!
        request.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
            print("bytesSent:\(bytesSent),totalBytesSent:\(totalBytesSent),totalBytesExpectedToSend:\(totalBytesExpectedToSend)");
        }
        
        task = mClient.resumableUpload(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
            return nil
        }).waitUntilFinished()
    }
    
    func sequentialMultipartUpload() {
        let request = OSSResumableUploadRequest()
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = "sequential-swift-multipart";
        request.uploadingFileURL = Bundle.main.url(forResource: "wangwang", withExtension: "zip")!
        request.deleteUploadIdOnCancelling = false
        request.crcFlag = OSSRequestCRCFlag.open
        let filePath = Bundle.main.path(forResource: "wangwang", ofType: "zip")
        request.contentSHA1 = OSSUtil.sha1(withFilePath: filePath)
        
        let task = mClient.sequentialMultipartUpload(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
            
            return nil
        }).waitUntilFinished()
    }
    
    @IBAction func putObjectWithSHA1(_ sender: Any) {
        let request = OSSPutObjectRequest()
        request.uploadingFileURL = Bundle.main.url(forResource: "test", withExtension: "xml")!
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "test.xml"
        request.contentSHA1 = OSSUtil.sha1(withFilePath: Bundle.main.path(forResource: "test", ofType: "xml"))
        
        request.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
            print("bytesSent:\(bytesSent),totalBytesSent:\(totalBytesSent),totalBytesExpectedToSend:\(totalBytesExpectedToSend)");
        };
        
        let task = mClient.putObject(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
        }).waitUntilFinished()
    }
    
    func getObjectACL() {
        let request = OSSGetObjectACLRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectName = OSS_IMAGE_KEY
        
        let task = mClient.getObjectACL(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
            
            return nil
        }).waitUntilFinished()
    }
    
    func deleteMultipleObjects() {
        let request = OSSDeleteMultipleObjectsRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.keys = ["testFor5m"]
        request.quiet = false
        request.encodingType = "url"
        
        let task = mClient.deleteMultipleObjects(request)
        task.continue({ (t) -> Any? in
            self.showResult(task: t)
            
            return nil
        }).waitUntilFinished()
    }

    func triggerCallBack() {
        let provider = OSSPlainTextAKSKPairCredentialProvider.init(plainTextAccessKey: "AK", secretKey: "SK")
        let pClient = OSSClient.init(endpoint: OSS_ENDPOINT, credentialProvider: provider);
        
        let request = OSSCallBackRequest()
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectName = "file1m"
        request.callbackVar = ["key1": "value1",
                               "key2": "value2"]
        request.callbackParam = ["callbackUrl": OSS_CALLBACK_URL,
                                "callbackBody": "test"]
        
        let task = pClient.triggerCallBack(request)
        task.continue({ (t) -> Any? in
            if (t.result != nil) {
                let result = t.result as! OSSCallBackResult;
                self .ossAlert(title: "提示", message: result.serverReturnJsonString);
            }
            
            return nil
        }).waitUntilFinished()
    }
}

