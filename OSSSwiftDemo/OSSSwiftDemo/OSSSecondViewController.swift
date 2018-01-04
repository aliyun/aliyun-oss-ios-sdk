//
//  OSSSecondViewController.swift
//  OSSSwiftDemo
//
//  Created by 怀叙 on 2018/1/4.
//  Copyright © 2018年 阿里云. All rights reserved.
//

import UIKit

class OSSSecondViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
}
