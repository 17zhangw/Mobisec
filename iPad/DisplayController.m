//
//  DisplayController.m
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import "DisplayController.h"
#import "AuthViewController.h"
#import "iOSBlocks.h"

#import "MBBController.h"
#import "MBProgressHUD.h"
#import "ReadVC.h"
#import "SQLHelper.h"

#import "AppDelegate.h"
#import "MBBFolderCell.h"
#import "MBBCollectionCell.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <objc/runtime.h>

@interface DisplayController ()
@property (nonatomic, strong) MBProgressHUD *progressHUD;
@property (nonatomic) NSData *selectedData;

@property (nonatomic) NSArray *photosLocation;
@property (nonatomic) int uploadFolderTempID;
@property (nonatomic) BOOL didUpload;

@property (nonatomic) int popoverFileIndex;
@end

@implementation DisplayController
static char key;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didPopToRootController {
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([self.navigationController isToolbarHidden]) {
        [self.navigationController setToolbarHidden:NO];
    }
    
    if (!self.isDisplayingBookmarks) {
        SEL sel = @selector(showBookmarks);
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:sel];
        self.navigationItem.rightBarButtonItem = item;
        
        if ([[MBBController sharedManager] isOnline]) {
            SEL se = @selector(addPicture);
            UIBarButtonItem *ite = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:se];
            self.toolbarItems = @[ite];
            
            if ([self.navigationItem leftBarButtonItem] == nil && [[self.navigationItem title] isEqualToString:NSLocalizedString(@"ROOT", nil)] && self.displayID == 0) {
                UIBarButtonItem *i = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
                [self.navigationItem setLeftBarButtonItem:i];
            }
        } else {
            [self.navigationItem setLeftBarButtonItem:nil];
            
            SEL se = @selector(moveOnline);
            UIBarButtonItem *ite = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"MOVE_ONLINE", nil) style:UIBarButtonItemStyleBordered target:self action:se];
            self.toolbarItems = @[ite];
        }
    }
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGesture:)];
    [lpgr setNumberOfTouchesRequired:1];
    [lpgr setMinimumPressDuration:0.5];
    [lpgr setDelaysTouchesBegan:YES];
    [lpgr setDelegate:self];
    [self.collectionView addGestureRecognizer:lpgr];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (![[MBBController sharedManager] isAuthenticated]) {
        [[MBBController sharedManager] setDidLoad:YES];
        [[MBBController sharedManager] performLogin];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addPicture {
    if (![[MBBController sharedManager] isOnline])
        return;
    
    if ([self analyzeFolderContentsForIncompleteDownload]) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPLOADING", nil) message:NSLocalizedString(@"INCOMPLETE_UPLOAD", nil)
                                   delegate:self cancelButtonTitle:NSLocalizedString(@"DELETE", nil) otherButtonTitles:NSLocalizedString(@"UPLOAD", nil), nil] show];
        return;
    }
    
    if ([[self.navigationItem title] isEqualToString:NSLocalizedString(@"ROOT", nil)] && self.displayID == 0) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"BAD_LOCATION", nil) message:NSLocalizedString(@"BAD_LOC_REASON", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE", nil) otherButtonTitles:nil] show];
        return;
    }
    
    self.uploadFolderTempID = -1;
    ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];
    [elcPicker setMaximumImagesCount:100];
    [elcPicker setReturnsOriginalImage:YES];
    [elcPicker setReturnsImage:YES];
    [elcPicker setOnOrder:YES];
    [elcPicker setMediaTypes:@[(NSString *)kUTTypeImage]];
    [elcPicker setImagePickerDelegate:self];
    [self presentViewController:elcPicker animated:YES completion:nil];
}

