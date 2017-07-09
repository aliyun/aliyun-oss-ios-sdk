//
//  ViewController.swift
//  Demo
//
//  Created by zhouzhuo on 07/02/2017.
//  Copyright © 2017 zhouzhuo. All rights reserved.
//

import UIKit
import AliyunOSSiOS

private let AccessKeyId = "<StsToken.AccessKeyId>"
private let AccessKeySecret = "<StsToken.SecretKeyId>"
private let SecurityToken = "<StsToken.SecurityToken>"
private let BucketName = "<Your BucketName>"
private let EndPoint = "https://oss-cn-hangzhou.aliyuncs.com"

class ViewController: UIViewController {

    private var oss: OSSClient!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let conf = OSSClientConfiguration()
        conf.maxRetryCount = 2
        conf.timeoutIntervalForRequest = 30
        conf.timeoutIntervalForResource = TimeInterval(24 * 60 * 60)
        conf.maxConcurrentRequestCount = 5
        
        
        let cred = OSSStsTokenCredentialProvider(accessKeyId: AccessKeyId, secretKeyId: AccessKeySecret, securityToken: SecurityToken)!
        
        self.oss = OSSClient(endpoint: EndPoint, credentialProvider: cred, clientConfiguration: conf)

        let get = OSSGetObjectRequest()
        get.bucketName = BucketName
        get.objectKey = "<fileKey>"

        let task = self.oss.getObject(get)

        task.continue({ (task) -> Any? in
            if let _err = task.error {
                print(_err)
            } else {
                if let result = task.result as? OSSGetObjectResult {
                    print("dowload success: ", result.downloadedData.count)
                }
            }
            return task
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
