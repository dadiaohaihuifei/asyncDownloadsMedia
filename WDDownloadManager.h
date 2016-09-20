//
//  WDDownloadManager.h
//  MediaSyncDownloader
//
//  Created by MrWu on 16/9/13.
//  Copyright © 2016年 TTYL. All rights reserved.
//

#import <Foundation/Foundation.h>
//判断AFN导入方法
#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

NS_ASSUME_NONNULL_BEGIN                                 //压栈-区域中属性方法为nonull
FOUNDATION_EXPORT NSString * const WDDownloadCachesFolderName;

/** 下载状态 */
typedef NS_ENUM(NSUInteger,WDDownloaderState) {
    WDDownloadStateNone,                                //默认
    WDDownloadStateWillResume,                              //等待
    WDDownloadStateDownloading,                         //下载
    WDDownloadStateSuspended,                           //暂停
    WDDownloadStateCompeleted,                          //完成
    WDDownloadStateFailed                               //失败
};
/** 下载优先级 */
typedef NS_ENUM(NSUInteger,WDDownloaderPrioritization) {
    WDDownloaderPrioritizationFIFO,                     //先进先出
    WDDownloaderPrioritizationLIFO                      //后进先出
};

#pragma mark 接收器
@interface WDDownloadReceipt : NSObject <NSCoding>
/** 下载状态 */
@property (nonatomic, assign, readonly) WDDownloaderState state;
/** 下载URL地址 */
@property (nonatomic, copy, readonly) NSString *url;
/** 文件下载路径 */
@property (nonatomic, copy, readonly) NSString *filePath;
/** 文件名 */
@property (nonatomic, copy, readonly, nullable) NSString *fileName;
/** 当前写入文件大小 */
@property (nonatomic, assign, readonly) long long totalBytesWriten;
/** 文件总共大小 */
@property (nonatomic, assign, readonly) long long totalBytesExpectedToWrite;
/** 下载进度 */
@property (nonatomic, copy, readonly) NSProgress *progress;
/** 出现错误 */
@property (nonatomic, strong, readonly) NSError *error;
@end

@protocol WDDownloadControlDelegate <NSObject>
/** 根据URL取消任务 */
- (void)resumeWithUrl:(NSString * _Nonnull)url;
/** 根据接收器取消任务 */
- (void)resumeWithDownloadReceipt:(WDDownloadReceipt * _Nonnull)receipt;

/** 根据URL暂停任务 */
- (void)suspendWithUrl:(NSString * _Nonnull)url;
/** 根据接收器暂停任务 */
- (void)suspendWithReceipt:(WDDownloadReceipt * _Nonnull)receipt;

/** URL移除任务 */
- (void)removeWithUrl:(NSString * _Nonnull)url;
/** 接收器移除任务 */
- (void)removeWithReceipt:(WDDownloadReceipt * _Nonnull)receipt;
@end

typedef void (^successBlock)(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSURL *filePath);
typedef void (^failureBlock)(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSError *error);
typedef void (^progressBlock)(NSProgress *progress,WDDownloadReceipt *receipt);

#pragma mark 下载器
@interface WDDownloadManager : NSObject <WDDownloadControlDelegate>
/**
 *  定义下载顺序 默认FIFO
 */
@property (nonatomic, assign) WDDownloaderPrioritization prioritization;
/** 实例方法 */
+ (instancetype)defautInstance;
/** 实例方法 */
- (instancetype)init;
/** 
    实例方法
    实例所在队列
    实例优先级
    实例并发数量 推荐『4』个
 */
- (instancetype)initWithSession:(NSURLSession *)session
         downloadPrioritization:(WDDownloaderPrioritization)prioritization
         maxmumActiveDownloader:(NSInteger)maxmumActivedownloader;
/** 
    根据Request创建接收器
    request的URL
    目的地一块对象执行为了确定下载文件的目的地。这个街区有两个参数,目标路径&服务器响应并返回所需的文件的URL生成的下载。在使用的临时文件下载后将会自动删除移动到返回的URL。
    如果是使用背景的NSURLSessionConfiguration iOS,这些块程序终止时将丢失。背景会话可能更喜欢用“-setDownloadTaskDidFinishDownloadingBlock:”指定保存下载文件的URL,而不是目标块的方法。
 */
- (WDDownloadReceipt *)downLoadFileWithUrl:(NSString * _Nullable)url
                                  progress:(progressBlock)downloadProgressBlock
                               destination:(nullable NSURL *(^)(NSURL *targetPath,NSURLResponse *response))destination
                                   success:(successBlock)success
                                   failure:(failureBlock)failure;

- (WDDownloadReceipt * _Nullable)downloadReceiptForUrl:(NSString *)url;
@end
NS_ASSUME_NONNULL_END
