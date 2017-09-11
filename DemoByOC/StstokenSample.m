//
//  StstokenSample.m
//  AliyunOSSiOS
//

#import "StstokenSample.h"

@interface StstokenSample ()


@end


@implementation StstokenSample

const NSString* url = @"http://xx.xx.xx.xx:12555/sts/getsts";//本地服务器 可以通过提供的server进行启动


- (void)getStsToken:(void (^)(NSDictionary *))block{
    NSString *urlStr = [NSString stringWithFormat:@"%@",url];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *requst = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *getStsTask = [session dataTaskWithRequest:requst completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"从服务器获取到数据");
        /*
         对从服务器获取到的数据data进行相应的处理：
         */
        if(data != nil){
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingMutableLeaves) error:nil];
            
            NSLog(@"数据解析完成");
            dispatch_async(dispatch_get_main_queue(), ^{
                block(dict[@"Credentials"]);
            });
        }else{
            //处理失败情况，自行处理
        }
        
    }];
    //执行任务（resume也是继续执行）:
    [getStsTask resume];
}

@end
