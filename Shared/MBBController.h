//
//  MBBController.h
//  Mobisec
//
//  Copyright (c) 2014 William Zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "File.h"
#import "Folder.h"

@protocol MBBDownloadController <NSObject>

@optional
- (void)fileDownloadStarted:(File *)file;
- (void)fileDownloadFinished:(File *)file successfull:(BOOL)isSuccessful;
- (void)fileDownloadProgressChanged:(CGFloat)updatedPercentage;

- (void)fileFirstPageDownloaded:(File *)file;
- (void)batchUploadAccomplished:(BOOL)successful error:(NSError *)error;

@end

#define AuthenticationSuccess @"AuthenticationSuccess"

@class BookInformation;
@interface MBBController : NSObject <UIAlertViewDelegate, CLLocationManagerDelegate>

typedef NS_ENUM(NSInteger, LOGIN_FREQUENCY) {
    LF_ONCE_PER_APPLICATION_LIFE_TIME,
    LF_EVERY_RESUME_FROM_BACKGROUND,
    LF_CUSTOM
};

@property (nonatomic) NSString *deviceToken;

typedef void (^MBBDownload)(NSMutableArray *downloadObjects);

@property (nonatomic) NSString *companyToken;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *password;
@property (nonatomic, strong) NSString *targetAddress;
- (void)parseTargetAddress:(NSString *)address;

@property (nonatomic, assign) id<MBBDownloadController> delegate;
- (void)setLoginFrequency:(LOGIN_FREQUENCY)frequency;

- (void)moveOnline;
- (void)rebootEmpress;
- (void)performLogin;
- (void)fetchOfflineNotices;
- (CLLocation *)getLastLocation;

+ (MBBController *)sharedManager;
- (void)downloadTheTreeListStoreLocalCompletionHandler:(MBBDownload)completion;
- (NSData *)downloadTreeListData;

- (NSData *)downloadPageData:(File *)file withPage:(int)page;
- (NSData *)downloadFirstPageOfFile:(File *)file;
- (BOOL)uploadImage:(NSData *)data folderID:(int)folderID fileName:(NSString *)fileName;

- (BOOL)checkFileExtension:(NSString *)fileExtension;

- (void)downloadFile:(File *)file delegate:(id<MBBDownloadController>)delegate;
- (void)removeFileFromSystemWithFileInformation:(File *)file;
- (NSData *)getDataForPage:(NSString *)page fromFile:(File *)file;

- (NSString *)localizeDate:(NSString *)date;

- (NSString *)readIdentificationFile;
- (NSString *)returnCurrentDate;

@property (nonatomic) BOOL isUploading;
- (void)batchUploadImages;

@property (nonatomic) BOOL isOnline;
@property (nonatomic) NSString *license;
@property (nonatomic) NSString *encryptionKey;

@property (nonatomic) BOOL isEmpressInit;
@property (nonatomic) BOOL isAuthenticated;
@property (nonatomic) BOOL isAlertShowing;
@property (nonatomic, strong) NSMutableArray *treeList;
- (NSMutableArray *)fetchTreeList;

@property (nonatomic, assign) BOOL isReachable;
@property (nonatomic, copy) NSString* empressPath;
@property (nonatomic, copy) NSString* tmpPath;
@property (nonatomic, copy) NSString* workPath;

@property (nonatomic, assign) BOOL didLoad;
@property (nonatomic, assign) BOOL shouldCancel;

@end
