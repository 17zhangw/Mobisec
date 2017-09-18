//
//  AuthViewController.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AuthenticationFinished <NSObject>

- (void)didLoadLoginFinished;
- (void)didReturnLoginFinished;

@end

@interface AuthViewController : UIViewController <UITextFieldDelegate, NSURLSessionDelegate>

@property (nonatomic) IBOutlet UITextField *username;
@property (nonatomic) IBOutlet UITextField *password;
@property (nonatomic) IBOutlet UITextField *destinationAddress;
@property (nonatomic) IBOutlet UITextField *companyToken;

@property (nonatomic, assign) id<AuthenticationFinished> delegate;

- (IBAction)backgroundTappedDown:(id)sender;
- (IBAction)login:(id)sender;

@property (nonatomic, strong) IBOutlet UIButton *reRegister;
- (IBAction)reRegister:(id)sender;

@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) IBOutlet UIScrollView *mainScrollView;

/* Register View Usable Methods and Declarations */
@property (nonatomic, strong) IBOutlet UITextField *targetAddress;
@property (nonatomic, strong) IBOutlet UITextField *companyID;
@property (nonatomic, strong) IBOutlet UITextField *usernameRegistration;
@property (nonatomic, strong) IBOutlet UITextField *passwordRegistration;
@property (nonatomic, strong) IBOutlet UITextField *deviceNameInput;
@property (nonatomic, strong) IBOutlet UITextField *deviceDescription;
- (IBAction)registerDevice:(id)sender;

@property (nonatomic, strong) IBOutlet UIButton *closeRegister;
- (IBAction)closeRegister:(id)sender;

@property (nonatomic, strong) IBOutlet UITextField *halfKeyEntry;
- (IBAction)enterKey:(id)sender;
- (IBAction)goOnline:(id)sender;

- (void)swapToKeyEntry;

@end