#pragma mark --- Did Pick Picture

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info {
    [self dismissViewControllerAnimated:YES completion:^{
        if ([info count] > 0) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"NAME_SET", nil) message:NSLocalizedString(@"ENTER_NAME", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"CANCEL", nil) otherButtonTitles:NSLocalizedString(@"ENTER", nil), nil];
            [a setAlertViewStyle:UIAlertViewStylePlainTextInput];
            
            objc_setAssociatedObject(a, &key, info, OBJC_ASSOCIATION_RETAIN);
            [a show];
        }
    }];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([[alertView title] isEqualToString:NSLocalizedString(@"NAME_SET", nil)] && [alertView cancelButtonIndex] != buttonIndex) {
        [[self.navigationItem rightBarButtonItem] setEnabled:NO];
        [self.navigationItem setHidesBackButton:YES];
        [[self toolbarItems][0] setEnabled:NO];
        
        NSString *fileName = [[alertView textFieldAtIndex:0] text];
        [self.view setUserInteractionEnabled:NO];
        self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        MBProgressHUD *hud = self.progressHUD;
        [hud setMode:MBProgressHUDModeIndeterminate];
        [hud setLabelText:NSLocalizedString(@"PROCESSING", nil)];
        [hud setTag:101];
        
        NSArray *info = objc_getAssociatedObject(alertView, &key);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self processPickedImages:info fileName:fileName];
        });
    } else if ([[alertView title] isEqualToString:NSLocalizedString(@"UPLOADING", nil)] && [alertView cancelButtonIndex] != buttonIndex) {
        self.uploadFolderTempID = -1;
        [[self.navigationItem rightBarButtonItem] setEnabled:NO];
        [[self.navigationItem leftBarButtonItem] setEnabled:NO];
        [self.navigationItem setHidesBackButton:YES];
        [[self toolbarItems][0] setEnabled:NO];
        [self.view setUserInteractionEnabled:NO];
        self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        MBProgressHUD *hud = self.progressHUD;
        [hud setMode:MBProgressHUDModeIndeterminate];
        [hud setLabelText:NSLocalizedString(@"UPLOADING", nil)];
        [hud setTag:101];
        
        [[MBBController sharedManager] setShouldCancel:NO];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [[MBBController sharedManager] batchUploadImages];
        });
    } else if ([[alertView title] isEqualToString:NSLocalizedString(@"UPLOAD_FAIL", nil)] || [[alertView title] isEqualToString:NSLocalizedString(@"UPLOAD_SUCCEED", nil)]) {
        self.uploadFolderTempID = -1;
        [self hideHUDView];
        
        DisplayController *c = (DisplayController *)[self.navigationController viewControllers][0];
        if ([[[self navigationItem] title] isEqualToString:NSLocalizedString(@"ROOT", nil)] && self.displayID == 0) {
            [self refresh:nil];
        } else {
            [self.navigationController popToRootViewControllerAnimated:YES onCompletion:^{
                [c refresh:nil];
            }];
        }
    } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"NOT", nil)]) {
    } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"DELETE", nil)]) {
        [self deleteAllPhotos];
        [self hideHUDView];
        
        [[self.navigationItem rightBarButtonItem] setEnabled:YES];
        [self.navigationItem setHidesBackButton:NO];
        [[self toolbarItems][0] setEnabled:YES];
        [self.view setUserInteractionEnabled:YES];
        [[self.navigationItem leftBarButtonItem] setEnabled:YES];
    } else {
        [self hideHUDView];
        
        [[self.navigationItem rightBarButtonItem] setEnabled:YES];
        [self.navigationItem setHidesBackButton:NO];
        [[self toolbarItems][0] setEnabled:YES];
        [self.view setUserInteractionEnabled:YES];
        [[self.navigationItem leftBarButtonItem] setEnabled:YES];
        [self deletePhotoDirectory];
    }
}

- (void)deleteAllPhotos {
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documentPath = [documentPath stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documentPath];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *photo = [documentPath stringByAppendingPathComponent:@"PHOTOS"];
    [[NSFileManager defaultManager] removeItemAtPath:photo error:nil];
    self.uploadFolderTempID = -1;
}

- (void)deletePhotoDirectory {
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documentPath = [documentPath stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documentPath];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *photoDirectory = [[documentPath stringByAppendingPathComponent:@"PHOTOS"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%d",self.uploadFolderTempID]];
    [[NSFileManager defaultManager] removeItemAtPath:photoDirectory error:nil];
    self.uploadFolderTempID = -1;
}

- (void)processPickedImages:(NSArray *)imageInformation fileName:(NSString *)fileName {
    int folderID = 0;
    NSArray *docObjects = [self collectionOfDocobjects];
    if ([docObjects count] > 0) {
        id o = [self collectionOfDocobjects][0];
        if ([o isKindOfClass:[File class]])
            folderID = [(File *)o folderID];
        else if ([o isKindOfClass:[Folder class]])
            folderID = [(Folder *)o parentID];
    } else {
        folderID = [self displayID];
    }
    
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documentPath = [documentPath stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documentPath];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *photoDirectory = [[documentPath stringByAppendingPathComponent:@"PHOTOS"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%d",folderID]];
    BOOL *isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:photoDirectory isDirectory:isDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:photoDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    for (NSDictionary *dict in imageInformation) {
        UIImage *image = dict[UIImagePickerControllerOriginalImage];
        NSInteger index = [imageInformation indexOfObject:dict] + 1;
        
        NSString *file = [NSString stringWithFormat:@"%@-%d",fileName,index];
        NSString *path = [photoDirectory stringByAppendingPathComponent:file];
        [UIImagePNGRepresentation(image) writeToFile:path atomically:NO];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideHUDView];
        
        self.uploadFolderTempID = folderID;
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPLOADING", nil) message:NSLocalizedString(@"UPLOAD_WARNING", nil)
                                  delegate:self cancelButtonTitle:NSLocalizedString(@"DELETE", nil) otherButtonTitles:NSLocalizedString(@"UPLOAD", nil), nil] show];
    });
}

