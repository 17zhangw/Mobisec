//
//  ReadVC.m
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import "ReadVC.h"
#import "SQLHelper.h"

@interface ReadVC ()
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *current;

@property (nonatomic) int sliderPreviousValue;
@end

@implementation ReadVC
@synthesize file;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) { }
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [tap setNumberOfTapsRequired:1];
    [tap setDelegate:self];
    [self.view addGestureRecognizer:tap];
    
    [[MBBController sharedManager] rebootEmpress];
    NSString *sql = [NSString stringWithFormat:@"SELECT PAGE_ID FROM LASTOPEN WHERE FILE_ID='%d'",[file fileID]];
    NSArray *result = [SQLHelper execQuery:(char*)[sql UTF8String] useDB:"FILES"];

    if ([result count] == 1 && [result[0] intValue] > 0) { pageCount = [result[0] intValue]; }
    else pageCount = 1;
    
    const char * c = [[file fileName] UTF8String];
    NSString *title = [NSString stringWithCString:c encoding:NSUTF8StringEncoding];
    self.title = title;
    
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        NSMutableArray *right = [NSMutableArray array];
        [right addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize
                                                                       target:self action:@selector(showActionSheet)]];
        [right addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
        [right addObject:[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"NEXT", nil) style:UIBarButtonItemStyleBordered
                                                         target:self action:@selector(swipeLeft:)]];
        
        NSMutableArray *left = [NSMutableArray array];
        [left addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                      target:self action:@selector(returnToStart)]];
        [left addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
        [left addObject:[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"PREVIOUS", nil)
                                                         style:UIBarButtonItemStyleBordered target:self action:@selector(swipeRight:)]];
        
        [self.navigationItem setLeftBarButtonItems:left];
        [self.navigationItem setRightBarButtonItems:right];
    } else {
        [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(showActionSheet)]];
    }
    
    if (![self.navigationController isToolbarHidden]) {
        [self.navigationController setToolbarHidden:NO];
    }
    
    /* Creating Slider */
    _slider = [[UISlider alloc] init];
    [_slider addTarget:self action:@selector(sliderValueUpdated:) forControlEvents:UIControlEventValueChanged];
    [_slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventTouchUpInside];
    [_slider setBackgroundColor:[UIColor clearColor]];
    [_slider setMaximumValue:[file pageCount]];
    [_slider setMinimumValue:1];
    [_slider setContinuous:YES];
    [_slider setValue:pageCount];
    UIBarButtonItem *slider = [[UIBarButtonItem alloc] initWithCustomView:_slider];
    
    CGFloat width = self.view.frame.size.width - 100;
    [slider setWidth:width];
    
    NSString *text = [NSString stringWithFormat:@"%d / %d", pageCount, [file pageCount]];
    _current = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 64, 44)];
    [_current setTextColor:[UIColor whiteColor]];
    [_current setAdjustsFontSizeToFitWidth:YES];
    [_current setMinimumScaleFactor:0.25];
    [_current setBackgroundColor:[UIColor clearColor]];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:_current];
    [item setTitlePositionAdjustment:UIOffsetMake(0, -10) forBarMetrics:UIBarMetricsDefault];
    [item setWidth:64];
    
    [self setToolbarItems:@[slider, item]];
    
    [_current setText:text];
}

- (void)viewDidLayoutSubviews {
    for (UIView *v in [self.view subviews]) {
        if ([v isKindOfClass:[UIScrollView class]]) {
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
                [v setFrame:self.view.frame];
                [[self.navigationController navigationBar] setFrame:CGRectMake(0, 0, v.frame.size.width, 64)];
                [self.toolbarItems[0] setWidth:v.frame.size.width-100];
                [self.toolbarItems[1] setTitlePositionAdjustment:UIOffsetMake(0, -10) forBarMetrics:UIBarMetricsDefault];
            } else {
                [v setFrame:self.view.frame];
                [[self.navigationController navigationBar] setFrame:CGRectMake(0, 0, v.frame.size.width, 64)];
                [self.toolbarItems[0] setWidth:v.frame.size.width-100];
                [self.toolbarItems[1] setTitlePositionAdjustment:UIOffsetMake(0, -10) forBarMetrics:UIBarMetricsDefault];
            }
            
            UIImageView *image = [v subviews][0];
            [image setFrame:v.frame];
            [self.navigationController setToolbarHidden:NO];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self.view setUserInteractionEnabled:YES];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self viewDidLayoutSubviews];
    
    [self initializeAll];
}

