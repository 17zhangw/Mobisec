//
//  MBBController.m
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import "MBBController.h"
#import "MBBCollectionViewController.h"
#import "SQLHelper.h"
#import "Reachability.h"

#import "AuthViewController.h"
#import "DisplayController.h"
#import "ReadVC.h"
#import "RNDecryptor.h"
#import "RNEncryptor.h"

#import "NSString+MD5Addition.h"
#import "FDKeychain.h"
#import "iOSBlocks.h"
#import "MBBTController.h"

@interface MBBController ()
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic) CGFloat downloadProgress;
@property (nonatomic) BOOL didDownload;
@property (nonatomic) BOOL downloadInProgress;
@property (nonatomic) BOOL transCancelled;

@property (nonatomic) NSDateFormatter *formatter;
@property (nonatomic) BOOL hasFetchedOffNotices;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *lastLocation;
@end

@implementation MBBController

#pragma mark ------------- Shared manager

+ (MBBController *)sharedManager {
    static MBBController *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

- (id)init {
    if ((self = [super init])) {
        Reachability *r = [Reachability reachabilityWithHostname:@"www.google.com"];
        [r startNotifier];
        self.isReachable = [r isReachable];
        r.reachableBlock = ^(Reachability *reachability) {
            self.isReachable = YES;
        };
        
        r.unreachableBlock = ^(Reachability * reachability) {
            self.isReachable = NO;
        };
        
        self.workPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory , NSUserDomainMask, YES)[0];
        self.workPath = [self.workPath stringByAppendingPathComponent:@"Mobisec"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.workPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.workPath withIntermediateDirectories:YES attributes:nil error:nil];
            NSURL *url = [NSURL fileURLWithPath:self.workPath];
            [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
        }
        
        NSBundle* mainBundle = [NSBundle mainBundle];
        NSString* mPath = [mainBundle bundlePath];
        
        self.empressPath = [mPath stringByAppendingString:@"/empress"];
        setenv("EMPRESSPATH", (char*) [self.empressPath UTF8String], 1);
        
        self.tmpPath = NSTemporaryDirectory();
        setenv("TMPDIR", (char*) [self.tmpPath UTF8String], 1);
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if ([fileManager changeCurrentDirectoryPath:self.workPath] != YES)
            NSLog(@"failed to change current directory path\n");
        
        self.formatter = [[NSDateFormatter alloc] init];
        [self.formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        
        [self.locationManager startUpdatingLocation];
    }
    
    return self;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    self.lastLocation = [locations lastObject];
}

- (CLLocation *)getLastLocation {
    return self.lastLocation;
}

- (void)fetchOfflineNotices {
    if (!self.isOnline) return;
    if (!self.isReachable) return;
    
    NSString *uuid = [[self readIdentificationFile] stringByAppendingString:[self returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *post = [NSString stringWithFormat:@"&iRequestType=8&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@",self.username,self.password,self.companyToken, uuid];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/terminal/auth",self.targetAddress]]];
    [request setHTTPMethod:@"POST"];
    NSData *postData = [post dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [request setHTTPBody:postData];
    
    NSURLResponse *response;
    NSError *connectionError;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&connectionError];
    
    NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
    NSLog(@"%lu",(long)[r statusCode]);
    if (connectionError) {
        NSLog(@"%@",[connectionError localizedDescription]);
        return;
    }
    
    if (data == nil) return;
    
    NSDictionary *values = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    if ([values[@"iAuthResult"] intValue] == 0) return;
    
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documents]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documents];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *file = [documents stringByAppendingPathComponent:@"info.dat"];
    NSMutableArray *fileContents;
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        NSData *data = [NSData dataWithContentsOfFile:file];
        NSData *dData = [RNDecryptor decryptData:data withPassword:@"SwuDAmabeqAbugU2taswebRaQEvufrar" error:nil];
        fileContents = [[NSKeyedUnarchiver unarchiveObjectWithData:dData] mutableCopy];
        if (!fileContents) fileContents = [NSMutableArray array];
    } else {
        fileContents = [NSMutableArray array];
    }
    
    NSString *blacklist = [documents stringByAppendingPathComponent:@"bl.dat"];
    NSArray *ids = [[[NSString alloc] initWithContentsOfFile:blacklist encoding:NSUTF8StringEncoding error:nil]
                    componentsSeparatedByString:@","];
    
    if ([values[@"OfflineInfo"] isKindOfClass:[NSNull class]])
        return;
    
    for (NSDictionary *a in values[@"OfflineInfo"]) {
        if ([self validateAgainstBlacklistIDS:ids id:[a[@"offline_id"] integerValue]])
            continue;
        
        BOOL shouldReplace = NO;
        NSInteger index = -1;
        for (NSArray *b in fileContents) {
            if ([[b objectAtIndex:0] integerValue] == [a[@"offline_id"] integerValue]) {
                shouldReplace = YES;
                index = [fileContents indexOfObject:b];
            }
        }
        
        NSString *lic = (a[@"lic"] == NULL || [a[@"lic"] isSubclassOfClass:[NSNull class]]) ? @"" : a[@"lic"];
        if ([lic length] == 0) { lic = self.license; }
        
        NSArray *obj = [NSArray arrayWithObjects:a[@"offline_id"],lic,values[@"strStartHalfEncryptionKey"],a[@"offline_end_time"],a[@"offline_start_time"], nil];
        if (!shouldReplace) [fileContents addObject:obj];
        else [fileContents replaceObjectAtIndex:index withObject:obj];
    }
    
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:fileContents];
    NSData *eData = [RNEncryptor encryptData:archived withSettings:kRNCryptorAES256Settings password:@"SwuDAmabeqAbugU2taswebRaQEvufrar" error:nil];
    [eData writeToFile:file atomically:NO];
}

