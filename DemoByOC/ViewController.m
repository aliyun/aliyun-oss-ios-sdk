//
//  ViewController.m
//  DemoByOC
//
//  Created by jingdan on 2017/9/7.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import "ViewController.h"
#import "OSSClient.h"
#import "OSSModel.h"
#import "OSSLog.h"
#import "GetObjcetSample.h"
#import "StstokenSample.h"

@interface ViewController ()

- (void)createButtonWithName:(NSString*)name LocationY:(CGFloat)y ClickFunc:(SEL)func Container:(UIView*) group;
- (void)initOSSClientWithAk:(NSString*)ak Sk:(NSString*)sk Token:(NSString*)token;

@end

static OSSClient * client;
static OSSStsTokenCredentialProvider * provider;
NSString* const ENDPOINT = @"http://oss-cn-hangzhou.aliyuncs.com";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"viewDidLoad");
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.width = [[UIScreen mainScreen] bounds].size.width;
    self.height = [[UIScreen mainScreen] bounds].size.height;
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.width, self.height)];
    
    self.activityIndicatorView=[[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(0, 0, 30, 30)];
    self.activityIndicatorView.center=self.view.center;
    [self.activityIndicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
    [self.activityIndicatorView setBackgroundColor:[UIColor lightGrayColor]];
    
    [self createButtonWithName:@"get_object" LocationY:50 ClickFunc:@selector(getObject:) Container:self.scrollView];
    [self createButtonWithName:@"sts_token" LocationY:90 ClickFunc:@selector(getStsToken:) Container:self.scrollView];
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(20, 130, self.width-20, 300)];
    self.textView.editable = NO;
    
    [self.scrollView addSubview:self.textView];
    
    [self.view addSubview:self.scrollView];
    
    [self.view addSubview:self.activityIndicatorView];
}

- (void)initOSSClientWithAk:(NSString *)ak Sk:(NSString *)sk Token:(NSString *)token{
    [OSSLog enableLog];
    provider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:ak secretKeyId:sk securityToken:token];
    
    OSSClientConfiguration * conf = [[OSSClientConfiguration alloc] init];
    conf.maxRetryCount = 2;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    conf.maxConcurrentRequestCount = 5;
    
    // 更换不同的credentialProvider测试
    client = [[OSSClient alloc] initWithEndpoint:ENDPOINT credentialProvider:provider clientConfiguration:conf];
}

- (void)createButtonWithName:(NSString*)name LocationY:(CGFloat)y ClickFunc:(SEL)func Container:(UIView *)group{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.clipsToBounds = YES;
    btn.layer.cornerRadius = 5;
    [btn setFrame:CGRectMake(20, y, 80, 30)];
    [btn addTarget:self action:func forControlEvents:UIControlEventTouchUpInside];
    [btn setTitle:name forState:UIControlStateNormal];
    [btn.layer setBorderColor:[UIColor blueColor].CGColor];
    [btn.layer setBorderWidth:0.5];
    [btn.layer setMasksToBounds:YES];
    [group addSubview:btn];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    NSLog(@"viewDidAppear");
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)getObject:(id)sender{
     NSLog(@"getObject");
    [self.activityIndicatorView startAnimating];
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(getObjectRun) object:nil];
    [thread start];
}

- (void)getObjectRun{
    [[[GetObjcetSample alloc] initWithOSSClient:client] getObject:^(NSData *data){
        [self.activityIndicatorView stopAnimating];
        if(data != nil){
            NSLog(@"success");
        }else{
            NSLog(@"fail");
        }
    }];
}



- (void)getStsToken:(id)sender{
    [self.activityIndicatorView startAnimating];
    [[[StstokenSample alloc] init] getStsToken:^(NSDictionary *dict){
        
        if(provider == nil || client == nil){
            [self initOSSClientWithAk:dict[@"AccessKeyId"] Sk:dict[@"AccessKeySecret"] Token:dict[@"SecurityToken"]];
        }else{
            //给provider设置
            [provider setAccessKeyId:dict[@"AccessKeyId"]];
            [provider setSecretKeyId:dict[@"AccessKeySecret"]];
            [provider setSecurityToken:dict[@"SecurityToken"]];
        }
        
        
        //以下内容只是用于展示事例
        NSMutableString *string = [[NSMutableString alloc] init];
        for (id key in dict){//只是打印下日志
            NSLog(@"%@：%@", key,dict[key]);
            [string appendString:[NSString stringWithFormat:@"%@：%@\n\n", key,dict[key]]];
        }
        [self.activityIndicatorView stopAnimating];
        [self.textView setText:string];
    }];
}


@end
