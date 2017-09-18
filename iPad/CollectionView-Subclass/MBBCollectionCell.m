//
//  MBBCollectionCell.m
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import "MBBCollectionCell.h"

@implementation MBBCollectionCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.fra = [[UIImageView alloc] initWithFrame:frame];
        self.fra.image = [UIImage imageNamed:@"fra"];
        [self setBackgroundView:self.fra];
        
        self.imageCover = [[UIImageView alloc] initWithFrame:CGRectMake(47.5, 5, 155, 215)];
        [self.contentView addSubview:self.imageCover];
        
        self.labelTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 224, 240, 21)];
        [self.labelTitle setAdjustsFontSizeToFitWidth:YES];
        [self.labelTitle setTextAlignment:NSTextAlignmentCenter];
        [self.contentView addSubview:self.labelTitle];
        
        self.labelIssue = [[UILabel alloc] initWithFrame:CGRectMake(0, 213, 240, 21)];
        [self.labelIssue setTextAlignment:NSTextAlignmentCenter];

        self.updateAvailable = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.updateAvailable setFrame:CGRectMake(180, 5, 60, 60)];
        [self.updateAvailable setTag:99];
        [self.contentView addSubview:self.updateAvailable];
    }
    return self;
}

- (void)layoutSubviews {
    self.labelTitle.textColor = [UIColor blackColor];
    self.labelTitle.backgroundColor = [UIColor clearColor];
    
    self.labelIssue.textColor = [UIColor blackColor];
    self.labelIssue.backgroundColor = [UIColor clearColor];
    
    [self.labelTitle setAdjustsFontSizeToFitWidth:YES];
    [self.labelTitle setMinimumScaleFactor:0.1];
    
    [self.labelIssue setAdjustsFontSizeToFitWidth:YES];
    [self.labelIssue setMinimumScaleFactor:0.1];
}

@end