- (BOOL)validateAgainstBlacklistIDS:(NSArray *)blacklist id:(NSInteger)value {
    for (NSString *t in blacklist) {
        if ([t integerValue] == value) return YES;
    }
    
    return NO;
}

- (void)rebootEmpress {
    msend();
    msinit();
    char *l = (char*)[self.license UTF8String];
    setenv("MSLICENCE", l, 1);
    if (!msinit()) {
        NSLog(@"%@",[NSString stringWithFormat: @"(%d) %s\n", mroperr, mrerrmsg()]);
    }
    
    char *ky = (char*)[self.encryptionKey UTF8String];
    char *k = (char*)ky;
    
    NSString *dbp = [NSString stringWithFormat:@"/private%@/%@",[[MBBController sharedManager] workPath],@"FILES"];
    if (!mrsetdbcipherkeyinfo([dbp UTF8String], k)) {
        NSLog(@"Set Key has Failed!");
        NSLog(@"%@",[NSString stringWithFormat: @"(%d) %s\n", mroperr, mrerrmsg()]);
    }
}

- (NSString *)localizeDate:(NSString *)date {
    [self.formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDate *gmtDate = [self.formatter dateFromString:date];
    [self.formatter setTimeZone:[NSTimeZone systemTimeZone]];
    NSString *sDate = [self.formatter stringFromDate:gmtDate];
    [self.formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return sDate;
}

#pragma mark - Batch Upload

- (void)batchUploadImages {
    if (self.isUploading)
        return;
    
    self.isUploading = YES;
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documentPath = [documentPath stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documentPath];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *photoDirectory = [documentPath stringByAppendingPathComponent:@"PHOTOS"];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:photoDirectory error:nil];
    
    for (NSString *pathLocation in contents) {
        NSString *directoryLocation = [photoDirectory stringByAppendingPathComponent:pathLocation];
        
        NSArray *actualContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryLocation error:nil];
        for (NSString *file in actualContent) {
            @autoreleasepool {
                NSString *completePath = [directoryLocation stringByAppendingPathComponent:file];
                NSData *data = [NSData dataWithContentsOfFile:completePath];
                if (self.shouldCancel) {
                    self.isUploading = NO;
                    [self.delegate batchUploadAccomplished:NO error:nil];
                    return;
                }
                
                if (![self uploadImage:data folderID:[pathLocation intValue] fileName:file]) {
                    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"UPLOAD_FAILED", nil),NSLocalizedDescriptionKey,nil];
                    NSError *error = [NSError errorWithDomain:@"SDBDomain" code:1 userInfo:dictionary];
                    [self.delegate batchUploadAccomplished:NO error:error];
                    self.isUploading = NO;
                    self.shouldCancel = NO;
                    return;
                }
                
                [[NSFileManager defaultManager] removeItemAtPath:completePath error:nil];
            }
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:directoryLocation error:nil];
    }
    
    [self.delegate batchUploadAccomplished:YES error:nil];
    self.shouldCancel = NO;
    self.isUploading = NO;
    return;
}

#pragma mark ---- Parse Web Address

- (void)parseTargetAddress:(NSString *)address {
    NSMutableString *alteredAddress = [address mutableCopy];
    if ([alteredAddress characterAtIndex:[alteredAddress length]-1] == '/') {
        alteredAddress = [[address substringToIndex:[address length]-1] mutableCopy];
    }
    
    if ([alteredAddress rangeOfString:@"http://"].location == NSNotFound && [alteredAddress rangeOfString:@"https://"].location == NSNotFound) {
        alteredAddress = [[@"https://" stringByAppendingString:alteredAddress] mutableCopy];
    }
    
    self.targetAddress = alteredAddress;
}

#pragma mark ------------- Show Login

- (void)performLogin {
    if ([self analyzeOfflineMode]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        if (self.isAlertShowing) {
            UINavigationController *c = (UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController];
            if ([[c topViewController] isKindOfClass:[AuthViewController class]]) {
                [(AuthViewController *)[c topViewController] swapToKeyEntry];
            }
        } else {
            [NSTimeZone resetSystemTimeZone];
            UINavigationController *c = (UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController];
            if ([[c topViewController] isKindOfClass:[DisplayController class]])
                [(DisplayController *)[c topViewController] performLogin];
            else if ([[c topViewController] isKindOfClass:[ReadVC class]])
                [(ReadVC *)[c topViewController] performLogin];
            else if ([[c topViewController] isKindOfClass:[MBBTController class]])
                [(MBBTController *)[c topViewController] performLogin];
            self.isAlertShowing = YES;
        }
        return;
    }
    
    if (self.isAlertShowing)
        return;
    
    [NSTimeZone resetSystemTimeZone];
    UINavigationController *c = (UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController];
    if ([[c topViewController] isKindOfClass:[DisplayController class]])
        [(DisplayController *)[c topViewController] performLogin];
    else if ([[c topViewController] isKindOfClass:[ReadVC class]])
        [(ReadVC *)[c topViewController] performLogin];
    else if ([[c topViewController] isKindOfClass:[MBBTController class]])
        [(MBBTController *)[c topViewController] performLogin];
    
    self.isAlertShowing = YES;
}

