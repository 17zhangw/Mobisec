//
//  InfoTVC.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "File.h"
#import "MBBController.h"

@protocol InfoDismissing <NSObject>
- (void)infoDidDismiss:(File *)file index:(NSIndexPath *)index;
@end

@interface InfoTVC : UITableViewController <MBBDownloadController>
@property (nonatomic, assign) id<InfoDismissing> delegate;

@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, strong) File *file;

@property (nonatomic, strong) IBOutlet UIImageView *photoImage;
@property (nonatomic, strong) IBOutlet UILabel *fileLabel;
@property (nonatomic, strong) IBOutlet UILabel *pageLabel;

@property (nonatomic, strong) IBOutlet UITextView *detailLabel;

@property (nonatomic, strong) IBOutlet UILabel *fileExtension;
@property (nonatomic, strong) IBOutlet UILabel *createLabel;
@property (nonatomic, strong) IBOutlet UILabel *modifyLabel;

@property (nonatomic, strong) IBOutlet UIButton *favoriteButton;
@property (nonatomic, strong) IBOutlet UIButton *removeButton;
@property (nonatomic, strong) IBOutlet UIButton *updateButton;

- (IBAction)favorite:(id)sender;
- (IBAction)remove:(id)sender;
- (IBAction)update:(id)sender;

@end
