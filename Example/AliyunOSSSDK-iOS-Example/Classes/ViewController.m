//
//  ViewController.m
//  OssIOSDemo
//
//  Created by jingdan on 17/11/23.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ViewController.h"
#import <AliyunOSSiOS/OSSService.h>
#import "OSSTestMacros.h"
#import "DownloadService.h"
#import "OSSWrapper.h"

@interface ViewController ()
{
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
@property (weak, nonatomic) IBOutlet UILabel *progressLab;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UIButton *downloadButton;
@property (weak, nonatomic) IBOutlet UIButton *uploadBigFileButton;

@property (nonatomic, strong) DownloadRequest *downloadRequest;
@property (nonatomic, strong) OSSClient *mClient;
@property (nonatomic, copy) Checkpoint *checkpoint;
@property (nonatomic, copy) NSString *downloadURLString;
@property (nonatomic, copy) NSString *headURLString;
@property (nonatomic, strong) DownloadService *downloadService;
@property (nonatomic, strong) OSSWrapper *oss;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [OSSLog enableLog];     // 开启sdk的日志功能
    
    
    [_uploadBigFileButton addTarget:self action:@selector(uploadBigFileClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self setupOSS];
    [self initDownloadURLs];
    self.progressBar.progress = 0;
}

- (void)setupOSS {
    _oss = [[OSSWrapper alloc] init];
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
        [self showMessage:@"error" inputMessage:@"The file name cannot be empty!"];
        return NO;
    }
    return YES;
}

- (IBAction)onOssButtonSelectPic:(UIButton *)sender {
    
    NSString * title = @"select";
    NSString * cancelButtonTitle = @"cancel";
    NSString * picButtonTitle = @"take pictures";
    NSString * photoButtonTitle = @"select from the album";
    
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
    
    NSString *funcStr = @"upload";
    NSString * objectKey = _ossTextFileName.text;
    [self.oss asyncPutImage:objectKey localFilePath:uploadFilePath success:^(id result) {
        [self showMessage:funcStr inputMessage:@"success"];
    } failure:^(NSError *error) {
        [self showMessage:funcStr inputMessage:error.localizedDescription];
    }];
}

// 普通下载
- (IBAction)onOssButtonNormalGet:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    
    NSString *funcStr = @"download";
    NSString * objectKey = _ossTextFileName.text;
    [self.oss asyncGetImage:objectKey success:^(id result) {
        [self showMessage:funcStr inputMessage:@"success"];
    } failure:^(NSError *error) {
        [self showMessage:funcStr inputMessage:error.localizedDescription];
    }];
}

// 取消普通上传/下载任务
- (IBAction)onOssButtonNormalCancel:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    [self.oss normalRequestCancel];
}

// 图片缩放
- (IBAction)onOssButtonResize:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    int width = [_ossTextWidth.text intValue];
    int height = [_ossTextHeight.text intValue];
    
    NSString *funcStr = @"picture zoom";
    [self.oss reSize:objectKey picWidth:width picHeight:height success:^(id result) {
        [self showMessage:funcStr inputMessage:@"success!"];
        NSString *filePath = (NSString *)result;
        self.ossImageView.image = [[UIImage alloc] initWithContentsOfFile:filePath];
    } failure:^(NSError *error) {
        [self showMessage:funcStr inputMessage:error.localizedDescription];
    }];
}

// 图片水印
- (IBAction)onOssButtonWatermark:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _ossTextFileName.text;
    NSString * waterMark = _ossTextWaterMark.text;
    int size = [_ossTextSize.text intValue];
    
    NSString *funcStr = @"image watermark";
    [self.oss textWaterMark:objectKey waterText:waterMark objectSize:size success:^(id result) {
        [self showMessage:funcStr inputMessage:@"success!"];
        NSString *filePath = (NSString *)result;
        self.ossImageView.image = [[UIImage alloc] initWithContentsOfFile:filePath];
    } failure:^(NSError *error) {
        [self showMessage:funcStr inputMessage:error.localizedDescription];
    }];
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
    UIAlertAction * defaultAction = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:nil];
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

- (IBAction)triggerCallbackClicked:(id)sender {
    NSString *funcStr = @"upload callbacl";
    
    [self.oss triggerCallbackWithObjectKey:_ossTextFileName.text success:^(id result) {
        [self showMessage:funcStr inputMessage:@"success"];
    } failure:^(NSError *error) {
        [self showMessage:funcStr inputMessage:error.localizedDescription];
    }];
}

- (void)uploadBigFileClicked:(id)sender {
    NSString *funcStr = @"large file upload";
    
    [self.oss multipartUploadWithSuccess:^(id result) {
        [self showMessage:funcStr inputMessage:@"success"];
    } failure:^(NSError *error) {
        [self showMessage:funcStr inputMessage:error.localizedDescription];
    }];
}

- (void)initDownloadURLs {
    OSSPlainTextAKSKPairCredentialProvider *pCredential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    _mClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:pCredential];
    OSSTask *downloadURLTask = [_mClient presignConstrainURLWithBucketName:@"aliyun-dhc-shanghai" withObjectKey:OSS_DOWNLOAD_FILE_NAME withExpirationInterval:1800];
    _downloadURLString = downloadURLTask.result;
    
    OSSTask *headURLTask = [_mClient presignConstrainURLWithBucketName:@"aliyun-dhc-shanghai" withObjectKey:OSS_DOWNLOAD_FILE_NAME httpMethod:@"HEAD" withExpirationInterval:1800 withParameters:nil];
    
    _headURLString = headURLTask.result;
}

- (IBAction)resumeDownloadClicked:(id)sender {
    _downloadRequest = [DownloadRequest new];
    _downloadRequest.sourceURLString = _downloadURLString;       // 设置资源的url
    _downloadRequest.headURLString = _headURLString;
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    _downloadRequest.downloadFilePath = [documentPath stringByAppendingPathComponent:OSS_DOWNLOAD_FILE_NAME];   //设置下载文件的本地保存路径
    
    __weak typeof(self) wSelf = self;
    _downloadRequest.downloadProgress = ^(int64_t bytesReceived, int64_t totalBytesReceived, int64_t totalBytesExpectToReceived) {
        // totalBytesReceived是当前客户端已经缓存了的字节数,totalBytesExpectToReceived是总共需要下载的字节数。
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) sSelf = wSelf;
            CGFloat fProgress = totalBytesReceived * 1.f / totalBytesExpectToReceived;
            sSelf.progressLab.text = [NSString stringWithFormat:@"%.2f%%", fProgress * 100];
            sSelf.progressBar.progress = fProgress;
        });
    };
    _downloadRequest.failure = ^(NSError *error) {
        __strong typeof(self) sSelf = wSelf;
        sSelf.checkpoint = error.userInfo[@"checkpoint"];
    };
    _downloadRequest.success = ^(NSDictionary *result) {
        NSLog(@"download successful");
    };
    _downloadRequest.checkpoint = self.checkpoint;
    
    NSString *titleText = [[_downloadButton titleLabel] text];
    if ([titleText isEqualToString:@"download"]) {
        [_downloadButton setTitle:@"pause" forState: UIControlStateNormal];
        _downloadService = [DownloadService downloadServiceWithRequest:_downloadRequest];
        [_downloadService resume];
    } else {
        [_downloadButton setTitle:@"download" forState: UIControlStateNormal];
        [_downloadService pause];
    }
}

- (IBAction)cancelDownloadClicked:(id)sender {
    [_downloadButton setTitle:@"download" forState: UIControlStateNormal];
    [_downloadService cancel];
}

@end
