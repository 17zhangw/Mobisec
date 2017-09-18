//
//  MBBCollectionViewController.m
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import "MBBCollectionViewController.h"
#import "MBBFlowLayout.h"

#import "File.h"
#import "Folder.h"

#import "MBBFolderCell.h"
#import "MBBCollectionCell.h"

#import "DecorationView.h"
#import "HeaderView.h"
#import "FooterView.h"

#import "MBBController.h"
#import "SQLHelper.h"

@interface MBBCollectionViewController ()
@property (nonatomic, strong) MBBFlowLayout *flowLayout;

@property (nonatomic, strong) UIImage *download;
@property (nonatomic, strong) UIImage *remove;
@property (nonatomic, strong) UIImage *info;
@end

@implementation MBBCollectionViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.flowLayout = [MBBFlowLayout new];
    [self.collectionView setCollectionViewLayout:self.flowLayout animated:NO];
    
    [self.collectionView registerClass:[MBBFolderCell class] forCellWithReuseIdentifier:@"MBBFolderCell"];
    [self.collectionView registerClass:[MBBCollectionCell class] forCellWithReuseIdentifier:@"MBBCollectionCell"];
    
    [self.collectionView registerClass:[HeaderView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"Header"];
    [self.collectionView registerClass:[FooterView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"Footer"];
    [self.flowLayout registerClass:[DecorationView class] forDecorationViewOfKind:@"Decoration"];
    
    [self.collectionView setBackgroundColor:[UIColor clearColor]];
    [[UIToolbar appearance] setBackgroundColor:[UIColor blackColor]];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    self.download = [UIImage imageNamed:@"download"];
    self.remove = [UIImage imageNamed:@"remove"];
    self.info = [UIImage imageNamed:@"info"];
    
    [[MBBController sharedManager] setDelegate:self];
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

- (void)viewDidLayoutSubviews {
    CGFloat height = self.view.frame.size.height - 64;
    UIInterfaceOrientation o = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (UIInterfaceOrientationIsPortrait(o)) {
        [self.collectionView setFrame:CGRectMake(0, 64, 768, height)];
        [self.collectionView setCenter:CGPointMake(self.view.center.x, self.view.center.y)];
    } else {
        [self.collectionView setFrame:CGRectMake(0, 64, 1024, height)];
        [self.collectionView setCenter:CGPointMake(self.view.center.x, self.view.center.y)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self arrangeCollectionView:[[UIApplication sharedApplication] statusBarOrientation]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)arrangeCollectionView:(UIInterfaceOrientation)interface {
    MBBFlowLayout *flowLayout = (MBBFlowLayout *)self.collectionView.collectionViewLayout;
    [flowLayout setMinimumLineSpacing:10.0];
    [flowLayout setMinimumInteritemSpacing:0];
    [self.collectionView setCollectionViewLayout:flowLayout animated:NO];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self arrangeCollectionView:toInterfaceOrientation];
}

#pragma mark --- Collection View Layout Sizes

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (_fileEmpty && !_folderEmpty)
        return CGSizeMake(240, 60);
    if (!_fileEmpty && _folderEmpty)
        return CGSizeMake(240, 250);
    
    if ([indexPath section] == 0) {
        return CGSizeMake(240, 60);
    } return CGSizeMake(240, 250);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(5, 5, 5, 5);
}

#pragma mark --- Collection View Delegate

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        HeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                                withReuseIdentifier:@"Header" forIndexPath:indexPath];
        if ([indexPath section] == 0) { header.descriptionLabel.text = NSLocalizedString(@"FOLDER", nil); }
        else { header.descriptionLabel.text = NSLocalizedString(@"FILE", nil); }
        return header;
    }
    
    return [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                            withReuseIdentifier:@"Footer" forIndexPath:indexPath];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    if (_folderEmpty || _fileEmpty)
        return CGSizeZero;
    return CGSizeMake(self.view.frame.size.width, 44);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    if (_folderEmpty || _fileEmpty)
        return CGSizeZero;
    if (section == 1)
        return CGSizeZero;
    return CGSizeMake(self.view.frame.size.width, 44);
}

- (NSArray *)collectionOfDocobjects {
    return self.storageObjects;
}

