//
//  WDDownloadManager.m
//  MediaSyncDownloader
//
//  Created by MrWu on 16/9/13.
//  Copyright © 2016年 TTYL. All rights reserved.
//

#import "WDDownloadManager.h"
#import <CommonCrypto/CommonDigest.h>

/** 缓存文件夹 */
NSString * const WDDownloadCachesFolderName = @"cacheFolderName";

#pragma mark - 代码块
/** 创建缓存文件夹 */
static NSString * cacheFolder () {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    static dispatch_once_t onceToken;
    static NSString *cacheFolder;
    dispatch_once(&onceToken, ^{
        NSString *cache = NSHomeDirectory();
        cacheFolder = [cache stringByAppendingPathComponent:WDDownloadCachesFolderName];
    });
    NSError *error;
    if (![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:@{} error:&error]) {
        NSLog(@"failed create folder at path: %@ ,error: %@",cacheFolder, error);
        cacheFolder = nil;
    }
    return cacheFolder;
}
/** 创建receipt路径 */
static NSString *LocalReceiptsPath () {
    return [cacheFolder() stringByAppendingPathComponent:@"receipts.data"];
}
/** 检查文件大小 */
static unsigned long long fileSizeForPath (NSString * path) {
    unsigned long long fileSize = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error;
        NSDictionary *fileAttr = [fileManager attributesOfItemAtPath:path error:&error];
        //@try
        if (!error && fileAttr) {
            fileSize = [fileAttr fileSize];
        }else {
            NSLog(@"fileSize error: %@",error);
        }
    }
    return fileSize;
}
/** 获得MD5字符串 */
static NSString *getMD5String (NSString *str) {
    if (str == nil) { return nil; }
    const char *cstring = str.UTF8String;
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstring, (CC_LONG)strlen(cstring), bytes);
    NSMutableString *md5String = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [md5String appendFormat:@"%02x",bytes[i]];
    }
    return md5String;
}
#pragma mark - 接收器
@interface WDDownloadReceipt ()
/** 下载状态 */
@property (nonatomic, assign) WDDownloaderState state;
/** 下载URL地址 */
@property (nonatomic, copy) NSString *url;
/** 文件下载路径 */
@property (nonatomic, copy) NSString *filePath;
/** 文件名 */
@property (nonatomic, copy, nullable) NSString *fileName;
/** 当前写入文件大小 */
@property (nonatomic, assign) long long totalBytesWriten;
/** 文件总共大小 */
@property (nonatomic, assign) long long totalBytesExpectedToWrite;
/** 下载进度 */
@property (nonatomic, copy) NSProgress *progress;

@property (nonatomic, strong) NSOutputStream *stream;
@property (nonatomic, copy) successBlock successBlock;
@property (nonatomic, copy) failureBlock failureBlock;
@property (nonatomic, copy) progressBlock progressBlock;
@end

@implementation WDDownloadReceipt

- (NSOutputStream *)stream {
    if (_stream == nil) {
        _stream = [NSOutputStream outputStreamToFileAtPath:self.filePath
                                                    append:YES];
    }
    return _stream;
}

- (NSString *)filePath {
    NSFileManager *fileM = [NSFileManager defaultManager];
    NSString *path = [cacheFolder() stringByAppendingString:self.fileName];
    if (![path isEqualToString:_filePath]) {
        if (_filePath && [fileM fileExistsAtPath:_filePath]) {
            NSError *error;
            NSString *directory = [_filePath stringByDeletingLastPathComponent];
            [fileM createDirectoryAtPath:directory
             withIntermediateDirectories:YES
                              attributes:@{}
                                   error:&error];
        }
        _filePath = path;
    }
    return _filePath;
}

- (NSString *)fileName {
    if (_fileName == nil) {
        NSString *pathExt = self.url.pathExtension;
        _fileName = [NSString stringWithFormat:@"%@.%@", getMD5String(self.url),pathExt];
    }else {
        _fileName = getMD5String(self.url);
    }
    return _fileName;
}

- (NSProgress *)progress {
    if (_progress == nil) {
        _progress = [[NSProgress alloc] initWithParent:nil
                                              userInfo:nil];
    }
    _progress.totalUnitCount = self.totalBytesExpectedToWrite;
    _progress.completedUnitCount = self.totalBytesWriten;
    return _progress;
}

- (long long)totalBytesWriten {
    return fileSizeForPath(self.filePath);
}

