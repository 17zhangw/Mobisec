//
//  MBBTController.m
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "MBBTController.h"
#import "MBBTCell.h"
#import "SQLHelper.h"

#import "MBProgressHUD.h"
#import "iOSBlocks.h"
#import "ReadVC.h"

#import <MobileCoreServices/UTCoreTypes.h>
#import <objc/runtime.h>

@interface MBBTController ()
@property (nonatomic, strong) MBProgressHUD *progressHUD;
@property (nonatomic, weak) SWTableViewCell *tableCell;

@property (nonatomic, weak) NSIndexPath *cachedIndexPath;
@property (nonatomic) int uploadFolderTempID;
@property (nonatomic) NSData *selectedData;
@end

@implementation MBBTController
static char key;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[MBBController sharedManager] setDelegate:self];
    [self.tableView registerNib:[UINib nibWithNibName:@"MBBTCell" bundle:nil] forCellReuseIdentifier:@"mbbtcell"];
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
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setStorageObjects:(NSMutableArray *)storageObjects {
    _storageObjects = storageObjects;
    
    _folderObjects = [NSMutableArray array];
    _fileObjects = [NSMutableArray array];
    for (id obj in _storageObjects) {
        if ([obj isKindOfClass:[Folder class]]) {
            [_folderObjects addObject:obj];
            _folderEmpty = NO;
        } else if ([obj isKindOfClass:[File class]]) {
            [_fileObjects addObject:obj];
            _fileEmpty = NO;
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (![[MBBController sharedManager] isAuthenticated]) {
        [[MBBController sharedManager] setDidLoad:YES];
        [[MBBController sharedManager] performLogin];
    }
}

#pragma mark - Control

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

#pragma mark - Custom Actions

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
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard-iPhone" bundle:nil];
        MBBTController *display = (MBBTController *)[storyboard instantiateViewControllerWithIdentifier:@"mbbtcontroller"];
        [display setIsDisplayingBookmarks:YES];
        [display setDelegate:self];
        
        [display setFolderEmpty:YES];
        [display setFileEmpty:YES];
        [display setStorageObjects:files];
        [display setTitle:NSLocalizedString(@"BOOKMARK", nil)];
        [[MBBController sharedManager] setDelegate:display];
        
        [self.navigationController pushViewController:display animated:YES];
    }
    
    return;
}

- (void)moveOnline {
    [[MBBController sharedManager] moveOnline];
    [[MBBController sharedManager] setLoginFrequency:LF_EVERY_RESUME_FROM_BACKGROUND];
    
    if ([[self.navigationItem title] isEqualToString:NSLocalizedString(@"ROOT", nil)] && self.displayID == 0) {
        [self performLog];
        return;
    }
    
    MBBTController *c = (MBBTController *)[self.navigationController viewControllers][0];
    [self.navigationController popToRootViewControllerAnimated:YES onCompletion:^{
        [c performLog];
    }];
}

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
            [self.tableView reloadData];
        });
    }];
}

#pragma mark - Reauthentication

- (void)performLog {
    [[MBBController sharedManager] setIsAuthenticated:NO];
    [[MBBController sharedManager] setDidLoad:YES];
    [[MBBController sharedManager] performLogin];
}

- (void)performLogin {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard-iPhone" bundle:nil];
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
    
    [self.tableView reloadData];
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

#pragma mark - Add Picture

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

- (void)askReupload {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPLOADING", nil) message:NSLocalizedString(@"UNFINISHED_UPLOAD", nil)
                               delegate:self cancelButtonTitle:NSLocalizedString(@"NO", nil) otherButtonTitles:NSLocalizedString(@"UPLOAD", nil), nil] show];
}