- (void)moveOnline {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documents]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documents];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *blacklist = [documents stringByAppendingPathComponent:@"bl.dat"];
    NSString *contents = [[NSString alloc] initWithContentsOfFile:blacklist encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *blacklistIDs = [[contents componentsSeparatedByString:@","] mutableCopy];
    if (!blacklistIDs) blacklistIDs = [NSMutableArray array];
    
    NSString *file = [documents stringByAppendingPathComponent:@"info.dat"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        NSData *data = [NSData dataWithContentsOfFile:file];
        NSData *dData = [RNDecryptor decryptData:data withPassword:@"SwuDAmabeqAbugU2taswebRaQEvufrar" error:nil];
        
        NSMutableArray *content = [[NSKeyedUnarchiver unarchiveObjectWithData:dData] mutableCopy];
        NSMutableArray *toDelete = [NSMutableArray array];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        for (NSArray *subContent in content) {
            NSDate *now = [NSDate date];
            NSDate *endDate = [formatter dateFromString:subContent[3]];
            NSDate *startDate = [formatter dateFromString:subContent[4]];
            if ([now compare:endDate] == NSOrderedAscending && [now compare:startDate] == NSOrderedDescending) {
                [toDelete addObject:subContent];
                
                if (![blacklistIDs containsObject:subContent[0]])
                    [blacklistIDs addObject:subContent[0]];
            } else if ([now compare:startDate] == NSOrderedAscending)  {
            } else {
                [toDelete addObject:subContent];
                
                if (![blacklistIDs containsObject:subContent[0]])
                    [blacklistIDs addObject:subContent[0]];
            }
        }
        
        for (NSArray *a in toDelete) {
            [content removeObject:a];
        }
        
        NSData *archiver = [NSKeyedArchiver archivedDataWithRootObject:content];
        NSData *eData = [RNEncryptor encryptData:archiver withSettings:kRNCryptorAES256Settings password:@"SwuDAmabeqAbugU2taswebRaQEvufrar" error:nil];
        [eData writeToFile:file atomically:NO];
    }
    
    NSString *ids = [blacklistIDs componentsJoinedByString:@","];
    [ids writeToFile:blacklist atomically:NO encoding:NSUTF8StringEncoding error:nil];
    
    self.isOnline = YES;
}

- (BOOL)analyzeOfflineMode {    
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documents]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documents];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *file = [documents stringByAppendingPathComponent:@"info.dat"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        
        NSData *data = [NSData dataWithContentsOfFile:file];
        NSData *dData = [RNDecryptor decryptData:data withPassword:@"SwuDAmabeqAbugU2taswebRaQEvufrar" error:nil];
        if (dData != nil) {
            NSMutableArray *content = [[NSKeyedUnarchiver unarchiveObjectWithData:dData] mutableCopy];
            NSMutableArray *toDelete = [NSMutableArray array];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            for (NSArray *subContent in content) {
                NSDate *now = [NSDate date];
                NSDate *endDate = [formatter dateFromString:subContent[3]];
                NSDate *startDate = [formatter dateFromString:subContent[4]];
                if ([now compare:endDate] == NSOrderedAscending && [now compare:startDate] == NSOrderedDescending) {
                    self.license = subContent[1];
                    self.encryptionKey = subContent[2];
                    self.isOnline = NO;
                    return YES;
                } else if ([now compare:startDate] == NSOrderedAscending)  {
                } else {
                    [toDelete addObject:subContent];
                }
            }
            
            for (NSArray *a in toDelete) {
                [content removeObject:a];
            }
            
            NSData *archiver = [NSKeyedArchiver archivedDataWithRootObject:content];
            NSData *eData = [RNEncryptor encryptData:archiver withSettings:kRNCryptorAES256Settings password:@"SwuDAmabeqAbugU2taswebRaQEvufrar" error:nil];
            [eData writeToFile:file atomically:NO];
        }
    }
    return NO;
}

- (void)setLoginFrequency:(LOGIN_FREQUENCY)frequency {
    if ([self analyzeOfflineMode])
        return;
    
    self.isOnline = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    switch (frequency) {
        case LF_ONCE_PER_APPLICATION_LIFE_TIME:
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(performLogin) name:UIApplicationDidFinishLaunchingNotification object:nil];
            break;
        case LF_EVERY_RESUME_FROM_BACKGROUND:
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(performLogin) name:UIApplicationWillEnterForegroundNotification object:nil];
            break;
        case LF_CUSTOM:
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            break;
            
        default:
            break;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopDownloads) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

#pragma mark --- Stop Downloads

- (void)stopDownloads {
    self.transCancelled = YES;
    self.didDownload = NO;
    [self.downloadQueue cancelAllOperations];
    
    self.isUploading = NO;
    self.shouldCancel = YES;
}

#pragma mark ------------- Download Book List

- (NSMutableArray *)fetchTreeList {
    if (self.treeList)
        return self.treeList;
    else
        return [self downloadTheTreeList];
}

- (void)downloadTheTreeListStoreLocalCompletionHandler:(MBBDownload)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *a = [self downloadTheTreeList];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (a == nil) {
                completion(nil);
                return;
            }
            self.treeList = a;
            completion(a);
        });
    });
}