- (instancetype)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        self.totalBytesExpectedToWrite = 1;
        self.url = url;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.url = [aDecoder
                    decodeObjectForKey:NSStringFromSelector(@selector(url))];
        self.filePath = [aDecoder
                         decodeObjectForKey:NSStringFromSelector(@selector(filePath))];
        self.state = [[aDecoder
                       decodeObjectOfClass:[NSNumber class]
                       forKey:NSStringFromSelector(@selector(state))] unsignedIntegerValue];
        self.fileName = [aDecoder
                         decodeObjectForKey:NSStringFromSelector(@selector(fileName))];
        self.totalBytesWriten = [[aDecoder
                                  decodeObjectOfClass:[NSNumber class]
                                  forKey:NSStringFromSelector(@selector(totalBytesWriten))] unsignedIntegerValue];
        self.totalBytesExpectedToWrite = [[aDecoder
                                           decodeObjectOfClass:[NSNumber class]
                                           forKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))] unsignedIntegerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.url
                  forKey:NSStringFromSelector(@selector(url))];
    [aCoder encodeObject:self.filePath
                  forKey:NSStringFromSelector(@selector(filePath))];
    [aCoder encodeObject:self.fileName
                  forKey:NSStringFromSelector(@selector(fileName))];
    [aCoder encodeObject:@(self.state)
                  forKey:NSStringFromSelector(@selector(state))];
    [aCoder encodeObject:@(self.totalBytesWriten)
                  forKey:NSStringFromSelector(@selector(totalBytesWriten))];
    [aCoder encodeObject:@(self.totalBytesExpectedToWrite)
                  forKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))];
}
@end

#pragma mark - 下载器
@interface WDDownloadManager ()<NSURLSessionDataDelegate>
@property (nonatomic, strong) dispatch_queue_t synchronizationQueue;
@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, assign) NSUInteger maxmumActiveDownloads;
@property (nonatomic, assign) NSUInteger activeRequestCount;

@property (nonatomic, strong) NSMutableArray *queueTasks;
@property (nonatomic, strong) NSMutableDictionary *tasks;
@property (nonatomic, strong) NSMutableArray *allReceipts;

@end

@implementation WDDownloadManager

/** 默认网络配置 */
+ (NSURLSessionConfiguration *)defaultURLSessionConfiguration {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPShouldSetCookies = YES;
    configuration.HTTPShouldUsePipelining = NO;
    configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    configuration.allowsCellularAccess = YES;
    configuration.timeoutIntervalForRequest = 60.0;
    
    return configuration;
}

- (instancetype)initWithSession:(NSURLSession *)session downloadPrioritization:(WDDownloaderPrioritization)prioritization maxmumActiveDownloader:(NSInteger)maxmumActivedownloader {
    if (self = [super init]) {
        self.session = session;
        self.prioritization = prioritization;
        self.maxmumActiveDownloads = maxmumActivedownloader;
        
        self.queueTasks = [NSMutableArray array];
        self.tasks = [NSMutableDictionary dictionary];
        self.activeRequestCount = 0;
        
        NSString *name = [NSString stringWithFormat:@"com.downloadManager-%@",[NSUUID UUID].UUIDString];
        self.synchronizationQueue = dispatch_queue_create([name cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidReceiveMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

/** 初始化 */
- (instancetype)init {
    NSURLSessionConfiguration *config = [self.class
                                         defaultURLSessionConfiguration];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:queue];
    return [self initWithSession:session
          downloadPrioritization:WDDownloaderPrioritizationFIFO
          maxmumActiveDownloader:4];
}
/** 单例方法 */
static WDDownloadManager *_instance = nil;
+ (instancetype)defautInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}
/** 接收器 */
- (NSMutableArray *)allReceipts {
    if (_allReceipts == nil) {
        NSArray *receipts = [NSKeyedUnarchiver
                             unarchiveObjectWithFile:LocalReceiptsPath()];
        _allReceipts = [NSMutableArray array];
        if (receipts != nil) {
            _allReceipts = receipts.mutableCopy;
        }
    }
    return _allReceipts;
}
/** 接收器本地化 */
- (void)saveReceipts:(NSArray <WDDownloadReceipt *> *)receipts {
    [NSKeyedArchiver archiveRootObject:receipts
                                toFile:LocalReceiptsPath()];
}
/** 根据URL查看下载器 */
- (WDDownloadReceipt *)downloadReceiptForUrl:(NSString *)url {
    if (url == nil) {
        return nil;
    }
    for (WDDownloadReceipt *receipt in self.allReceipts) {
        if ([receipt.url isEqualToString:url]) {
            return receipt;
        }
    }
    WDDownloadReceipt *receipt = [[WDDownloadReceipt alloc] initWithUrl:url];
    receipt.state = WDDownloadStateNone;
    receipt.totalBytesExpectedToWrite = 1;
    //添加入数组，防止多线程操作
    @synchronized (self) {
        [self.allReceipts addObject:receipt];
        [self saveReceipts:self.allReceipts];
    }
    return receipt;
}
/** 更新接收器 */
- (WDDownloadReceipt *)updateReceiptWithUrl:(NSString *)url state:(WDDownloaderState)state {
    WDDownloadReceipt *receipt = [self downloadReceiptForUrl:url];
    receipt.state = state;
    @synchronized (self) {
        [self saveReceipts:self.allReceipts];
    }
    return receipt;
}

- (WDDownloadReceipt *)downLoadFileWithUrl:(NSString *)url progress:(progressBlock)downloadProgressBlock destination:(NSURL * _Nonnull (^)(NSURL * _Nonnull, NSURLResponse * _Nonnull))destination success:(successBlock)success failure:(failureBlock)failure {
    __block WDDownloadReceipt *receipt = [self downloadReceiptForUrl:url];
    
    dispatch_sync(self.synchronizationQueue, ^{
        NSString *URL_ID = url;
        if (URL_ID == nil) {
            if (failure) {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:@{}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(nil,nil,error);
                });
                return ;
            }
        }
        receipt.successBlock = success;
        receipt.failureBlock = failure;
        receipt.progressBlock = downloadProgressBlock;
        
        //完成状态
        if (receipt.state == WDDownloadStateCompeleted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (receipt.successBlock) {
                    receipt.successBlock(nil,nil,[NSURL URLWithString:receipt.url]);
                }
            });
            return ;
        }
        
        if (receipt.state == WDDownloadStateDownloading) {
            dispatch_async(dispatch_get_main_queue(), ^{
                receipt.progressBlock(receipt.progress,receipt);
            });
            return ;
        }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                                        [NSURL URLWithString:receipt.url]];
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-",receipt.totalBytesWriten];
        [request setValue:range forHTTPHeaderField:@"Range"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
        task.taskDescription = receipt.url;
        self.tasks[receipt.url] = task;
        [self.queueTasks addObject:task];
        //没在下载中，没完成，就存储任务-然后取消
        [self resumeWithUrl:receipt.url];
    });
    return receipt;
}

