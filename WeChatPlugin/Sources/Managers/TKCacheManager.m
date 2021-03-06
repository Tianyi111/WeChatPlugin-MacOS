//
//  TKCacheManager.m
//  WeChatPlugin
//
//  Created by TK on 2018/8/3.
//  Copyright © 2018年 tk. All rights reserved.
//

#import "TKCacheManager.h"

@interface TKCacheManager () <EmoticonDownloadMgrExt>

@property (nonatomic, copy) NSString *cacheDirectory;
@property (nonatomic, strong) NSMutableSet *emotionSet;
@end

@implementation TKCacheManager

+ (instancetype)shareManager {
    static TKCacheManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[TKCacheManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.cacheDirectory = [NSTemporaryDirectory() stringByAppendingString:@"TKWeChatPlugin/"];
        NSFileManager *manager = [NSFileManager defaultManager];
        if (![manager fileExistsAtPath:self.cacheDirectory]) {
            [manager createDirectoryAtPath:self.cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        MMExtensionCenter *extensionCenter = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("MMExtensionCenter") class]];
        MMExtension *extension = [extensionCenter getExtension:@protocol(EmoticonDownloadMgrExt)];
        if (extension) {
            [extension registerExtension:self];
        }
        
        self.emotionSet = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc {
    MMExtensionCenter *extensionCenter = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("MMExtensionCenter") class]];
    MMExtension *extension = [extensionCenter getExtension:@protocol(EmoticonDownloadMgrExt)];
    if (extension) {
        [extension unregisterExtension:self];
    }
}

- (BOOL)fileExistsWithName:(NSString *)fileName {
    fileName = [fileName stringByAppendingString:@".gif"];
    NSString *filePath = [self.cacheDirectory stringByAppendingString:fileName];
    NSFileManager *manager = [NSFileManager defaultManager];
    return [manager fileExistsAtPath:filePath];
}

- (NSString *)filePathWithName:(NSString *)fileName {
    if (![self fileExistsWithName:fileName]) return nil;
    
    fileName = [fileName stringByAppendingString:@".gif"];
    return [self.cacheDirectory stringByAppendingString:fileName];
}

- (NSString *)cacheImageData:(NSData *)imageData withFileName:(NSString *)fileName completion:(void (^)(BOOL))completion {
    BOOL result = NO;
    if (!imageData) {
        if (completion) {
            completion(result);
        }
    }
    NSString *imageName = [NSString stringWithFormat:@"%@.gif", fileName];
    NSString *tempImageFilePath = [self.cacheDirectory stringByAppendingString:imageName];
    if (imageData) {
        NSURL *imageUrl = [NSURL fileURLWithPath:tempImageFilePath];
        result = [imageData writeToURL:imageUrl atomically:YES];
    }
    
    if (completion) {
        completion(result);
    }
    return tempImageFilePath;
}

- (NSString *)cacheEmotionMessage:(MessageData *)emotionMsg {
    EmoticonMgr *emoticonMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("EmoticonMgr")];
    NSData *imageData = [emoticonMgr getEmotionDataWithMD5:emotionMsg.m_nsEmoticonMD5];
    if (!imageData && ![self.emotionSet containsObject:emotionMsg.m_nsEmoticonMD5]) {
        EmoticonDownloadMgr *emotionMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("EmoticonDownloadMgr")];
        [emotionMgr downloadEmoticonWithMessageData:emotionMsg];
        [self.emotionSet addObject:emotionMsg.m_nsEmoticonMD5];
    }
    NSString *tempImageFilePath = [self cacheImageData:imageData withFileName:emotionMsg.m_nsEmoticonMD5 completion:nil];

    return tempImageFilePath;
}

- (void)emoticonDownloadFinished:(EmoticonMsgInfo *)msgInfo {
    if (![self.emotionSet containsObject:msgInfo.m_nsMD5]) return;
    
    EmoticonMgr *emoticonMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("EmoticonMgr")];
    NSData *imageData = [emoticonMgr getEmotionDataWithMD5:msgInfo.m_nsMD5];
    [self cacheImageData:imageData withFileName:msgInfo.m_nsMD5 completion:^(BOOL result) {
        if(result) {
            [self.emotionSet removeObject:msgInfo.m_nsMD5];
        }
    }];
}

@end
