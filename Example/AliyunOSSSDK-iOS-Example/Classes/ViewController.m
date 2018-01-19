//
//  ViewController.m
//  OssIOSDemo
//
//  Created by jingdan on 17/11/23.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ViewController.h"
#import "ImageService.h"
#import "OSSConstants.h"
#import <AliyunOSSiOS/OSSService.h>
#import "OSSTestMacros.h"

@interface ViewController ()
{
    OssService * service;
    OssService * imageService;
    ImageService * imageOperation;
    NSString * uploadFilePath;
    int originConstraintValue;
}

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *inputViewBottom;

@property (weak, nonatomic) IBOutlet UIImageView *ossImageView;
@property (weak, nonatomic) IBOutlet UITextField *ossTextFileName;
@property (weak, nonatomic) IBOutlet UITextField *ossTextWidth;
@property (weak, nonatomic) IBOutlet UITextField *ossTextHeight;
@property (weak, nonatomic) IBOutlet UITextField *ossTextWaterMark;
@property (weak, nonatomic) IBOutlet UITextField *ossTextSize;

@property (weak, nonatomic) IBOutlet UIButton *ossButtonSelectPic;
@property (weak, nonatomic) IBOutlet UIButton *ossButtonCancel;
@property (weak, nonatomic) IBOutlet UIButton *ossButtonNormalPut;
@property (weak, nonatomic) IBOutlet UIButton *ossButtonNormalGet;
@property (weak, nonatomic) IBOutlet UIButton *ossButtonNormalCancel;
@property (weak, nonatomic) IBOutlet UIButton *ossButtonResize;
@property (weak, nonatomic) IBOutlet UIButton *ossButtonWatermark;


- (IBAction)onOssButtonSelectPic:(UIButton *)sender;
- (IBAction)onOssButtonCancel:(UIButton *)sender;
- (IBAction)onOssButtonNormalPut:(UIButton *)sender;
- (IBAction)onOssButtonNormalGet:(UIButton *)sender;
- (IBAction)onOssButtonNormalCancel:(UIButton *)sender;
- (IBAction)onOssButtonResize:(UIButton *)sender;
- (IBAction)onOssButtonWatermark:(UIButton *)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    // init ossService
    service = [[OssService alloc] initWithViewController:self withEndPoint:endPoint];
    [service setCallbackAddress:callbackAddress];
    imageService = [[OssService alloc] initWithViewController:self withEndPoint:imageEndPoint];
    imageOperation = [[ImageService alloc] initImageService:imageService];
    
    [OSSLog enableLog];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)textFieldDidBeginEditing:(UITextField *)textField {
    
    originConstraintValue = self.inputViewBottom.constant;
    self.inputViewBottom.constant -= 85;
    [UIView animateWithDuration:1 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    self.inputViewBottom.constant = originConstraintValue;
}

- (void)saveImage:(UIImage *)currentImage withName:(NSString *)imageName {
    NSData *imageData = UIImageJPEGRepresentation(currentImage, 0.5);
    NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:imageName];
    [imageData writeToFile:fullPath atomically:NO];
    uploadFilePath = fullPath;
    NSLog(@"uploadFilePath : %@", uploadFilePath);
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:^{}];
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    NSLog(@"image width:%f, height:%f", image.size.width, image.size.height);
    [self saveImage:image withName:@"currentImage"];
    [self.ossImageView setImage:image];
    self.ossImageView.tag = 100;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:^{}];
}

- (BOOL)verifyFileName {
    if (_ossTextFileName.text == nil || [_ossTextFileName.text length] == 0) {
        [self showMessage:@"填写错误" inputMessage:@"文件名不能为空！"];
        return NO;
    }
    return YES;
}

- (IBAction)onOssButtonSelectPic:(UIButton *)sender {
    
    NSString * title = @"选择";
    NSString * cancelButtonTitle = @"取消";
    NSString * picButtonTitle = @"拍照";
    NSString * photoButtonTitle = @"从相册选择";
    
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction * cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction * picAction = [UIAlertAction actionWithTitle:picButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.delegate = self;
        imagePickerController.allowsEditing = YES;
        imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:imagePickerController animated:YES completion:^{}];
    }];
    UIAlertAction * photoAction = [UIAlertAction actionWithTitle:photoButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.delegate = self;
        imagePickerController.allowsEditing = YES;
        imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:imagePickerController animated:YES completion:^{}];
    }];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [alert addAction:cancelAction];
        [alert addAction:picAction];
        [alert addAction:photoAction];
    } else {
        [alert addAction:cancelAction];
        [alert addAction:photoAction];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

// 取消上传
- (IBAction)onOssButtonCancel:(UIButton *)sender {
    _ossTextFileName.text = @"";
    uploadFilePath = @"";
    [_ossImageView setImage:nil];
}

// 普通上传
- (IBAction)onOssButtonNormalPut:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    [service asyncPutImage:objectKey localFilePath:uploadFilePath];
}

// 普通下载
- (IBAction)onOssButtonNormalGet:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    [service asyncGetImage:objectKey];
}

// 取消普通上传/下载任务
- (IBAction)onOssButtonNormalCancel:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    [service normalRequestCancel];
}

// 图片缩放
- (IBAction)onOssButtonResize:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    int width = [_ossTextWidth.text intValue];
    int height = [_ossTextHeight.text intValue];
    [imageOperation reSize:objectKey picWidth:width picHeight:height];
}

// 图片水印
- (IBAction)onOssButtonWatermark:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    NSString * waterMark = _ossTextWaterMark.text;
    int size = [_ossTextSize.text intValue];
    [imageOperation textWaterMark:objectKey waterText:waterMark objectSize:size];
}

/**
 *	@brief	下载后存储并显示图片
 *
 *	@param 	objectData 	图片数据
 *	@param 	objectKey   文件名设置为objectKey
 */
- (void)saveAndDisplayImage:(NSData *)objectData
          downloadObjectKey:(NSString *)objectKey
 {
    NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:objectKey];
    [objectData writeToFile:fullPath atomically:NO];
    UIImage * image = [[UIImage alloc] initWithData:objectData];
    uploadFilePath = fullPath;
    [self.ossImageView setImage:image];
    
}

- (void)showMessage:(NSString *)putType
       inputMessage:(NSString*)message {
    UIAlertAction * defaultAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:putType message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)customSignButtonClicked:(id)sender{
    OSSCustomSignerCredentialProvider *provider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        
        // 用户应该在此处将需要签名的字符串发送到自己的业务服务器(AK和SK都在业务服务器保存中,从业务服务器获取签名后的字符串)
        OSSFederationToken *token = [OSSFederationToken new];
        token.tAccessKey = OSS_ACCESSKEY_ID;
        token.tSecretKey = OSS_SECRETKEY_ID;
        
        NSString *signedContent = [OSSUtil sign:contentToSign withToken:token];
        return signedContent;
    }];
    
    NSError *error;
    OSSLogDebug(@"%@",[provider sign:@"abc" error:&error]);
}

@end
