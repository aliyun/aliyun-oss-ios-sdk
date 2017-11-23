//
//  RootViewController.h
//  AliyunOSSSDK-Example
//
//  Created by 凌琨 on 15/12/15.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RootViewController : UIViewController

- (void)showMessage:(NSString*)putType
       inputMessage:(NSString*)message;

- (void)saveAndDisplayImage:(NSData *)objectData
          downloadObjectKey:(NSString *)objectKey;

@end