- (void)batchUploadAccomplished:(BOOL)successful error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *n = (UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController];
        if ([[n topViewController] isKindOfClass:[DisplayController class]]) {
            [self hideHUDView];
            if (error) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPLOAD_FAIL", nil) message:[error localizedDescription] delegate:self cancelButtonTitle:NSLocalizedString(@"RELOAD", nil) otherButtonTitles:nil] show];
                return;
            }
            
            if (successful) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPLOAD_SUCCEED", nil) message:[error localizedDescription] delegate:self cancelButtonTitle:NSLocalizedString(@"RELOAD", nil) otherButtonTitles:nil] show];
            }
        } else {
            [self hideHUDView];
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPLOAD_CUT", nil) message:NSLocalizedString(@"UPLOAD_CUT_REASON", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"YES", nil) otherButtonTitles:nil] show];
        }
    });
}

#pragma mark - Image Selection

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = info[UIImagePickerControllerEditedImage];
    self.selectedData = [NSData dataWithData:UIImagePNGRepresentation(chosenImage)];
    [picker dismissViewControllerAnimated:YES completion:^{
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"NAME_SET", nil) message:NSLocalizedString(@"ENTER_NAME", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"CANCEL", nil) otherButtonTitles:NSLocalizedString(@"ENTER", nil), nil];
        [a setAlertViewStyle:UIAlertViewStylePlainTextInput];
        [a show];
    }];
}

#pragma mark --- Online

- (void)moveOnline {
    [[MBBController sharedManager] moveOnline];
    [[MBBController sharedManager] setLoginFrequency:LF_EVERY_RESUME_FROM_BACKGROUND];
    
    if ([[self.navigationItem title] isEqualToString:NSLocalizedString(@"ROOT", nil)] && self.displayID == 0) {
        [self performLog];
        return;
    }
    
    DisplayController *c = (DisplayController *)[self.navigationController viewControllers][0];
    [self.navigationController popToRootViewControllerAnimated:YES onCompletion:^{
        [c performLog];
    }];
}

- (void)performLog {
    [[MBBController sharedManager] setIsAuthenticated:NO];
    [[MBBController sharedManager] setDidLoad:YES];
    [[MBBController sharedManager] performLogin];
}

- (void)performLogin {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard-iPad" bundle:nil];
    AuthViewController *auth = (AuthViewController *)[storyboard instantiateViewControllerWithIdentifier:@"Auth"];
    [auth setDelegate:self];
    [self.navigationController pushViewController:auth animated:YES];
}

#pragma mark - Authentication Finished

- (void)didLoadLoginFinished {
    self.folderEmpty = YES;
    self.fileEmpty = YES;
    [self setStorageObjects:[[MBBController sharedManager] treeList]];
    if ([self.navigationController isToolbarHidden]) {
        [self.navigationController setToolbarHidden:NO];
    }
    
    [self arrangeCollectionView:[[UIApplication sharedApplication] statusBarOrientation]];
    [self.collectionView reloadData];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self analyzeFolderContentsForIncompleteDownload]) {
            [self askReupload];
        }
    });
}

- (void)didReturnLoginFinished {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.navigationController isToolbarHidden]) {
            [self.navigationController setToolbarHidden:NO];
        }
        [self.view setUserInteractionEnabled:YES];
        [self.navigationItem setHidesBackButton:NO];
        
        if ([self analyzeFolderContentsForIncompleteDownload]) {
            [self askReupload];
        }
    });
}