- (NSURLSessionDownloadTask *)safelyRemoveTaskWithURLIdentifier:(NSString *)identifier {
    __block NSURLSessionDownloadTask *task = nil;
    dispatch_sync(self.synchronizationQueue, ^{
        task = [self removeTaskWithURLIdentifier:identifier];
    });
    return task;
}
/** 这个方法只能在  synchronizationQueue  这个队列中调用 才能保证安全 */
- (NSURLSessionDownloadTask *)removeTaskWithURLIdentifier:(NSString *)identifier {
    NSURLSessionDownloadTask *task = self.tasks[identifier];
    [self.tasks removeObjectForKey:identifier];
    return task;
}
/** 减少并发数 */
- (void)safelyDecrementActiveTaskCount {
    if (self.activeRequestCount > 0) {
        self.activeRequestCount -= 1;
    }
}

- (void)safelyStartNextTaskIfNecessary {
    dispatch_sync(self.synchronizationQueue, ^{
        if ([self isActiveRequestCountBelowMaxmumLimit]) {
            while (self.queueTasks.count > 0) {
                NSURLSessionDownloadTask *task = [self dequeueTask];
                WDDownloadReceipt *receipt = [self downloadReceiptForUrl:
                                              task.taskDescription];
                if (task.state == NSURLSessionTaskStateSuspended ||
                    receipt.state == WDDownloadStateWillResume) {
                    [self startTask:task];
                    break;
                }
            }
        }
    });
}
/** 判断是否需要增加下载任务 */
- (BOOL)isActiveRequestCountBelowMaxmumLimit {
    return self.activeRequestCount < self.maxmumActiveDownloads;
}
/** 任务出列 */
- (NSURLSessionDownloadTask *)dequeueTask {
    NSURLSessionDownloadTask *task = [NSURLSessionDownloadTask new];
    task = [self.queueTasks firstObject];
    [self.queueTasks removeObject:task];
    return task;
}
/** 任务入列 */
- (void)enqueueTask:(NSURLSessionDownloadTask *)task {
    switch (self.prioritization) {
        case WDDownloaderPrioritizationLIFO:
            [self.queueTasks addObject:task];    //FILO
            break;
        default:
            [self.queueTasks insertObject:task   //FIFO
                                  atIndex:0];
            break;
    }
}

- (void)startTask:(NSURLSessionDownloadTask *)task {
    [task resume];
    self.activeRequestCount ++;
    [self updateReceiptWithUrl:task.taskDescription state:WDDownloadStateDownloading];
}

