//
//  VICacheManager.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VICacheManager.h"
#import "VIMediaDownloader.h"

NSString *VICacheManagerDidUpdateCacheNotification = @"VICacheManagerDidUpdateCacheNotification";

NSString *VICacheURLKey = @"VICacheURLKey";
NSString *VICacheFragmentsKey = @"VICacheFragmentsKey";
NSString *VICacheContentLengthKey = @"VICacheContentLengthKey";

static NSString *kMCMediaCacheDirectory;

@implementation VICacheManager

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setCacheDirectory:[NSTemporaryDirectory() stringByAppendingPathComponent:@"vimedia"]];
    });
}

+ (void)setCacheDirectory:(NSString *)cacheDirectory {
    kMCMediaCacheDirectory = cacheDirectory;
}

+ (NSString *)cacheDirectory {
    return kMCMediaCacheDirectory;
}

+ (NSString *)cachedFilePathForURL:(NSURL *)url {
    return [[self cacheDirectory] stringByAppendingPathComponent:[url lastPathComponent]];
}

+ (VICacheConfiguration *)cacheConfigurationForURL:(NSURL *)url {
    NSString *filePath = [self cachedFilePathForURL:url];
    VICacheConfiguration *configuration = [VICacheConfiguration configurationWithFilePath:filePath];
    return configuration;
}

+ (unsigned long long)calculateCachedSizeWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [self cacheDirectory];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:error];
    unsigned long long size = 0;
    if (files) {
        for (NSString *path in files) {
            NSString *filePath = [cacheDirectory stringByAppendingPathComponent:path];
            NSDictionary<NSFileAttributeKey, id> *attribute = [fileManager attributesOfItemAtPath:filePath error:error];
            if (!attribute) {
                size = -1;
                break;
            }
            
            size += [attribute fileSize];
        }
    }
    return size;
}

+ (void)cleanAllCacheWithError:(NSError **)error {
    // Find downloaing file
    NSMutableSet *downloadingFiles = [NSMutableSet set];
    [[[VIMediaDownloaderStatus shared] urls] enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *file = [self cachedFilePathForURL:obj];
        [downloadingFiles addObject:file];
        NSString *configurationPath = [VICacheConfiguration configurationFilePathForFilePath:file];
        [downloadingFiles addObject:configurationPath];
    }];
    
    // Remove files
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [self cacheDirectory];
    
    NSArray *files = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:error];
    if (files) {
        for (NSString *path in files) {
            NSString *filePath = [cacheDirectory stringByAppendingPathComponent:path];
            if ([downloadingFiles containsObject:filePath]) {
                continue;
            }
            if (![fileManager removeItemAtPath:filePath error:error]) {
                break;
            }
        }
    }
}

+ (void)cleanCacheForURL:(NSURL *)url error:(NSError **)error {
    if ([[VIMediaDownloaderStatus shared] containsURL:url]) {
        NSString *description = [NSString stringWithFormat:NSLocalizedString(@"Clean cache for url `%@` can't be done, because it's downloading", nil), url];
        *error = [NSError errorWithDomain:@"com.mediadownload" code:2 userInfo:@{NSLocalizedDescriptionKey: description}];
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self cachedFilePathForURL:url];
    
    if ([fileManager fileExistsAtPath:filePath]) {
        if (![fileManager removeItemAtPath:filePath error:error]) {
            return;
        }
    }
    
    NSString *configurationPath = [VICacheConfiguration configurationFilePathForFilePath:filePath];
    if ([fileManager fileExistsAtPath:configurationPath]) {
        if (![fileManager removeItemAtPath:configurationPath error:error]) {
            return;
        }
    }
}

@end