- (void)askReupload {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPLOADING", nil) message:NSLocalizedString(@"UNFINISHED_UPLOAD", nil)
                               delegate:self cancelButtonTitle:NSLocalizedString(@"NO", nil) otherButtonTitles:NSLocalizedString(@"UPLOAD", nil), nil] show];
}

- (BOOL)analyzeFolderContentsForIncompleteDownload {
    if ([[MBBController sharedManager] isUploading] || ![[MBBController sharedManager] isOnline])
        return NO;
    
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documentPath = [documentPath stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documentPath];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *photoDirectory = [documentPath stringByAppendingPathComponent:@"PHOTOS"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:photoDirectory]) return NO;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:photoDirectory error:nil];
    
    BOOL isDirectory;
    for (NSString *loc in contents) {
        NSString *nDir = [photoDirectory stringByAppendingPathComponent:loc];
        NSArray *locContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:nDir error:nil];
        for (NSString * s in locContents) {
            NSString *sDir = [nDir stringByAppendingPathComponent:s];
            BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:sDir isDirectory:&isDirectory];
            if (exist && !isDirectory) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)removeHUD {
    [self hideHUDView];
}

#pragma mark - Show Bookmarks

- (void)showBookmarks {
    [[MBBController sharedManager] rebootEmpress];
    NSMutableArray *files = [NSMutableArray array];
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM BOOKMARKS"];
    
    NSArray *results = [SQLHelper execQuery:(char *)[sql UTF8String] useDB:"FILES"];
    if (results) {
        for (NSString *a in results) {
            if ([a length] == 0) {
                return;
            }
            
            NSInteger index = [a integerValue];
            for (id o in [[MBBController sharedManager] treeList]) {
                if ([o isKindOfClass:[File class]]) {
                    if ([(File *)o fileID] == index) {
                        [files addObject:o];
                    }
                } else {
                    [self searchFolderForFiles:files folder:o fileid:index];
                }
            }
        }
        
        [[MBBController sharedManager] setDelegate:nil];
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard-iPad" bundle:nil];
        DisplayController *display = (DisplayController *)[storyboard instantiateViewControllerWithIdentifier:@"Display"];
        [display setIsDisplayingBookmarks:YES];
        
        [display setFolderEmpty:YES];
        [display setFileEmpty:YES];
        [display setStorageObjects:files];
        [display setTitle:NSLocalizedString(@"BOOKMARK", nil)];
        [display setBookmarkDelegate:self];
        [[MBBController sharedManager] setDelegate:display];
        
        [self.navigationController pushViewController:display animated:YES];
    }
    
    return;
}

- (void)searchFolderForFiles:(NSMutableArray *)a folder:(Folder *)f fileid:(NSInteger)index {
    for (id o in [f children]) {
        if ([o isKindOfClass:[File class]]) {
            if ([(File *)o fileID] == index) {
                [a addObject:o];
            }
        } else {
            [self searchFolderForFiles:a folder:o fileid:index];
        }
    }
}

#pragma mark - Collection

- (NSArray *)collectionOfDocobjects {
    return self.storageObjects;
}

#pragma mark --- Refresh

- (IBAction)refresh:(id)sender {
    if (![[MBBController sharedManager] isOnline]) {
        return;
    }
    
    [[self.navigationItem rightBarButtonItem] setEnabled:NO];
    [[self.navigationItem leftBarButtonItem] setEnabled:NO];
    [[self toolbarItems][0] setEnabled:NO];
    
    [self.view setUserInteractionEnabled:NO];
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    MBProgressHUD *hud = self.progressHUD;
    [hud setMode:MBProgressHUDModeIndeterminate];
    [hud setLabelText:NSLocalizedString(@"RETRIEVING_LIST", nil)];
    [hud setTag:101];
    
    [[MBBController sharedManager] downloadTheTreeListStoreLocalCompletionHandler:^(NSMutableArray *downloadObjects) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDView];
            
            if (downloadObjects == nil) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"REFRESH", nil) message:NSLocalizedString(@"RETRIEVE_FAIL", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE", nil) otherButtonTitles:nil] show];
                [[self.navigationItem rightBarButtonItem] setEnabled:YES];
                [[self.navigationItem leftBarButtonItem] setEnabled:YES];
                [[self toolbarItems][0] setEnabled:YES];
                
                [self.view setUserInteractionEnabled:YES];
                return;
            }
            
            [[self.navigationItem rightBarButtonItem] setEnabled:YES];
            [[self.navigationItem leftBarButtonItem] setEnabled:YES];
            [[self toolbarItems][0] setEnabled:YES];
            
            [self.view setUserInteractionEnabled:YES];
            
            self.folderEmpty = YES;
            self.fileEmpty = YES;
            [self setStorageObjects:[[MBBController sharedManager] treeList]];
            [self.collectionView reloadData];
        });
    }];
}

