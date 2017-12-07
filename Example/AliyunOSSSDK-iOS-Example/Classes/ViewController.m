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
#import "DataCallback.h"

@interface ViewController ()
{
    OssService * _service;
    OssService * _imageService;
    ImageService * _imageOperation;
    NSString * _uploadFilePath;
    int _originConstraintValue;
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
@property (weak, nonatomic) IBOutlet UIButton *ossButtonResumablePut;

- (IBAction)onOssButtonSelectPic:(UIButton *)sender;
- (IBAction)onOssButtonCancel:(UIButton *)sender;
- (IBAction)onOssButtonNormalPut:(UIButton *)sender;
- (IBAction)onOssButtonNormalGet:(UIButton *)sender;
- (IBAction)onOssButtonNormalCancel:(UIButton *)sender;
- (IBAction)onOssButtonResize:(UIButton *)sender;
- (IBAction)onOssButtonWatermark:(UIButton *)sender;
- (IBAction)onOssButtonResumablePut:(UIButton *)sender;
- (IBAction)onOssButtonResumablePutCancel:(UIButton *)sender;
- (IBAction)onOssButtonAppendPut:(UIButton *)sender;
- (IBAction)onOssButtonCreateBucket:(UIButton *)sender;
- (IBAction)onOssButtonDeleteBucket:(UIButton *)sender;
- (IBAction)onOssButtonListObjcet:(UIButton *)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.ossImageView setContentMode:UIViewContentModeScaleAspectFit];
    // init ossService
    _service = [[OssService alloc] initWithEndPoint:endPoint];
    
    [_service addObserver:self forKeyPath:@"callback" options:NSKeyValueObservingOptionNew context:nil];
    
    [_service setCallbackAddress:callbackAddress];
    _imageService = [[OssService alloc] initWithEndPoint:imageEndPoint];
    [_imageService addObserver:self forKeyPath:@"callback" options:NSKeyValueObservingOptionNew context:nil];
    _imageOperation = [[ImageService alloc] initImageService:_imageService];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)textFieldDidBeginEditing:(UITextField *)textField {
    
    _originConstraintValue = self.inputViewBottom.constant;
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
    self.inputViewBottom.constant = _originConstraintValue;
}

- (void)setButtonBorder:(UIButton *)button {
    [button.layer setMasksToBounds:YES];
    [button.layer setBorderWidth:1.0];
}

- (void)saveImage:(UIImage *)currentImage withName:(NSString *)imageName {
    NSData *imageData = UIImageJPEGRepresentation(currentImage, 0.5);
    NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:imageName];
    [imageData writeToFile:fullPath atomically:NO];
    _uploadFilePath = fullPath;
    NSLog(@"uploadFilePath : %@", _uploadFilePath);
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
    _uploadFilePath = @"";
    [_ossImageView setImage:nil];
}

// 普通上传
- (IBAction)onOssButtonNormalPut:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    
    if ([_uploadFilePath length] == 0) {
        [self showMessage:@"填写错误" inputMessage:@"上传文件不能为空！"];
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    [_service asyncPutImage:objectKey localFilePath:_uploadFilePath];
}

// 普通下载
- (IBAction)onOssButtonNormalGet:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    [_service asyncGetImage:objectKey];
}

// 取消普通上传/下载任务
- (IBAction)onOssButtonNormalCancel:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    [_service normalRequestCancel];
}

// 图片缩放
- (IBAction)onOssButtonResize:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    int width = [_ossTextWidth.text intValue];
    int height = [_ossTextHeight.text intValue];
    [_imageOperation reSize:objectKey picWidth:width picHeight:height];
}

// 图片水印
- (IBAction)onOssButtonWatermark:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    NSString * waterMark = _ossTextWaterMark.text;
    int size = [_ossTextSize.text intValue];
    [_imageOperation textWaterMark:objectKey waterText:waterMark objectSize:size];
}

// 断点续传
- (IBAction)onOssButtonResumablePut:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    if ([_uploadFilePath length] == 0) {
        [self showMessage:@"填写错误" inputMessage:@"上传文件不能为空！"];
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    [_service resumableUpload:objectKey localFilePath:_uploadFilePath];
}

// 取消断点续传
- (IBAction)onOssButtonResumablePutCancel:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    [_service normalRequestCancel];
}

// 追加上传
- (IBAction)onOssButtonAppendPut:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    if ([_uploadFilePath length] == 0) {
        [self showMessage:@"填写错误" inputMessage:@"上传文件不能为空！"];
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    [_service appendUpload:objectKey localFilePath:_uploadFilePath];
}

// 创建bucket
- (IBAction)onOssButtonCreateBucket:(UIButton *)sender {
    [_service createBucket];
}

// 删除bucket
- (IBAction)onOssButtonDeleteBucket:(UIButton *)sender {
    [_service deleteBucket];
}

// 列举object
- (IBAction)onOssButtonListObjcet:(UIButton *)sender {
    [_service listObject];
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
    NSLog(@"image width:%f, height:%f", image.size.width, image.size.height);
    _uploadFilePath = fullPath;
    [self.ossImageView setImage:image];
    
}

- (void)showMessage:(NSString *)putType
       inputMessage:(NSString*)message {
    UIAlertAction * defaultAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:putType message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if([keyPath isEqualToString:@"callback"]) {
        id result = [change objectForKey:NSKeyValueChangeNewKey];
        if ([result isKindOfClass:[DataCallback class]]) {
            DataCallback * data = result;
            [self showMessage:data.showMessage inputMessage:data.inputMessage];
            if (data.code == 1 && data.action == 1) {
                if (data.download) {
                    [self saveAndDisplayImage:data.download downloadObjectKey:data.objectKey];
                }
            }
        }
    }
}



@end