#pragma mark - Image Selection

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
        
        MBBTController *c = (MBBTController *)[self.navigationController viewControllers][0];
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
    NSArray *docObjects = [self storageObjects];
    if ([docObjects count] > 0) {
        id o = [self storageObjects][0];
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
        if ([[n topViewController] isKindOfClass:[MBBTController class]]) {
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

#pragma mark - Search for File

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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_fileEmpty && _folderEmpty) return 0;
    if (_fileEmpty || _folderEmpty) return 1;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_fileEmpty && section == 0) return [_folderObjects count];
    if (_folderEmpty && section == 0) return [_fileObjects count];
    if (section == 0) return [_folderObjects count];
    if (section == 1) return [_fileObjects count];
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MBBTCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mbbtcell" forIndexPath:indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    MBBTCell *mbbtCell = (MBBTCell *)cell;
    mbbtCell.delegate = nil;
    mbbtCell.leftUtilityButtons = nil;
    mbbtCell.rightUtilityButtons = nil;
    
    mbbtCell.delegate = self;
    
    id object = nil;
    if ((!_folderEmpty && !_fileEmpty && [indexPath section] == 0) || (!_folderEmpty && _fileEmpty)) object = self.folderObjects[indexPath.row];
    else if ((!_folderEmpty && !_fileEmpty && [indexPath section] == 1) || (!_fileEmpty && _folderEmpty)) object = self.fileObjects[indexPath.row];
    
    if ([object isKindOfClass:[Folder class]]) {
        mbbtCell.previewImage.image = [UIImage imageNamed:@"folder"];
        
        Folder *folder = (Folder *)object;
        mbbtCell.titleLabel.text = [folder folderName];
        mbbtCell.pageLabel.text = [NSString stringWithFormat:@"%d %@",[[folder children] count],NSLocalizedString(@"NUM_BOOKS", nil)];
        
        [mbbtCell setIsFolder:YES];
        [mbbtCell setTag:[folder folderID]];
    } else if ([object isKindOfClass:[File class]]) {
        File *file = (File *)object;
        [mbbtCell setTag:2];
        mbbtCell.titleLabel.text = [file fileName];
        mbbtCell.pageLabel.text = [NSString stringWithFormat:@"%d %@",[file pageCount], NSLocalizedString(@"NUM_PAGES", nil)];
        
        if ([[file fileCover] length] > 0 && [UIImage imageWithData:[file fileCover]] != nil) {
            UIImage *image = [UIImage imageWithData:[file fileCover]];
            UIGraphicsBeginImageContextWithOptions(mbbtCell.previewImage.frame.size, NO, 0.0);
            [image drawInRect:CGRectMake(0, 0, mbbtCell.previewImage.frame.size.width, mbbtCell.previewImage.frame.size.height)];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            mbbtCell.previewImage.image = image;
        } else {
            if ([file canDownload] && [[MBBController sharedManager] isOnline]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    [file setFileCover:[[MBBController sharedManager] downloadPageData:file withPage:1]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        int index = -1;
                        for (id o in self.fileObjects) {
                            if ([o isKindOfClass:[File class]] && [o fileID] == [file fileID]) {
                                index = [self.fileObjects indexOfObject:o];
                                break;
                            }
                        }
                        
                        if (index >= 0) {
                            int section = 1;
                            if (self.fileEmpty || self.folderEmpty) section = 0;
                            NSIndexPath *i = [NSIndexPath indexPathForRow:index inSection:section];
                            [self.tableView reloadRowsAtIndexPaths:@[i] withRowAnimation:UITableViewRowAnimationLeft];
                        }
                    });
                });
            } else {
                NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"missing" ofType:@"png"]];
                UIImage *image = [UIImage imageWithData:data];
                mbbtCell.previewImage.image = image;
            }
        }
        
        NSMutableArray *items = [NSMutableArray array];
        if (![file isDownloaded]) { }
        else {
            [items sw_addUtilityButtonWithColor:[UIColor blueColor] icon:[UIImage imageNamed:@"remove"]];
        }
        
        if ([file isBookmarked]) {
            [items sw_addUtilityButtonWithColor:[UIColor greenColor] icon:[UIImage imageNamed:@"bookmark"]];
        } else {
            [items sw_addUtilityButtonWithColor:[UIColor greenColor] icon:[UIImage imageNamed:@"bookmark_not"]];
        }
        
        [items sw_addUtilityButtonWithColor:[UIColor whiteColor] icon:[UIImage imageNamed:@"info"]];
        if (![file isLatest] && [file isDownloaded])
            [items sw_addUtilityButtonWithColor:[UIColor orangeColor] icon:[UIImage imageNamed:@"downloadUpdate"]];
        
        [mbbtCell setRightUtilityButtons:items];
        
        [mbbtCell setIsFolder:NO];
        [mbbtCell setTag:[file fileID]];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_fileEmpty) return NSLocalizedString(@"FOLDER", nil);
    if (_folderEmpty) return NSLocalizedString(@"FILE", nil);
    if (section == 0) return NSLocalizedString(@"FOLDER", nil);
    if (section == 1) return NSLocalizedString(@"FILE", nil);
    return @"";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.tableCell) [self.tableCell hideUtilityButtonsAnimated:YES];
    
    MBBTCell *cell = (MBBTCell *)[tableView cellForRowAtIndexPath:indexPath];
    if ([cell isFolder]) {
        Folder *f = [self searchForFolderWithID:[cell tag]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            [[MBBController sharedManager] setDelegate:nil];
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard-iPhone" bundle:nil];
            MBBTController *display = (MBBTController *)[storyboard instantiateViewControllerWithIdentifier:@"mbbtcontroller"];
            
            [display setFolderEmpty:YES];
            [display setFileEmpty:YES];
            [display setStorageObjects:[f children]];
            [display setTitle:[f folderName]];
            [display setDisplayID:[f folderID]];
            [[MBBController sharedManager] setDelegate:display];
            
            [self.navigationController pushViewController:display animated:YES];
        });
    } else {
        File *f = [self searchForFileWithID:[cell tag]];
        if (![f isDownloaded]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                [self downloadFile:f];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                [self openFileForReading:f];
            });
        }
    }
}