- (void)hideHUDView {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            self.progressHUD = nil;
        });
    }
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.progressHUD = nil;
}

#pragma mark --- Selection

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (_actionControllerPopover || _infoControllerPopover)
        return;
    
    id file;
    BOOL isFolderEmpty = [self.folderObjects count] == 0;
    BOOL isFileEmpty = [self.fileObjects count] == 0;
    
    if ((!isFolderEmpty && !isFileEmpty && [indexPath section] == 0) || (!isFolderEmpty && isFileEmpty)) {
        file = self.folderObjects[[indexPath row]];
    } else if ((!isFolderEmpty && !isFileEmpty && [indexPath section] == 1) || (!isFileEmpty && isFolderEmpty)) {
        file = self.fileObjects[[indexPath row]];
    }
    
    if ([file isKindOfClass:[File class]]) {
        if ([file isDownloaded]) {
            [self openFileForReading:file];
        } else if ([[MBBController sharedManager] checkFileExtension:[file fileExtension]]) {
            [self openFileForReading:file];
        } else if ([file canDownload] && [[MBBController sharedManager] isOnline]) {
            [self initiateDownloadStart:file];
        }
    } else if ([file isKindOfClass:[Folder class]]) {
        Folder *folder = file;
        
        [[MBBController sharedManager] setDelegate:nil];
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard-iPad" bundle:nil];
        DisplayController *display = (DisplayController *)[storyboard instantiateViewControllerWithIdentifier:@"Display"];
        
        [display setFolderEmpty:YES];
        [display setFileEmpty:YES];
        [display setStorageObjects:[folder children]];
        [display setTitle:[folder folderName]];
        [display setDisplayID:[folder folderID]];
        [[MBBController sharedManager] setDelegate:display];
        
        [self.navigationController pushViewController:display animated:YES];
    }
}

- (void)initiateDownloadStart:(File *)file {
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    MBProgressHUD *hud = self.progressHUD;
    [hud setMode:MBProgressHUDModeAnnularDeterminate];
    [hud setLabelText:NSLocalizedString(@"DOWNLOADING", nil)];
    [hud setTag:101];
    
    [self.view setUserInteractionEnabled:NO];
    [[self.navigationItem rightBarButtonItem] setEnabled:NO];
    [self.toolbarItems[0] setEnabled:NO];
    
    [self.navigationItem setHidesBackButton:YES];
    [[MBBController sharedManager] downloadFile:file delegate:self];
}
                                          