- (NSData *)downloadTreeListData {
    if (!self.isReachable) return nil;
    
    NSString *uuid = [[self readIdentificationFile] stringByAppendingString:[self returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *post = [NSString stringWithFormat:@"&iRequestType=3&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@",self.username,self.password,self.companyToken, uuid];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/terminal/auth",self.targetAddress]]];
    [request setHTTPMethod:@"POST"];
    NSData *postData = [post dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [request setHTTPBody:postData];
    
    NSURLResponse *response;
    NSError *connectionError;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&connectionError];
    
    NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
    NSLog(@"%lu",(long)[r statusCode]);
    if (connectionError) {
        NSLog(@"%@",[connectionError localizedDescription]);
        return nil;
    }
    return data;
}

- (NSMutableArray *)downloadTheTreeList {
    NSData *data;
    
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documents]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documents];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *file = [documents stringByAppendingPathComponent:@"data.json"];
    if (self.isOnline) {
        data = [self downloadTreeListData];
        [data writeToFile:file atomically:NO];
    } else
        data = [NSData dataWithContentsOfFile:file];
    
    NSError *error;
    if (data == nil) {
        [self showError];
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        NSLog(@"Error: %@",[error localizedDescription]);
        return nil;
    }
    
    if (!object)
        return nil;
    
    if ([[object allKeys] containsObject:@"iAuthResult"]) {
        if ([object[@"iAuthResult"] intValue] == 0)
            return nil;
    }
    
    [self rebootEmpress];
    NSArray *obj = object[@"strTreeData"];
    
    NSMutableArray *a = [NSMutableArray array];
    for (NSMutableDictionary *d in obj) {
        NSMutableDictionary *dict = [d mutableCopy];
        [self cleanOutNullKeys:dict];
        if (![dict[@"is_folder"] boolValue]) { // is file
            File *f = [self setupFileWithDictionary:dict];
            if (f == nil) return nil;
            if ([f pageCount] != -100)
                [a addObject:f];
        } else { // is folder
            Folder *f = [self setupFolderWithDictionary:dict];
            if (f == nil) return nil;
            [a addObject:f];
        }
    }
    return a;
}

