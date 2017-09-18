//
//  ReadVC.h
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "File.h"
#import "MBBController.h"
#import "AuthViewController.h"

@interface ReadVC : UIViewController <UIScrollViewDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, AuthenticationFinished> {
    int pageCount;
    
    UIImage *previousImage;
    UIImage *nextImage;
}

@property (nonatomic, strong) File *file;
- (void)performLogin;

@end