- (Folder *)searchForFolderWithID:(int)searchID {
    for (Folder *f in self.folderObjects) {
        if ([f folderID] == searchID) return f;
    }
    
    return nil;
}

#pragma mark - Delegate

- (BOOL)swipeableTableViewCellShouldHideUtilityButtonsOnSwipe:(SWTableViewCell *)cell {
    return YES;
}

- (void)swipeableTableViewCell:(SWTableViewCell *)cell didTriggerRightUtilityButtonWithIndex:(NSInteger)index {
    self.tableCell = cell;
    
    File *f = [self searchForFileWithID:[cell tag]];
    if (![f isDownloaded]) index++;
    switch (index) {
        case 0:{
            if ([f isDownloaded]) {
                [self removeFileFromSystem:f];
                
                [cell hideUtilityButtonsAnimated:YES];
                NSMutableArray *a = [[cell rightUtilityButtons] mutableCopy];
                [a removeObjectAtIndex:0];
                [cell setRightUtilityButtons:a];
            }
            break;}
        case 1:{
            if ([f isBookmarked]) {
                [self unbookmark:f];
                [cell hideUtilityButtonsAnimated:YES];
                
                NSMutableArray *a = [[cell rightUtilityButtons] mutableCopy];
                
                if (![f isDownloaded]) index--;
                
                NSMutableArray *ar = [NSMutableArray array];
                [ar sw_addUtilityButtonWithColor:[UIColor greenColor] icon:[UIImage imageNamed:@"bookmark_not"]];
                [a replaceObjectAtIndex:index withObject:ar[0]];
                [cell setRightUtilityButtons:a];
            } else {
                [self bookmark:f];
                [cell hideUtilityButtonsAnimated:YES];
                
                NSMutableArray *a = [[cell rightUtilityButtons] mutableCopy];
                
                if (![f isDownloaded]) index--;
                
                NSMutableArray *ar = [NSMutableArray array];
                [ar sw_addUtilityButtonWithColor:[UIColor greenColor] icon:[UIImage imageNamed:@"bookmark"]];
                [a replaceObjectAtIndex:index withObject:ar[0]];
                [cell setRightUtilityButtons:a];
            }
            break;}
        case 2:{
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell hideUtilityButtonsAnimated:YES];
                [self infoPressed:f index:[self.tableView indexPathForCell:cell]];
            });
            break;}
        case 3: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell hideUtilityButtonsAnimated:YES];
                [self downloadFile:f];
            });
            break;}
        default:
            break;
    }
}