- (void)cleanOutNullKeys:(NSMutableDictionary *)dictionary {
    NSArray *keys = [dictionary allKeys];
    for (id o in keys) {
        if ([dictionary[o] isKindOfClass:[NSNull class]]) {
            [dictionary setObject:@"" forKey:o];
        } else if ([dictionary[o] isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *d = [dictionary[o] mutableCopy];
            [self cleanOutNullKeys:d];
            [dictionary setObject:d forKey:o];
        }
    }
}

- (Folder *)setupFolderWithDictionary:(NSDictionary *)dict {
    Folder *f = [Folder new];
    [f setFolderID:[dict[@"sign"][@"folder_id"] intValue]];
    [f setFolderName:dict[@"text"]];
    [f setFolderLevel:[dict[@"sign"][@"folder_level"] intValue]];
    [f setFolderDescription:dict[@"folder_detail"][@"folder_description"]];
    [f setCreateDate:dict[@"folder_detail"][@"create_date"]];
    [f setModifyDate:dict[@"folder_detail"][@"modify_date"]];
    [f setParentID:[dict[@"sign"][@"folder_pid"] intValue]];
    
    NSMutableArray *children = [NSMutableArray array];
    for (NSMutableDictionary *di in dict[@"children"]) {
        NSMutableDictionary *d = [di mutableCopy];
        [self cleanOutNullKeys:d];
        if (![d[@"is_folder"] boolValue]) { // is file
            File *file = [self setupFileWithDictionary:d];
            if (file == nil) return nil;
            if ([file pageCount] != -100)
                [children addObject:file];
        } else {
            Folder *folder = [self setupFolderWithDictionary:d];
            if (folder == nil) return nil;
            [children addObject:folder];
        }
    }
    
    [f setChildren:children];
    return f;
}

- (File *)setupFileWithDictionary:(NSDictionary *)dict {
    File *f = [File new];
    [f setFileID:[dict[@"sign"][@"file_id"] intValue]];
    [f setFolderID:[dict[@"sign"][@"folder_id"] intValue]];
    [f setFileName:dict[@"text"]];
    [f setFileDescription:dict[@"file_detail"][@"file_description"]];
    [f setIsLocked:[dict[@"file_detail"][@"file_status"] boolValue]];
    [f setFileSize:dict[@"file_detail"][@"file_size"]];
    [f setFileType:dict[@"file_detail"][@"file_type"]];
    [f setFileExtension:dict[@"file_detail"][@"file_extension"]];
    [f setCreateDate:dict[@"file_detail"][@"create_date"]];
    [f setModifyDate:dict[@"file_detail"][@"modify_date"]];

    NSTimeZone *tempZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    if (![[self.formatter timeZone] isEqualToTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]]) {
        tempZone = [self.formatter timeZone];
        [self.formatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    }
    
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM CENTRAL WHERE FILE_ID='%d'",[f fileID]];
    NSArray *results = [SQLHelper execQuery:(char*)[sql UTF8String] useDB:"FILES"];

    if ([results count] == 5) {
        if ([[self.formatter dateFromString:results[1]] isEqualToDate:[self.formatter dateFromString:[f modifyDate]]]) { [f setIsLatest:YES]; }
        else { [f setIsLatest:NO]; }
        
        int pageCount = [self retrievePageCountForFile:f];
        if (pageCount <= 0 && [results[4] intValue] <= 0) {
            [f setPageCount:-100];
            return f;
        }
        
        [f setIsBookmarked:[self isBookMarked:f]];
        [f setIsDownloaded:[results[2] boolValue]];
        [f setCanDownload:YES];
        
        if (![f isLatest] && ![results[2] boolValue]) {
            [f setPageCount:pageCount];
            sql = [NSString stringWithFormat:@"UPDATE CENTRAL SET PAGECOUNT TO '%d' WHERE FILE_ID='%d'",pageCount,[f fileID]];
            if (![SQLHelper executeSQL:(char*)[sql UTF8String] useDB:"FILES"])
                return false;
            
            [f setCanDownload:YES];
            [f setFileCover:[self registerAnyPage:f page:1]];
            
            sql = [NSString stringWithFormat:@"UPDATE CENTRAL SET MODIFY_DATE TO '%@' WHERE FILE_ID='%d'",[f modifyDate],[f fileID]];
            if (![SQLHelper executeSQL:(char*)[sql UTF8String] useDB:"FILES"])
                return false;

            return f;
        } else {
            [f setPageCount:[results[4] intValue]];
            [f setFileCover:[self getDataForPage:@"1" fromFile:f]];
            return f;
        }
    }
    
    int pageCount = [self retrievePageCountForFile:f];
    if (pageCount <= 0) {
        [f setPageCount:-100];
        return f;
    }
    
    [f setCanDownload:YES];
    [f setFileCover:[self downloadPageData:f withPage:1]];
    
    sql = [NSString stringWithFormat:@"INSERT INTO CENTRAL (FILE_ID, MODIFY_DATE, ISDOWNLOADED, ISFIRSTLATEST, PAGECOUNT) VALUES ('%d','%@',False,False,'%d')",[f fileID], [f modifyDate], pageCount];
    if (![SQLHelper executeSQL:(char*)[sql UTF8String] useDB:"FILES"])
        return false;
    
    [f setPageCount:pageCount];
    [f setIsLatest:YES];
    [f setCanDownload:YES];
    [f setIsBookmarked:[self isBookMarked:f]];
    [f setIsDownloaded:NO];
    return f;
}
            
- (BOOL)checkFileExtension:(NSString *)fileExtension {
    if ([fileExtension isEqualToString:@"png"])
        return YES;
    if ([fileExtension isEqualToString:@"jpg"])
        return YES;
    if ([fileExtension isEqualToString:@"jpeg"])
        return YES;
    return NO;
}

#pragma mark - Get Page Count

- (int)retrievePageCountForFile:(File *)file {
    if (!self.isOnline) return 0;
    if (!self.isReachable) return 0;
    
    NSString *uuid = [[self readIdentificationFile] stringByAppendingString:[self returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *post = [NSString stringWithFormat:@"iRequestType=5&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@&strRequestData={\"folder_id\":%d,\"file_id\":%d}",self.username,self.password,self.companyToken,uuid,[file folderID],[file fileID]];
    NSMutableURLRequest *request = [self createRequest:post];
    
    NSURLResponse *response;
    NSError *connectionError;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&connectionError];
    
    NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
    NSLog(@"%lu",(long)[r statusCode]);
    if (connectionError) {
        NSLog(@"%@",[connectionError localizedDescription]);
        return 0;
    }
    
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    if ([[d allKeys] containsObject:@"iAuthResult"] && [d[@"iAuthResult"] intValue] == 0)
        return 0;
        
    return [d[@"iPageCount"] intValue];
}

#pragma mark ------------- Book Registration

- (BOOL)isBookMarked:(File *)file {
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM BOOKMARKS WHERE FILE_ID='%d'",[file fileID]];
    NSArray *a = [SQLHelper execQuery:(char *)[sql UTF8String] useDB:"FILES"];
    
    if ([a count] == 1) {
        if ([a[0] intValue] == [file fileID]) {
            return YES;
        }
    }
    
    return NO;
}

- (NSData *)downloadPageData:(File *)file withPage:(int)page {
    if (![file canDownload]) return nil;
    if (!self.isOnline) return nil;
    
    NSData *data = [self registerAnyPage:file page:page];
    return data;
}

- (NSData *)downloadFirstPageOfFile:(File *)file {
    if (![file canDownload])
        return nil;
    
    if (!self.isOnline)
        return nil;
    
    return [self downloadPageData:file withPage:1];
}

- (NSData *)registerFirstPageOfImage:(File *)file {
    if (!self.isOnline)
        return nil;
    
    if (![file canDownload]) return nil;
    if (!self.isReachable) return nil;
    
    NSString *uuid = [[self readIdentificationFile] stringByAppendingString:[self returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *post = [NSString stringWithFormat:@"iRequestType=5&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@&strRequestData={\"folder_id\":%d,\"file_id\":%d,\"image_pageID\":1,\"is_origin\":1}",_username,_password,self.companyToken,uuid,[file folderID],[file fileID]];
    NSMutableURLRequest *request = [self createRequest:post];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    if (data == nil) return nil;
    
    NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    if ([[dict allKeys] containsObject:@"iAuthResult"]) {
        return nil;
    }
    
    [self deletePageFromTable:[NSString stringWithFormat:@"%d",[file fileID]] pageID:1];
    [self insertDataForFileAtPage:data fileid:[NSString stringWithFormat:@"%d",file.fileID] page:@"1"];
    return data;
}

- (NSData *)registerAnyPage:(File *)file page:(int)page {
    if (!self.isOnline)
        return nil;
    
    if (!self.isReachable) return nil;
    
    NSString *uuid = [[self readIdentificationFile] stringByAppendingString:[self returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *post = [NSString stringWithFormat:@"iRequestType=5&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@&strRequestData={\"folder_id\":%d,\"file_id\":%d,\"image_pageID\":%d}",_username,_password,self.companyToken,uuid,[file folderID],[file fileID],page];
    NSMutableURLRequest *request = [self createRequest:post];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    if ([[dict allKeys] containsObject:@"iAuthResult"]) {
        return nil;
    }
    
    [self deletePageFromTable:[NSString stringWithFormat:@"%d",[file fileID]] pageID:page];
    [self insertDataForFileAtPage:data fileid:[NSString stringWithFormat:@"%d",file.fileID] page:[NSString stringWithFormat:@"%d",page]];
    return data;
}

#pragma mark ------------- Networking

- (NSMutableURLRequest *)createRequest:(NSString *)data {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/terminal/operate",self.targetAddress]]];
    [request setHTTPMethod:@"POST"];
    
    NSData *postData = [data dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [request setHTTPBody:postData];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    return request;
}

#pragma mark --- Upload Image

- (BOOL)uploadImage:(NSData *)data folderID:(int)folderID fileName:(NSString *)fileName {
    if (!self.isOnline) {
        return NO;
    }
    
    if (!self.isReachable) return NO;
    
    @autoreleasepool {
        UIImage *i = [UIImage imageWithData:data];
        data = UIImageJPEGRepresentation(i, 0.1);
    }
    
    NSString *binary = [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    fileName = [fileName stringByAppendingString:@".jpg"];
    
    NSString *uuid = [[self readIdentificationFile] stringByAppendingString:[self returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *post = [NSString stringWithFormat:@"iRequestType=4&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@&strRequestData={\"folder_id\":%d, \"binary_file\":\"%@\", \"file_name\":\"%@\"}",_username,_password,self.companyToken,uuid,folderID,binary,fileName];
    NSMutableURLRequest *request = [self createRequest:post];
    
    NSError *error;
    NSData *dat = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
    if (error)
        return NO;
    
    if ([dat length] == 0 || dat == nil) return YES;

    id json = [NSJSONSerialization JSONObjectWithData:dat options:NSJSONReadingMutableLeaves error:nil];
    if ([json[@"iAuthResult"] intValue] == 4 || [json[@"iAuthResult"] intValue] == 0)
        return NO;
    return YES;
}

#pragma mark ------------- Download Book

/**
 *  Downloads PDF file via HTTPS from Application Server hosted on Amazon AWS Cloud Service
 *
 *  @param file     Object describing the file that exists on the Amazon AWS server
 *  @param delegate Object that implements the MBBDownloadController protocol used for status updates
 */
- (void)downloadFile:(File *)file delegate:(id<MBBDownloadController>)delegate {
    // check application and file status
    if (self.downloadInProgress || ![file canDownload] || !self.isOnline) {
        [delegate fileDownloadFinished:file successfull:NO];
        return;
    }
    
    // check network connectivity of device
    if (!self.isReachable) {
        self.downloadInProgress = NO;
        if ([self.delegate respondsToSelector:@selector(fileDownloadFinished:successfull:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FAIL", nil) message:NSLocalizedString(@"ERROR_HAPPENED", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE",nil) otherButtonTitles:nil] show];
                [self.delegate fileDownloadFinished:file successfull:NO];
            });
        }
        return;
    }
    
    // initialization
    self.delegate = delegate;
    self.downloadInProgress = YES;
    self.downloadProgress = 0;
    self.downloadQueue = [NSOperationQueue new];
    [self.downloadQueue setMaxConcurrentOperationCount:1];
    
    // notify listener that download has started
    if ([self.delegate respondsToSelector:@selector(fileDownloadStarted:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate fileDownloadStarted:file];
        });
    }
    
    // notify listener of initial download progress (0%)
    if ([self.delegate respondsToSelector:@selector(fileDownloadProgressChanged:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate fileDownloadProgressChanged:self.downloadProgress];
        });
    }
    
    // get page count of the file from Amazon AWS Cloud Server
    __block int pageCount = [self retrievePageCountForFile:file];
    if (pageCount == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FAIL", nil) message:NSLocalizedString(@"ERROR_HAPPENED", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE",nil) otherButtonTitles:nil] show];
            [self.delegate fileDownloadFinished:file successfull:NO];
        });
        return;
    }
    
    // runs the containing block code (downloads file) on a background thread
    // to allow main thread (UI thread) to display a progress bar
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        self.didDownload = YES;
        self.transCancelled = NO;
        
        // evaluate whether the first page that is displayed on the UI is out of sync
        NSData *firstPageData;
        if (![file isLatest] || [file fileCover] == nil || [UIImage imageWithData:[file fileCover]] == nil) {
            firstPageData = [self registerAnyPage:file page:1];
        }
        
        // wipe already stored data if already downloaded
        if ([file isDownloaded]) {
            [self removeFileFromSystemWithFileInformation:file];
        }
        
        // build a download operation for each page of the file and add to the downloadQueue
        // download operation calls downloadBookContentAndFinish: method
        for (int i = 2; i <= pageCount; i++) {
            NSArray *a = [NSArray arrayWithObjects:file,[NSString stringWithFormat:@"%d",i], nil];
            NSInvocationOperation *o = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(downloadBookContentAndFinish:) object:a];
            [self.downloadQueue addOperation:o];
            
            a = nil;
        }
        
        [self.downloadQueue waitUntilAllOperationsAreFinished];
        
        // if downloaded successfully
        if (self.didDownload && !self.transCancelled) {
            // update database to mark the file as downloaded
            NSString *sq = [NSString stringWithFormat:@"UPDATE CENTRAL SET ISDOWNLOADED=1 WHERE FILE_ID='%d'",[file fileID]];
            if (![SQLHelper execQuery:(char *)[sq UTF8String] useDB:"FILES"];) {
                [self.downloadQueue cancelAllOperations];
                self.didDownload = NO;
            } else {
                if ([self checkFileExtension:[file fileExtension]] && pageCount <= 0) {
                    pageCount = 1;
                }
                
                // update database with new file attributes
                NSString *sql = [NSString stringWithFormat:@"UPDATE CENTRAL SET MODIFY_DATE='%@', PAGECOUNT='%d' WHERE FILE_ID='%d'",[file modifyDate],pageCount,[file fileID]];
                if (![SQLHelper execQuery:(char *)[sql UTF8String] useDB:"FILES"];) {
                    [self.downloadQueue cancelAllOperations];
                    self.didDownload = NO;
                    goto escape;
                }
                
                // update the live object with new file attributes and commit the transaction
                if (firstPageData != nil && [firstPageData length] > 0)
                    [file setFileCover:firstPageData];
                    
                [file setPageCount:pageCount];
                [file setIsDownloaded:YES];
                [file setIsLatest:YES];
            }
        } else if (self.transCancelled) {
        
        }
        
    escape:
        
        // notify listener object of download finished
        self.downloadInProgress = NO;
        if ([self.delegate respondsToSelector:@selector(fileDownloadFinished:successfull:)]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.delegate fileDownloadFinished:file successfull:self.didDownload];
            });
        }
    });
}