- (void)longPressGesture:(UILongPressGestureRecognizer *)sender {
    if ([sender state] != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint p = [sender locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:p];
    MBBCollectionCell *cell = (MBBCollectionCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:[MBBFolderCell class]]) return;
    if (cell == nil) return;
    
    File *item;
    int search = [cell tag];
    for (id file in self.fileObjects) {
        if ([file isKindOfClass:[File class]]) {
            if ([file fileID] == search) {
                item = file;
                break;
            }
        }
    }
    
    UIStoryboard *main = [UIStoryboard storyboardWithName:@"Storyboard-iPad" bundle:nil];
    if (_actionController == nil) {
        _actionController = [main instantiateViewControllerWithIdentifier:@"action"];
    }
    if (_actionControllerPopover == nil) {
        _actionControllerPopover = [[UIPopoverController alloc] initWithContentViewController:_actionController];
        _actionControllerPopover.delegate = self;
        _popoverFileIndex = [indexPath row];
        
        [_actionControllerPopover presentPopoverFromRect:[self.view convertRect:cell.imageCover.frame fromView:cell]
                                                inView:self.view
                              permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        
        if (![item isDownloaded]) {
            [[_actionController remove] setEnabled:NO];
        } else {
            [[_actionController remove] setTag:[cell tag]];
            [[_actionController remove] addTarget:self
                                           action:@selector(removeFileFromSystem:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        if ([item isBookmarked]) {
            [[_actionController bookmark] setTitle:NSLocalizedString(@"DELETE_BOOKMARK", nil) forState:UIControlStateNormal];
            [[_actionController bookmark] setTag:[cell tag]];
            [[_actionController bookmark] addTarget:self action:@selector(unbookmark:) forControlEvents:UIControlEventTouchUpInside];
        } else {
            [[_actionController bookmark] setTag:[cell tag]];
            [[_actionController bookmark] addTarget:self
                                             action:@selector(bookmark:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        [[_actionController info] setTag:[cell tag]];
        [[_actionController info] addTarget:self action:@selector(infoPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)infoPressed:(UIButton *)button {
    int popover = _popoverFileIndex;
    [_actionControllerPopover dismissPopoverAnimated:YES];
    [self popoverControllerDidDismissPopover:_actionControllerPopover];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:popover inSection:self.folderEmpty ? 0 : 1];
    MBBCollectionCell *cell = (MBBCollectionCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    int search = [button tag];
    File * item;
    for (id file in self.fileObjects) {
        if ([file isKindOfClass:[File class]]) {
            if ([file fileID] == search) {
                item = file;
                break;
            }
        }
    }
    File * file = item;
    
    UIStoryboard *main = [UIStoryboard storyboardWithName:@"Storyboard-iPad" bundle:nil];
    if (_infoController == nil) {
        _infoController = [main instantiateViewControllerWithIdentifier:@"info"];
        [_infoController loadView];
    }
    if (_infoControllerPopover == nil) {
        _infoControllerPopover = [[UIPopoverController alloc] initWithContentViewController:_infoController];
        _infoControllerPopover.delegate = self;
        _popoverFileIndex = [indexPath row];
        
        CGRect x = [self.view convertRect:cell.imageCover.frame fromView:cell];
        [_infoControllerPopover presentPopoverFromRect:x
                                                inView:self.view
                              permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        File *f = (File *)file;
        [[_infoController fileName] setText:[f fileName]];
        [[_infoController fileExplanation] setText:[f fileDescription]];
        if ([f pageCount] > 0)
            [[_infoController pageCount] setText:[NSString stringWithFormat:@"%d",[f pageCount]]];
        [[_infoController fileSize] setText:[f fileSize]];
        [[_infoController fileExtension] setText:[f fileExtension]];
        
        [[_infoController fileCreation] setText:[[MBBController sharedManager] localizeDate:[f createDate]]];
        [[_infoController fileModify] setText:[[MBBController sharedManager] localizeDate:[f modifyDate]]];
    }
}

- (void)removeFileFromSystem:(id)sender {
    [_actionControllerPopover dismissPopoverAnimated:YES];
    [self popoverControllerDidDismissPopover:_actionControllerPopover];
    
    UIButton *b = (UIButton *)sender;
    int search = [b tag];
    File * item;
    for (id file in self.fileObjects) {
        if ([file isKindOfClass:[File class]]) {
            if ([file fileID] == search) {
                item = file;
                break;
            }
        }
    }
    
    File *file = item;
    [[MBBController sharedManager] rebootEmpress];
    [[MBBController sharedManager] removeFileFromSystemWithFileInformation:file];
    [file setIsDownloaded:NO];
    [file setIsLatest:YES];
}

- (void)unbookmark:(UIButton *)b {
    [_actionControllerPopover dismissPopoverAnimated:YES];
    [self popoverControllerDidDismissPopover:_actionControllerPopover];
    
    int search = [b tag];
    File * item;
    for (id file in self.fileObjects) {
        if ([file isKindOfClass:[File class]]) {
            if ([file fileID] == search) {
                item = file;
                break;
            }
        }
    }
    File *file = item;
    [file setIsBookmarked:NO];
    
    [[MBBController sharedManager] rebootEmpress];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM BOOKMARKS WHERE FILE_ID='%d'",[file fileID]];
    if (![SQLHelper executeSQL:(char *)[sql UTF8String] useDB:"FILES"])
        return;
}

- (void)bookmark:(UIButton *)b {
    [_actionControllerPopover dismissPopoverAnimated:YES];
    [self popoverControllerDidDismissPopover:_actionControllerPopover];
    
    int search = [b tag];
    File * item;
    for (id file in self.fileObjects) {
        if ([file isKindOfClass:[File class]]) {
            if ([file fileID] == search) {
                item = file;
                break;
            }
        }
    }
    File *file = item;
    [file setIsBookmarked:YES];
    
    [[MBBController sharedManager] rebootEmpress];
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO BOOKMARKS VALUES ('%d')",[file fileID]];
    if (![SQLHelper executeSQL:(char *)[sql UTF8String] useDB:"FILES"])
        return;
}

#pragma mark --- Popover

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.infoController = nil;
    self.infoControllerPopover = nil;
    self.actionController = nil;
    self.actionControllerPopover = nil;
    _popoverFileIndex = -1;
}

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView *__autoreleasing *)view {
    if (_popoverFileIndex > -1) {
        NSIndexPath *i = [NSIndexPath indexPathForItem:_popoverFileIndex inSection:self.folderEmpty ? 0 : 1];
        MBBCollectionCell *cell = (MBBCollectionCell *)[self.collectionView cellForItemAtIndexPath:i];
        *rect = [cell convertRect:cell.imageCover.frame toView:self.view];
    }
    
    *view = self.view;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (_popoverFileIndex > -1) {
        NSIndexPath *i = [NSIndexPath indexPathForItem:_popoverFileIndex inSection:self.folderEmpty ? 0 : 1];
        MBBCollectionCell *cell = (MBBCollectionCell *)[self.collectionView cellForItemAtIndexPath:i];
        CGRect r = [cell convertRect:cell.imageCover.frame toView:self.view];
        if (_actionControllerPopover) {
            [_actionControllerPopover presentPopoverFromRect:r inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        } else if (_infoControllerPopover) {
            [_infoControllerPopover presentPopoverFromRect:r inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
    }
}

#pragma mark --- Pressed

- (void)downloadPressed:(UIButton *)button touch:(id)event {
    if (![[MBBController sharedManager] isOnline])
        return;

    int search = [[[button superview] superview] tag];
    File * item;
    for (id file in self.fileObjects) {
        if ([file isKindOfClass:[File class]]) {
            if ([file fileID] == search) {
                item = file;
                break;
            }
        }
    }
    [self initiateDownloadStart:item];
}

- (void)updateDataPressed:(UIButton *)button touch:(id)event {
    if (![[MBBController sharedManager] isOnline])
        return;

    int search = [[[button superview] superview] tag];
    File * item;
    for (id file in self.fileObjects) {
        if ([file isKindOfClass:[File class]]) {
            if ([file fileID] == search) {
                item = file;
                break;
            }
        }
    }
    [self initiateDownloadStart:item];
}

#pragma mark --- Open File for reading

- (void)openFileForReading:(File *)file {
    UIStoryboard *storybaord = [UIStoryboard storyboardWithName:@"Storyboard-iPad" bundle:nil];
    ReadVC *readVC = (ReadVC *)[storybaord instantiateViewControllerWithIdentifier:@"Read"];
    [readVC setFile:file];
    [self.navigationController pushViewController:readVC animated:YES];
}

#pragma mark --- Download Delegate

- (void)fileDownloadProgressChanged:(CGFloat)updatedPercentage {
    [self.progressHUD setProgress:updatedPercentage];
}

- (void)fileDownloadFinished:(File *)file successfull:(BOOL)isSuccessful {
    [self.view setUserInteractionEnabled:YES];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.progressHUD = nil;
    
    [[self.navigationItem rightBarButtonItem] setEnabled:YES];
    [self.navigationItem setHidesBackButton:NO];
    [self.toolbarItems[0] setEnabled:YES];
    
    if (isSuccessful) {
        [self arrangeCollectionView:[[UIApplication sharedApplication] statusBarOrientation]];
        
        int index = -1;
        for (id o in self.fileObjects) {
            if ([o isKindOfClass:[File class]]) {
                if ([o fileID] == [file fileID]) {
                    index = [self.fileObjects indexOfObject:o];
                    [o setIsLatest:YES];
                    [o setIsDownloaded:YES];
                }
            }
        }
        
        if (index >= 0) {
            NSInteger section = 1;
            if (self.folderEmpty || self.fileEmpty) {
                section = 0;
            }
            
            [file setIsLatest:YES];
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:section];
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        }
        
        return;
    }
}

#pragma mark --- Display

- (void)childGoingToDismiss { }

- (void)reloadTheData {
    [self.collectionView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {    
    if ([[self title] isEqualToString:NSLocalizedString(@"BOOKMARK", nil)]) {
        [self.bookmarkDelegate bookmarkGoing];
    }
}

- (void)viewDidDisappear:(BOOL)animated { }

- (void)bookmarkGoing {

}

@end