#pragma mark - WDDownloadControlDelegate
/** 根据URL开始执行任务 */
- (void)resumeWithUrl:(NSString *)url {
    if (url == nil) {
        return;
    }
    WDDownloadReceipt *receipt = [self downloadReceiptForUrl:url];
    [self resumeWithDownloadReceipt:receipt];
}
/** 根据Receipt执行任务 */
- (void)resumeWithDownloadReceipt:(WDDownloadReceipt *)receipt {
    if ([self isActiveRequestCountBelowMaxmumLimit]) {
        [self startTask:self.tasks[receipt.url]];
    }
    else if(receipt.state == WDDownloadStateWillResume) {
        [self saveReceipts:self.allReceipts];
        [self enqueueTask:self.tasks[receipt.url]];
    }
}
/** 根据URL暂停 */
- (void)suspendWithUrl:(NSString *)url {
    if (url == nil) {
        return;
    }
    WDDownloadReceipt *receipt = [self downloadReceiptForUrl:url];
    [self suspendWithReceipt:receipt];
}
/** 根据Receipt暂停 */
- (void)suspendWithReceipt:(WDDownloadReceipt *)receipt {
    [self updateReceiptWithUrl:receipt.url state:WDDownloadStateSuspended];
    NSURLSessionDownloadTask *task = self.tasks[receipt.url];
    if (task) {
        [task suspend];
    }
}
/** 暂停全部 */
- (void)suspendAll {
    for (NSURLSessionDownloadTask *task in self.queueTasks) {
        [task suspend];
        WDDownloadReceipt *receipt = [self downloadReceiptForUrl:task.taskDescription];
        receipt.state = WDDownloadStateSuspended;
    }
    @synchronized (self) {
        [self saveReceipts:self.allReceipts];
    }
}

/** 移除 */
- (void)removeWithUrl:(NSString *)url {
    
}

- (void)removeWithReceipt:(WDDownloadReceipt *)receipt {
    NSURLSessionDownloadTask *task = self.tasks[receipt.url];
    if (task) {
        [task cancel];
    }
    [self.queueTasks removeObject:task];                    //队列移除
    [self safelyRemoveTaskWithURLIdentifier:receipt.url];   //内存移除
    
    @synchronized (self) {
        [self.allReceipts removeObject:receipt];            //本地移除
        [self saveReceipts:self.allReceipts];
    }
    
    NSFileManager *fileM = [NSFileManager defaultManager];
    NSError *error;
    [fileM removeItemAtPath:receipt.filePath error:&error];
    if (error) {
        NSLog(@"remove task with receipt failed -- %@",error);
    }
}

#pragma mark - URLSessionDataTaskDelegate
/** 开始得到服务器响应 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    WDDownloadReceipt *receipt = [self downloadReceiptForUrl:dataTask.taskDescription];
    receipt.totalBytesExpectedToWrite = response.expectedContentLength;
    receipt.state = WDDownloadStateDownloading;
    @synchronized (self) {
        [self saveReceipts:self.allReceipts];
    }
    completionHandler(NSURLSessionResponseAllow); //原样执行
}
/** 接收数据 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    WDDownloadReceipt *receipt = [self downloadReceiptForUrl:dataTask.taskDescription];
    receipt.progress.totalUnitCount = receipt.totalBytesExpectedToWrite;
    receipt.progress.completedUnitCount = receipt.totalBytesWriten;
    receipt.progressBlock(receipt.progress,receipt);
    
    [receipt.stream write:data.bytes maxLength:data.length];
}
/** 结束 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    WDDownloadReceipt *receipt = [self
                                  downloadReceiptForUrl:task.taskDescription];
    [receipt.stream close];
    receipt.stream = nil;
    
    if (error) {
        receipt.state = WDDownloadStateFailed;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.failureBlock) {
                receipt.failureBlock(task.originalRequest,(NSHTTPURLResponse *)task.response,error);
            }
        });
    }else {
        receipt.state = WDDownloadStateCompeleted;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.successBlock) {
                receipt.successBlock(task.originalRequest,(NSHTTPURLResponse *)task.response,task.originalRequest.URL);
            }
        });
    }
    @synchronized (self) {
        [self saveReceipts:self.allReceipts];
    }
    
    [self safelyDecrementActiveTaskCount];      //除去当前任务
    [self safelyStartNextTaskIfNecessary];      //开启下一个任务
}


#pragma mark - 系统通知
- (void)applicationWillTerminate:(NSNotification *)notif {
    [self suspendAll];
}

- (void)applicationDidReceiveMemoryWarning:(NSNotification *)notif {
    [self suspendAll];
}

@end