/**
 *  Download specified page of PDF file via HTTPS from Amazon AWS Cloud Server
 *  For securty purposes, each page of the PDF file is converted to an image file on the server
 *
 *  @param doc Array where the first element is the File object and the second element is the page number
 */
- (void)downloadBookContentAndFinish:(NSArray *)doc {
    @autoreleasepool {
        File *file = [doc objectAtIndex:0];
        NSString *str = [NSString stringWithFormat:@"%d",file.fileID];
        
        // check device netowrk connectivity
        if (!self.isReachable) {
            [self showError];
            self.didDownload = NO;
            [self.downloadQueue cancelAllOperations];
            return;
        }
        
        // create network request
        NSString *uuid = [[self readIdentificationFile] stringByAppendingString:[self returnCurrentDate]];
        uuid = [uuid stringFromMD5];
        NSString *post = [NSString stringWithFormat:@"iRequestType=5&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@&strRequestData={\"folder_id\":%d,\"file_id\":%d,\"image_pageID\":%@}",
                          _username,_password,self.companyToken,uuid,[file folderID],[file fileID],doc[1]];
        NSMutableURLRequest *request = [self createRequest:post];
        
        NSError *error;
        NSURLResponse *response;
        // for memory management purposes, immediately deallocate all temporary objects after the block
        @autoreleasepool {
            // download JSON encoded image data
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
            
            // is download successful
            if (data && ![[dict allKeys] containsObject:@"iAuthResult"]) {
                if (![self insertDataForFileAtPage:data fileid:str page:doc[1]]) { // try to insert data into database
                    [self showError];
                    self.didDownload = NO;
                    [self.downloadQueue cancelAllOperations];
                }
            } else {
                [self showError];
                NSLog(@"Error when downloading book: %@",error);
                
                self.didDownload = NO;
                [self.downloadQueue cancelAllOperations];
                return;
            }
            
            data = nil;
        }
        
        // notify listener of download progress
        request = nil;
        self.downloadProgress = [doc[1] floatValue] / file.pageCount;
        NSLog(@"Writing : %d",[doc[1] intValue]);
        
        if ([self.delegate respondsToSelector:@selector(fileDownloadProgressChanged:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate fileDownloadProgressChanged:self.downloadProgress];
            });
        }
    }
}

