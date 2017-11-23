//
//  ImageService.m
//  OssIOSDemo
//  使用图片服务处理图片
//  Created by 凌琨 on 15/12/15.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/OSSService.h>
#import "OssService.h"
#import "ImageService.h"

// 字体，默认文泉驿正黑
NSString * const font = @"d3F5LXplbmhlaQ==";

@implementation ImageService
{
    OssService * imageService;
}

- (id)initImageService:(OssService *)service {
    if (self = [super init]) {
        imageService = service;
    }
    return self;
}


/**
 *    @brief    图片打水印
 *          除了大小字体之外其他都是默认值
 *    @param     object  图片名
 *    @param     text     水印文字
 *    @param     size     文字大小
 */
- (void)textWaterMark:(NSString *)object
            waterText:(NSString *)text
           objectSize:(int)size {
    NSString * base64Text = [OSSUtil calBase64WithData:(UTF8Char*)[text cStringUsingEncoding:NSASCIIStringEncoding]];
    NSString * queryString = [NSString stringWithFormat:@"@watermark=2&type=%@&text=%@&size=%d",
                              font, base64Text, size];
    NSLog(@"TextWatermark: %@", object);
    NSLog(@"Text: %@", text);
    NSLog(@"QueryString: %@", queryString);
    NSLog(@"%@%@", object, queryString);
    [imageService asyncGetImage:[NSString stringWithFormat:@"%@%@", object, queryString]];
}



/**
 *    @brief    缩放
 *
 *    @param     object     图片名
 *    @param     width     缩放宽度
 *    @param     height     缩放高度
 */
- (void)reSize:(NSString *)object
      picWidth:(int)width
     picHeight:(int)height
{
    NSString * queryString = [NSString stringWithFormat:@"@%dw_%dh_2e", width, height];
    NSLog(@"ResizeImage: %@", object);
    NSLog(@"Width: %d", width);
    NSLog(@"Height: %d", height);
    NSLog(@"QueryString: %@", queryString);
    [imageService asyncGetImage:[NSString stringWithFormat:@"%@%@", object, queryString]];
}

@end

