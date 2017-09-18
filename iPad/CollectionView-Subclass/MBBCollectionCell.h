//
//  MBBCollectionCell.h
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MBBCollectionCell : UICollectionViewCell

@property (strong, nonatomic) UIImageView *imageCover;

@property (strong, nonatomic) UIImageView *fra;

@property (strong, nonatomic) UILabel *labelTitle;
@property (strong, nonatomic) UILabel *labelIssue;

@property (strong, nonatomic) UIButton *bookmark;
@property (strong, nonatomic) UIButton *remove;
@property (strong, nonatomic) UIButton *updateAvailable;
@property (strong, nonatomic) UIButton *info;

@end