- (void)showError {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FAIL", nil) message:NSLocalizedString(@"ERROR_HAPPENED", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"YES", nil) otherButtonTitles:nil] show];
    });
}

#pragma mark ------------- Insert + Get Data

- (BOOL)insertDataForFileAtPage:(NSData *)data fileid:(NSString *)fileid page:(NSString *)page {
    void *cfdata = (void *)[data bytes];
    
    mrdes *tab_desc = mropen("FILES","PAGES",'u');
    msbool          success;
    gen_binary      ins_blob;
    mrrdes*	rec_write_desc = mrmkrec(tab_desc);
    mrades* bin_info_attr_desc = mrngeta(tab_desc,"PAGE");
    success = true;
    
    ins_blob.num_segments = 1;
    ins_blob.flags = 0;
    ins_blob.total_data_len = ins_blob.segment[0].data_len = [data length];
    ins_blob.segment[0].data = cfdata;
    if (!mrputgi(rec_write_desc, bin_info_attr_desc, &ins_blob)) {
        NSLog(@"%s",mrerrmsg());
        success = false;
    }
    
    bin_info_attr_desc = mrngeta(tab_desc,"FILE_ID");
    if (!mrputvs(rec_write_desc, bin_info_attr_desc,[fileid UTF8String])) {
        NSLog(@"%s",mrerrmsg());
        success = false;
    }
    
    bin_info_attr_desc = mrngeta(tab_desc,"PAGE_NUMBER");
    if (!mrputvs(rec_write_desc, bin_info_attr_desc,[page UTF8String])) {
        NSLog(@"%s",mrerrmsg());
        success = false;
    }
    
    if (!mradd (rec_write_desc)) {
        NSLog(@"%s",mrerrmsg());
        success = false;
    }
    
    if (!mraddend (rec_write_desc)) {
        NSLog(@"%s",mrerrmsg());
        success = false;
    }
    
    if (!mrfrrec (rec_write_desc)) {
        NSLog(@"%s",mrerrmsg());
        success = false;
    }
    
    mrclose(tab_desc);
    cfdata = nil;
    return success;
}

#pragma mark ------------- Remove Book

- (void)removeFileFromSystemWithFileInformation:(File *)file {
    [self cleanEntries:file];
    [self deleteEverythingFromTableExceptOne:[NSString stringWithFormat:@"%d",[file fileID]]];
    
    if (![file isLatest]) {
        [file setFileCover:[self registerAnyPage:file page:1]];
        [file setIsLatest:YES];
    }
}

