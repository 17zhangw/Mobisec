//
//  MBBFolderCell.m
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "MBBFolderCell.h"

@implementation MBBFolderCell

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.fra = [[UIImageView alloc] initWithFrame:frame];
        self.fra.image = [UIImage imageNamed:@"fra_folder"];
        [self setBackgroundView:self.fra];
        
        self.imageCover = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        [self.contentView addSubview:self.imageCover];
        
        self.labelTitle = [[UILabel alloc] initWithFrame:CGRectMake(60, 0, 180, 60)];
        [self.labelTitle setAdjustsFontSizeToFitWidth:YES];
        [self.labelTitle setTextAlignment:NSTextAlignmentCenter];
        [self.contentView addSubview:self.labelTitle];
    }
    
    return self;
}

- (void)layoutSubviews {
    self.labelTitle.textColor = [UIColor blackColor];
    self.labelTitle.backgroundColor = [UIColor clearColor];
    
    [self.labelTitle setAdjustsFontSizeToFitWidth:YES];
    [self.labelTitle setMinimumScaleFactor:0.1];
}


@end
