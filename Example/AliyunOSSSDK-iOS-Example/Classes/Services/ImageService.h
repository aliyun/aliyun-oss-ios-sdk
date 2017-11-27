//
//  ImageService.h
//  OssIOSDemo
//  使用图片服务处理图片
//  Created by jingdan on 17/11/23.
//  Copyright © 2015年 Ali. All rights reserved.
//
#ifndef ImageService_h
#define ImageService_h
#import <Foundation/Foundation.h>
#import "OssService.h"
@interface ImageService: NSObject

- (id)initImageService:(OssService *)service;

/**
 *    @brief    图片打水印下载
 *
 *    @param     object  图片名
 *    @param     text     水印文字
 *    @param     size     文字大小
 */
- (void)textWaterMark:(NSString *)object
            waterText:(NSString *)text
           objectSize:(int)size;

/**
 *    @brief    图片缩放下载
 *
 *    @param     object     图片名
 *    @param     width     缩放宽度
 *    @param     height     缩放高度
 */
- (void)reSize:(NSString *) object
      picWidth:(int) width
     picHeight:(int) height;

@end

#endif /* ImageService_h */

