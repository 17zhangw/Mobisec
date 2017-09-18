//
//  InfoTVC.m
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "InfoTVC.h"
#import "SQLHelper.h"
#import "MBProgressHUD.h"

@interface InfoTVC ()
@property (nonatomic, strong) MBProgressHUD *progressHUD;
@end

@implementation InfoTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationController setToolbarHidden:YES];
    [[self.navigationController navigationItem] setRightBarButtonItem:nil];
    
    UIImage *image = [UIImage imageWithData:[self.file fileCover]];
    UIGraphicsBeginImageContextWithOptions(self.photoImage.frame.size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, self.photoImage.frame.size.width, self.photoImage.frame.size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.photoImage.image = image;
    
    self.fileLabel.text = [self.file fileName];
    self.pageLabel.text = [NSString stringWithFormat:@"%d %@",[self.file pageCount], NSLocalizedString(@"NUM_PAGES", nil)];
    
    self.detailLabel.text = [self.file fileDescription];
    
    self.fileExtension.text = [self.file fileExtension];
    self.createLabel.text = [[MBBController sharedManager] localizeDate:[self.file createDate]];
    self.modifyLabel.text = [[MBBController sharedManager] localizeDate:[self.file modifyDate]];
    
    if ([self.file isDownloaded]) {
        [self.removeButton setTitle:NSLocalizedString(@"DELETE", nil) forState:UIControlStateNormal];
    } else {
        [self.removeButton setTitle:NSLocalizedString(@"DOWNLOAD", nil) forState:UIControlStateNormal];
    }
    
    [self.updateButton setTitle:NSLocalizedString(@"UPDATE", nil) forState:UIControlStateNormal];
    if ([self.file isDownloaded] && ![self.file isLatest]) {
        [self.updateButton setEnabled:YES];
    } else { [self.updateButton setEnabled:NO]; }
    
    if ([self.file isBookmarked]) {
        [self.favoriteButton setTitle:NSLocalizedString(@"UNFAVORITE", nil) forState:UIControlStateNormal];
    } else {
        [self.favoriteButton setTitle:NSLocalizedString(@"FAVORITE", nil) forState:UIControlStateNormal];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Actions

- (IBAction)favorite:(id)sender {
    if ([self.file isBookmarked]){
        [self unbookmark:self.file];
        [self.favoriteButton setTitle:NSLocalizedString(@"FAVORITE", nil) forState:UIControlStateNormal];
    } else {
        [self bookmark:self.file];
        [self.favoriteButton setTitle:NSLocalizedString(@"UNFAVORITE", nil) forState:UIControlStateNormal];
    }
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

- (IBAction)remove:(id)sender {
    if ([self.file isDownloaded]) {
        [self removeFileFromSystem:self.file];
        [self.updateButton setEnabled:NO];
        [self.removeButton setTitle:NSLocalizedString(@"DOWNLOAD", nil) forState:UIControlStateNormal];
    } else {
        [self.updateButton setEnabled:NO];
        [self downloadFile:self.file];
    }
}

- (IBAction)update:(id)sender {
    [self downloadFile:self.file];
}

- (void)removeFileFromSystem:(File *)file {
    [[MBBController sharedManager] rebootEmpress];
    [[MBBController sharedManager] removeFileFromSystemWithFileInformation:file];
    [file setIsDownloaded:NO];
}

- (void)downloadFile:(File *)file {
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    MBProgressHUD *hud = self.progressHUD;
    [hud setMode:MBProgressHUDModeAnnularDeterminate];
    [hud setLabelText:NSLocalizedString(@"DOWNLOADING", nil)];
    [hud setTag:101];
    
    [self.view setUserInteractionEnabled:NO];
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
    
    [self.navigationItem setHidesBackButton:NO];
    
    if (isSuccessful) {
        [file setIsLatest:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.removeButton setTitle:NSLocalizedString(@"DELETE", nil) forState:UIControlStateNormal];
            [self.updateButton setEnabled:NO];
        });
        return;
    }
}

#pragma mark - Disappear

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.delegate infoDidDismiss:self.file index:self.indexPath];
}

@end
