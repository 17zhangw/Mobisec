//
//  MBBCollectionViewController.h
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBBController.h"

@interface MBBCollectionViewController : UICollectionViewController <MBBDownloadController, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) NSMutableArray *storageObjects;
@property (nonatomic, strong) NSMutableArray *folderObjects;
@property (nonatomic, strong) NSMutableArray *fileObjects;

@property (nonatomic) BOOL folderEmpty;
@property (nonatomic) BOOL fileEmpty;

- (NSArray *)collectionOfDocobjects;
- (void)arrangeCollectionView:(UIInterfaceOrientation)interface;

- (void)downloadPressed:(UIButton *)button touch:(id)event;
- (void)updateDataPressed:(UIButton *)button touch:(id)event;
- (void)infoPressed:(UIButton *)button touch:(id)event;

@end