- (void)sliderValueUpdated:(UISlider *)sliderChanged {
    int value = roundf([_slider value]);
    _current.text = [NSString stringWithFormat:@"%d / %d",value, [file pageCount]];
}

- (void)sliderValueChanged:(UISlider *)sliderChanged {
    int value = roundf([_slider value]);
    if (value >= _sliderPreviousValue) {
        pageCount = value - 1;
        [self drawTransition:YES];
    } else if (value < _sliderPreviousValue) {
        pageCount = value + 1;
        [self drawTransition:NO];
    }
    
    _sliderPreviousValue = value;
}

- (void)initializeAll {
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    CGSize size = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
    
    UIScrollView *scroll = [self returnScroll];
    [scroll setFrame:frame];
    
    UIImageView *image = [[UIImageView alloc] initWithFrame:frame];
    UIImage *i = [UIImage imageWithData:[self getDataForPage:[NSString stringWithFormat:@"%d",pageCount]]];
    UIImage *x = [self imageWithImage:i scaledToSize:size];
    i = nil;
    [image setImage:x];
    [scroll setZoomScale:1.0];    
    [scroll insertSubview:image atIndex:0];
}

- (UIScrollView *)returnScroll {
    for (UIView *v in [self.view subviews]) {
        if ([v isMemberOfClass:[UIScrollView class]]) {
            return (UIScrollView *)v;
        }
    }
    
    return nil;
}

#pragma mark - Tap { Tap }

- (void)tap:(UITapGestureRecognizer *)sender {
    BOOL shouldHide = NO;
    
    if ([sender state] == UIGestureRecognizerStateEnded) {
        CGPoint touch = [sender locationInView:self.view];
        if (touch.x >= self.view.frame.size.width * 3/4) { [self drawTransition:YES]; }
        else if (touch.x <= self.view.frame.size.width / 4) { [self drawTransition:NO]; }
        else if (touch.x >= self.view.frame.size.width / 4) { shouldHide = YES; }
    }
    
    if (shouldHide) {
        if ([[self.navigationController navigationBar] isHidden]) {
            [[self.navigationController navigationBar] setHidden:NO];
            [[self.navigationController toolbar] setHidden:NO];
        } else {
            [[self.navigationController navigationBar] setHidden:YES];
            [[self.navigationController toolbar] setHidden:YES];
        }
    }
}

- (void)showActionSheet {
    NSString *string = [NSString stringWithFormat:@"1 %@ %d",NSLocalizedString(@"TO", nil),[file pageCount]];
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"PAGE_SELECTION", nil) message:string delegate:self cancelButtonTitle:NSLocalizedString(@"CANCEL", nil) otherButtonTitles:NSLocalizedString(@"ENTER", nil), nil];
    [a setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [a show];
}

#pragma mark - Swipe { Left - Right }

- (void)swipeLeft:(UISwipeGestureRecognizer *)sender { [self drawTransition:YES]; }

- (void)swipeRight:(UISwipeGestureRecognizer *)sender { [self drawTransition:NO]; }

#pragma mark - Draw Transition

