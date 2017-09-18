//
//  InfoController.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface InfoController : UIViewController

@property (nonatomic, strong) IBOutlet UILabel *fileName;
@property (nonatomic, strong) IBOutlet UILabel *pageCount;
@property (nonatomic, strong) IBOutlet UILabel *fileExplanation;
@property (nonatomic, strong) IBOutlet UILabel *fileSize;
@property (nonatomic, strong) IBOutlet UILabel *fileExtension;
@property (nonatomic, strong) IBOutlet UILabel *fileCreation;
@property (nonatomic, strong) IBOutlet UILabel *fileModify;

@end
