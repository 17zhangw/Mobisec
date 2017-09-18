//
//  DisplayController.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "MBBCollectionViewController.h"
#import "AuthViewController.h"
#import "ELCImagePickerController.h"

#import "InfoController.h"
#import "ActionController.h"

@protocol BookmarkDelegate <NSObject>
- (void)bookmarkGoing;
@end;

@interface DisplayController : MBBCollectionViewController <AuthenticationFinished, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, ELCImagePickerControllerDelegate, UIPopoverControllerDelegate, BookmarkDelegate,UIGestureRecognizerDelegate>

@property (nonatomic, strong) InfoController *infoController;
@property (nonatomic, strong) ActionController *actionController;
@property (nonatomic, strong) UIPopoverController *infoControllerPopover;
@property (nonatomic, strong) UIPopoverController *actionControllerPopover;

@property (nonatomic, assign) id<BookmarkDelegate> bookmarkDelegate;

- (void)childGoingToDismiss;
- (IBAction)refresh:(id)sender;
- (void)reloadTheData;
- (void)didPopToRootController;

- (void)performLogin;
- (void)removeHUD;

@property (nonatomic, assign) int displayID;
@property (nonatomic, assign) BOOL isDisplayingBookmarks;

@end