- (void)drawTransition:(BOOL)direction {
    UIScrollView *scroll = [self returnScroll];
    [scroll setZoomScale:1.0];
    UIImageView *imagef = [scroll subviews][0];
    
    BOOL canPerform = NO;
    UIViewAnimationOptions opt;
    
    if (direction) {
        opt = UIViewAnimationOptionTransitionCurlUp;
        
        if (pageCount < [file pageCount]) {
            pageCount = pageCount + 1;
            canPerform = YES;
        }
    } else {
        opt = UIViewAnimationOptionTransitionCurlDown;
        
        if (pageCount > 1) {
            pageCount = pageCount - 1;
            canPerform = YES;
        }
    }
    
    if (canPerform) {
        [self.view setUserInteractionEnabled:NO];
        @autoreleasepool {
            [UIView transitionWithView:imagef duration:0.3 options:opt animations:^{
                UIImage *i = [UIImage imageWithData:[self getDataForPage:[NSString stringWithFormat:@"%d",pageCount]]];
                UIImage *x = [self imageWithImage:i scaledToSize:self.view.frame.size];
                i = nil;
                [imagef setImage:x];
            } completion:^(BOOL finished) {
                [scroll setScrollEnabled:NO];
                [self.view setUserInteractionEnabled:YES];
                
                [self.slider setValue:pageCount];
                [self.current setText:[NSString stringWithFormat:@"%d / %d",pageCount, [file pageCount]]];
                [self saveLastOpenPage];
            }];
        }
    }
}

#pragma mark - Image Scaling

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize; {
    newSize = image.size;
    
    UIGraphicsBeginImageContext(newSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
    CGContextFillRect(context, CGRectMake(0, 0, newSize.width, newSize.height));
    UIImage *bgImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIGraphicsBeginImageContext( newSize );
    [bgImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (NSData *)getDataForPage:(NSString *)page {
    return [[MBBController sharedManager] getDataForPage:page fromFile:file];
}

#pragma mark - Gesture { Delegate }

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) { return NO; }
    else if ([gestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]]) { return YES; }
    else { return YES; }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView { return scrollView.subviews[0]; }

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if ([scrollView zoomScale] != 1.0) { [scrollView setScrollEnabled:YES]; }
    else { [scrollView setScrollEnabled:NO]; }
}

#pragma mark - Action Sheet

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    int value = [[alertView textFieldAtIndex:0].text intValue];
    if (value > 0 && value <= [file pageCount]) {
        pageCount = value - 1;
        [self drawTransition:YES];
    }
}

#pragma mark - Autorotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    CGSize size = self.view.frame.size;
    size = CGSizeMake(size.height, size.width);
    
    UIScrollView *scroll = [self returnScroll];
    [scroll setZoomScale:1.0];
    UIImageView *image = [scroll subviews][0];
    image.image = nil;
    
    UIImage *i = [UIImage imageWithData:[self getDataForPage:[NSString stringWithFormat:@"%d",pageCount]]];
    UIImage *x = [self imageWithImage:i scaledToSize:size];
    i = nil;
    [image setImage:x];
}

#pragma mark - Return

- (void)returnToStart {
    [self.slider removeFromSuperview];
    [self.current removeFromSuperview];
    self.slider = nil;
    self.current = nil;
    
    [self saveLastOpenPage];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)saveLastOpenPage {
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM LASTOPEN WHERE FILE_ID='%d'",[file fileID]];
    [SQLHelper executeSQL:(char*)[sql UTF8String] useDB:"FILES"];
    sql = [NSString stringWithFormat:@"INSERT INTO LASTOPEN VALUES ('%d', '%d')",[file fileID],pageCount];
    [SQLHelper executeSQL:(char*)[sql UTF8String] useDB:"FILES"];
}

#pragma mark - Delegate

- (void)didLoadLoginFinished {
    
}

- (void)didReturnLoginFinished {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.navigationController isToolbarHidden]) {
            [self.navigationController setToolbarHidden:NO];
        }
    });
}

#pragma mark - Perform Login

- (void)performLogin {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    AuthViewController *auth = (AuthViewController *)[storyboard instantiateViewControllerWithIdentifier:@"Auth"];
    [auth setDelegate:self];
    [self.navigationController pushViewController:auth animated:YES];
}

@end