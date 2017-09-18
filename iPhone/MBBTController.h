//
//  MBBTController.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBBController.h"
#import "AuthViewController.h"

#import "SWTableViewCell.h"
#import "NSMutableArray+SWUtilityButtons.h"
#import "InfoTVC.h"

#import "ELCImagePickerHeader.h"
#import "ELCImagePickerController.h"

@protocol BookmarkGoing <NSObject>
- (void)bookmarkGoing;
@end

@interface MBBTController : UITableViewController <MBBDownloadController,AuthenticationFinished,SWTableViewCellDelegate,BookmarkGoing,InfoDismissing, UIAlertViewDelegate,ELCImagePickerControllerDelegate>

@property (nonatomic, strong) NSMutableArray *storageObjects;
@property (nonatomic, strong) NSMutableArray *folderObjects;
@property (nonatomic, strong) NSMutableArray *fileObjects;

@property (nonatomic) BOOL folderEmpty;
@property (nonatomic) BOOL fileEmpty;

@property (nonatomic, assign) id<BookmarkGoing> delegate;

@property (nonatomic, assign) int displayID;
@property (nonatomic, assign) BOOL isDisplayingBookmarks;

- (void)performLogin;

@end
