//
//  OSSSecondViewController.swift
//  OSSSwiftDemo
//
//  Created by 怀叙 on 2018/1/4.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import UIKit
import AliyunOSSiOS
import AliyunOSSSwiftSDK

class OSSSecondViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func uploadButtonClicked(_ sender: UIButton) {
        let imagePickerCtrl = UIImagePickerController();
        imagePickerCtrl.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate;
        self.present(imagePickerCtrl, animated: true, completion: {
            print("打开了图片选择器页面")
        });
    }
    @IBAction func multipartUploadButtonClicked(_ sender: Any) {
        print("分片上传按钮被点击过！")
        multipartUpload()
    }
    @IBAction func resumableButtonClicked(_ sender: Any) {
        print("断点续传按钮被点击过！")
        resumableUpload()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    deinit {
        print("OSSSecondViewController 销毁！")
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: {
            print("图片选择控制器销毁啦！")
            if #available(iOS 11.0, *) {
                let selectedImageURL = info[UIImagePickerControllerImageURL]
                self.putObject(fileURL: selectedImageURL as! URL)
            } else {
                // Fallback on earlier versions
            }
        })
    }
    
    func putObject(fileURL: URL) -> Void {
        let request = OSSPutObjectRequest()
        request.uploadingFileURL = fileURL
        request.bucketName = OSS_BUCKET_PRIVATE
        request.objectKey = "landscape-painting.jpeg"
        request.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
            print("bytesSent:\(bytesSent),totalBytesSent:\(totalBytesSent),totalBytesExpectedToSend:\(totalBytesExpectedToSend)");
        };
        
        let provider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        let task = client.putObject(request)
        task.continue({ (t) -> Any? in
            print("Error: \(String(describing: t.error))")
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
            print("Error: \(String(describing: t.error))")
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
        
        let provider = OSSAuthCredentialProvider(authServerUrl: OSS_STSTOKEN_URL)
        let client = OSSClient(endpoint: OSS_ENDPOINT, credentialProvider: provider)
        var task = client.resumableUpload(request)
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
        
        task = client.resumableUpload(request)
        task.continue({ (t) -> Any? in
            print("Error: \(String(describing: t.error))")
        }).waitUntilFinished()
    }
}