- (void)cleanEntries:(File *)file {
    NSString *sql = [NSString stringWithFormat:@"UPDATE CENTRAL SET ISDOWNLOADED TO False WHERE FILE_ID='%d'",[file fileID]];
    [SQLHelper executeSQL:(char*)[sql UTF8String] useDB:"FILES"];
    sql = [NSString stringWithFormat:@"DELETE FROM LASTOPEN WHERE FILE_ID='%d'",[file fileID]];
    [SQLHelper executeSQL:(char*)[sql UTF8String] useDB:"FILES"];
}

#pragma mark ------------- Delete Contents of DB

- (void)deleteEverythingFromTableExceptOne:(NSString *)file {
    mrdes*        tab_desc = mropen("FILES","PAGES",'u');
    mrades*       attrdesc;
    mrrdes*       record;
    mrqdes*       qual;
    mrqdes*       qual2;
    mrqdes*       combine;
    mrretrdes*    retrieve_desc;
    
    char *qua = "FILE_ID";
    
    record = mrmkrec(tab_desc);
    attrdesc = mrngeta(tab_desc,"PAGE_NUMBER");
    qual = mrqcon("!=",attrdesc,mrcvt(attrdesc,"1"));
    attrdesc = mrngeta(tab_desc,qua);
    qual2 = mrqcon("=",attrdesc,mrcvt(attrdesc,[file UTF8String]));
    combine = mrqand(qual,qual2);
    
    retrieve_desc = mrgetbegin(combine,record,NULL);
    while (mrget(retrieve_desc) == MSMR_GET_OK) {
        mrdel(record);
    }
    mrgetend(retrieve_desc);
    mrdelend(record);
    mrfrrec(record);
    mrclose(tab_desc);
}

- (void)deletePageFromTable:(NSString *)file pageID:(int)pageID {
    mrdes*        tab_desc = mropen("FILES","PAGES",'u');
    mrades*       attrdesc;
    mrrdes*       record;
    mrqdes*       qual;
    mrqdes*       qual2;
    mrqdes*       combine;
    mrretrdes*    retrieve_desc;
    
    char *qua = "FILE_ID";
    
    record = mrmkrec(tab_desc);
    attrdesc = mrngeta(tab_desc,"PAGE_NUMBER");
    
    char *c = (char*)[[NSString stringWithFormat:@"%d",pageID] UTF8String];
    qual = mrqcon("=",attrdesc,mrcvt(attrdesc,c));
    attrdesc = mrngeta(tab_desc,qua);
    qual2 = mrqcon("=",attrdesc,mrcvt(attrdesc,[file UTF8String]));
    combine = mrqand(qual,qual2);
    
    retrieve_desc = mrgetbegin(combine,record,NULL);
    while (mrget(retrieve_desc) == MSMR_GET_OK) {
        mrdel(record);
    }
    mrgetend(retrieve_desc);
    mrdelend(record);
    mrfrrec(record);
    mrclose(tab_desc);
}

#pragma mark --- Get Data

- (NSData *)getDataForPage:(NSString *)page fromFile:(File *)file {
    mrdes* tab_desc;
    mrrdes*	new_rec_desc;
    mrqdes* qual;
    mrretrdes*	ret;
    tab_desc = mropen("FILES","PAGES",'u');
    mrades* bin_info_attr_desc = mrngeta(tab_desc,"PAGE");
    new_rec_desc = mrmkrec (tab_desc);
    mrades* page_number = mrngeta(tab_desc,"PAGE_NUMBER");
    qual = mrqcon("=",page_number,mrcvt(page_number,[page UTF8String]));
    
    char *x = (char*)[[NSString stringWithFormat:@"%d",file.fileID] UTF8String];
    
    mrades* file_id = mrngeta(tab_desc,"FILE_ID");
    mrqdes* qual2 = mrqcon("=",file_id,mrcvt(file_id, x));
    mrqdes* combine = mrqand(qual,qual2);
    
    ret = mrgetbegin(combine,new_rec_desc,NULL);
    NSData *datay;
    if (mrget(ret) == MSMR_GET_OK) {
        unsigned char * bulk_ptr = (unsigned char*)mrgeti (new_rec_desc,bin_info_attr_desc);
        datay = [NSData dataWithBytes:bulk_ptr+sizeof(long) length:*(long*)bulk_ptr];
    }
    
    if (datay == nil) {
        if ([file canDownload] && self.isOnline) {
            NSData *data = [self downloadPageData:file withPage:[page intValue]];
            return data;
        }
    } else {
        NSLog(@"%s D",[page UTF8String]);
    }
    
    mrgetend(ret);
    mrfrrec(new_rec_desc);
    mrclose(tab_desc);
    return datay;
}

#pragma mark - Identification

- (NSString *)readIdentificationFile {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    documents = [documents stringByAppendingPathComponent:@"Identification"];
    return [[NSString alloc] initWithContentsOfFile:documents encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)returnCurrentDate {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSURL *doc = [NSURL fileURLWithPath:documents];
    doc = [doc URLByAppendingPathComponent:@"Mobisec"];
    doc = [doc URLByAppendingPathComponent:@"Identification"];
    
    NSDate *fileDate;
    NSError *error;
    if (![doc getResourceValue:&fileDate forKey:NSURLContentModificationDateKey error:&error]) {
        NSLog(@"%@",error);
        return @"";
    }
    
    if (error) { NSLog(@"%@",error); return @""; }
    return [NSString stringWithFormat:@"%@",fileDate];
}

@end