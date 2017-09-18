//
//  MBBTCell.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SWTableViewCell.h"

@interface MBBTCell : SWTableViewCell

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *pageLabel;
@property (nonatomic, strong) IBOutlet UIImageView *previewImage;

@property (nonatomic, assign) BOOL isFolder;

@end
