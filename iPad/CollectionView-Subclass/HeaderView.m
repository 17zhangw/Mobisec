//
//  FooterView.m
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "HeaderView.h"

@implementation HeaderView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setBackgroundColor:[UIColor clearColor]];
        
        CGRect rect = CGRectMake(10, 0, frame.size.width-10, frame.size.height);
        self.descriptionLabel = [[UILabel alloc] initWithFrame:rect];
        [self.descriptionLabel setFont:[UIFont systemFontOfSize:18]];
        [self addSubview:self.descriptionLabel];
    }
    
    return self;
}

@end