- (void)swipeableTableViewCell:(SWTableViewCell *)cell scrollingToState:(SWCellState)state {
    if (state == kCellStateCenter) self.tableCell = cell;
}

- (File *)searchForFileWithID:(int)fileID {
    for (id obj in self.storageObjects) {
        if ([obj isKindOfClass:[File class]]) { if ([obj fileID] == fileID) return obj; }
        else if ([obj isKindOfClass:[Folder class]]) { return [self searchForFileWithID:fileID]; }
    }
    
    return nil;
}

- (void)unbookmark:(File *)file {
    [file setIsBookmarked:NO];
    [[MBBController sharedManager] rebootEmpress];
    
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM BOOKMARKS WHERE FILE_ID='%d'",[file fileID]];
    if (![SQLHelper executeSQL:(char *)[sql UTF8String] useDB:"FILES"])
        return;
}

- (void)bookmark:(File *)file {
    [file setIsBookmarked:YES];
    [[MBBController sharedManager] rebootEmpress];
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO BOOKMARKS VALUES ('%d')",[file fileID]];
    if (![SQLHelper executeSQL:(char *)[sql UTF8String] useDB:"FILES"])
        return;
}

- (void)removeFileFromSystem:(File *)file {
    [[MBBController sharedManager] rebootEmpress];
    [[MBBController sharedManager] removeFileFromSystemWithFileInformation:file];
    [file setIsDownloaded:NO];
    [file setIsLatest:YES];
}

- (void)infoPressed:(File *)file index:(NSIndexPath *)index {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Storyboard-iPhone" bundle:nil];
    InfoTVC *ivc = [storyboard instantiateViewControllerWithIdentifier:@"infotvc"];
    [ivc setDelegate:self];
    [ivc setFile:file];
    [ivc setIndexPath:index];
    [self.navigationController pushViewController:ivc animated:YES];
}

- (void)infoDidDismiss:(File *)file index:(NSIndexPath *)index {
    dispatch_async(dispatch_get_main_queue(), ^{
        SEL sel = @selector(showBookmarks);
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:sel];
        self.navigationItem.rightBarButtonItem = item;
        [self.navigationController setToolbarHidden:NO];
        
        [self.tableView reloadRowsAtIndexPaths:@[index] withRowAnimation:UITableViewRowAnimationLeft];
    });
}

#pragma mark - Open file for reading

- (void)openFileForReading:(File *)file {
    UIStoryboard *storybaord = [UIStoryboard storyboardWithName:@"Storyboard-iPhone" bundle:nil];
    ReadVC *readVC = (ReadVC *)[storybaord instantiateViewControllerWithIdentifier:@"Read"];
    [readVC setFile:file];
    [self.navigationController pushViewController:readVC animated:YES];
}

#pragma mark - File Download

- (void)downloadFile:(File *)file {
    if (self.tableCell) [self.tableCell hideUtilityButtonsAnimated:YES];
    
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
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:section];
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
        }
        
        return;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64;
}

#pragma mark - Bookmark Delegate

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.delegate bookmarkGoing];
}

- (void)bookmarkGoing {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

@end