#pragma mark --- Collection View Datasource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    if (!_folderEmpty && _fileEmpty)
        return [_folderObjects count];
    else if (!_fileEmpty && _folderEmpty)
        return [_fileObjects count];
    
    if (section == 0)
        return [self.folderObjects count];
    else if (section == 1)
        return [self.fileObjects count];
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView {
    if (_folderEmpty || _fileEmpty)
        return 1;
    return 2;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    id b;
    if ((!_folderEmpty && !_fileEmpty && [indexPath section] == 0) || (!_folderEmpty && _fileEmpty)) {
        MBBFolderCell * cell = (MBBFolderCell *)[cv dequeueReusableCellWithReuseIdentifier:@"MBBFolderCell" forIndexPath:indexPath];
        b = [self.folderObjects objectAtIndex:indexPath.row];
        
        const char *c = [[b folderName] UTF8String];
        NSString *folderName = [NSString stringWithCString:c encoding:NSUTF8StringEncoding];
        cell.labelTitle.text = folderName;
        cell.imageCover.image = [UIImage imageNamed:@"folder"];
        return cell;
        
    } else if ((!_folderEmpty && !_fileEmpty && [indexPath section] == 1) || (!_fileEmpty && _folderEmpty)) {
        MBBCollectionCell * cell = (MBBCollectionCell*)[cv dequeueReusableCellWithReuseIdentifier:@"MBBCollectionCell" forIndexPath:indexPath];
        b = [self.fileObjects objectAtIndex:indexPath.row];
        
        const char *c = [[b fileName] UTF8String];
        NSString *filename = [NSString stringWithCString:c encoding:NSUTF8StringEncoding];
        cell.labelTitle.text = filename;
        
        if ([b pageCount] > 0) cell.labelIssue.text = [NSString stringWithFormat:@"%d",[(File *)b pageCount]];
        else cell.labelIssue.text = @"";
        
        [cell.remove removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        
        if ([b fileCover] && [[b fileCover] length] != 0) {
            UIImage *image = [UIImage imageWithData:[b fileCover]];
            UIGraphicsBeginImageContextWithOptions(cell.imageCover.frame.size, NO, 0.0);
            [image drawInRect:CGRectMake(0, 0, cell.imageCover.frame.size.width, cell.imageCover.frame.size.height)];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            cell.imageCover.image = image;
        } else {
            if ([b canDownload] && [[MBBController sharedManager] isOnline]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    [b setFileCover:[[MBBController sharedManager] downloadPageData:b withPage:1]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        int index = -1;
                        for (id o in self.fileObjects) {
                            if ([o isKindOfClass:[File class]] && [o fileID] == [b fileID]) {
                                index = [self.fileObjects indexOfObject:o];
                                break;
                            }
                        }
                        
                        if (index >= 0) {
                            int section = 1;
                            if (self.fileEmpty || self.folderEmpty) section = 0;
                            NSIndexPath *i = [NSIndexPath indexPathForItem:index inSection:section];
                            [self.collectionView reloadItemsAtIndexPaths:@[i]];
                        }
                    });
                });
            }
            else {
                NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"missing" ofType:@"png"]];
                UIImage *image = [UIImage imageWithData:data];
                cell.imageCover.image = image;
            }
        }
        
        if ([b canDownload]) {
            if ([b isDownloaded]) {
                if (![b isLatest]) {
                    if ([[MBBController sharedManager] isOnline]) {
                        [cell.updateAvailable addTarget:self action:@selector(updateDataPressed:touch:) forControlEvents:UIControlEventTouchUpInside];
                        [cell.updateAvailable setHidden:NO];
                        [cell.updateAvailable setEnabled:YES];
                        [cell.updateAvailable setImage:[UIImage imageNamed:@"downloadUpdate"] forState:UIControlStateNormal];
                    } else {
                        [cell.updateAvailable setHidden:YES];
                        [cell.updateAvailable setEnabled:NO];
                    }
                } else {
                    [cell.updateAvailable setHidden:YES];
                    [cell.updateAvailable setEnabled:NO];
                }
            }
        }
        
        [cell setTag:[b fileID]];
        return cell;
    }
    
    return nil;
}

- (void)unbookmark:(UIButton *)b event:(id)event {
    int search = [[[b superview] superview] tag];
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
    
    [b removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [b addTarget:self action:@selector(bookmark:event:) forControlEvents:UIControlEventTouchUpInside];
    [b setImage:[UIImage imageNamed:@"bookmark_not"] forState:UIControlStateNormal];
}

- (void)bookmark:(UIButton *)b event:(id)event {
    int search = [[[b superview] superview] tag];
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
    
    [b removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [b addTarget:self action:@selector(unbookmark:event:) forControlEvents:UIControlEventTouchUpInside];
    [b setImage:[UIImage imageNamed:@"bookmark"] forState:UIControlStateNormal];
}

#pragma mark --- Selection

- (void)removeFileFromSystem:(id)sender {
    
}

#pragma mark - Satisfy Warning Declarations

- (void)downloadPressed:(UIButton *)button touch:(id)event {
    
}

- (void)updateDataPressed:(UIButton *)button touch:(id)event {
    
}

- (void)infoPressed:(UIButton *)button touch:(id)event {
    
}

@end
