//
//  File.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface File : NSObject

@property (nonatomic) NSString *fileName;
@property (nonatomic) int fileID;
@property (nonatomic) int folderID;

@property (nonatomic) NSString *fileDescription;
@property (nonatomic) NSInteger pageCount;
@property (nonatomic) NSData *fileCover;

@property (nonatomic) BOOL canDownload;
@property (nonatomic) BOOL isLocked;
@property (nonatomic) BOOL isDownloaded;
//@property (nonatomic) BOOL isFirstLatest;
@property (nonatomic) BOOL isLatest;
@property (nonatomic) BOOL isBookmarked;

@property (nonatomic) NSString *fileSize;
@property (nonatomic) NSString *fileType;
@property (nonatomic) NSString *fileExtension;

@property (nonatomic) NSString *createDate;
@property (nonatomic) NSString *modifyDate;

@end
