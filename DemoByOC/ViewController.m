//
//  ViewController.m
//  DemoByOC
//
//  Created by jingdan on 2017/9/7.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import "ViewController.h"
#import "AliyunOSSiOS.h"
#import "GetObjcetSample.h"
static NSString* const url = @"http://30.40.11.11:9090/sts/getsts";//本地服务地址
//如何启动本地服务可参加python 目录下httpserver.py中注释说明。*.*.*.* 为本机ip地址。****为开启本机服务的端口地址
@interface ViewController ()

- (void)createButtonWithName:(NSString*)name LocationY:(CGFloat)y ClickFunc:(SEL)func Container:(UIView*) group;
- (void)initOSSClientWithAk;

@end

static OSSClient * client;
static id<OSSCredentialProvider> provider;
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
    
    [self.view addSubview:self.scrollView];
    
    [self.view addSubview:self.activityIndicatorView];
    
    //please init local sts server firstly。 please check python/*.py for more info.
    [self initOSSClientWithAk];
    
}

- (void)initOSSClientWithAk{
    [OSSLog enableLog];
    provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:url];
    
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

@end
