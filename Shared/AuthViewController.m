//
//  AuthViewController.m
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "AuthViewController.h"
#import "DisplayController.h"
#import "MBBTController.h"
#import "MBProgressHUD.h"
#import "SQLHelper.h"
#import "MBBPushRegister.h"

#import "RNEncryptor.h"
#import "RNDecryptor.h"
#import "FDKeychain.h"
#import "NSString+MD5Addition.h"

#import <CommonCrypto/CommonCrypto.h>
#import <CoreLocation/CoreLocation.h>

@interface AuthViewController ()
@property (nonatomic) BOOL isRegister;
@property (nonatomic) BOOL isOffline;
@property (nonatomic) UIView *registerView;
@property (nonatomic) UIView *offlineView;

@property (nonatomic, weak) UITextField *activeField;
@end

@implementation AuthViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationItem setHidesBackButton:YES];
    [self setTitle:NSLocalizedString(@"LOGIN", nil)];
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Apple-Wood.png"]]];
    
    if ([[self.navigationController navigationBar] isHidden]) {
        [[self.navigationController navigationBar] setHidden:NO];
    }
    if (![self.navigationController isToolbarHidden]) {
        [self.navigationController setToolbarHidden:YES];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self.mainScrollView setContentSize:CGSizeMake(320, 252)];
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureCaptured:)];
        [self.mainScrollView addGestureRecognizer:singleTap];
        [self.mainScrollView setFrame:self.view.frame];
        [self.mainScrollView setContentOffset:CGPointMake(0, 0)];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    
    CGRect frame = self.view.frame;
    if (![[MBBController sharedManager] isOnline]) {
        self.isOffline = YES;
        self.offlineView = [[[NSBundle mainBundle] loadNibNamed:@"OfflineEntry" owner:self options:nil] objectAtIndex:0];
        [self.offlineView setFrame:frame];
        [self.offlineView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Apple-Wood.png"]]];
        [self.view addSubview:self.offlineView];
    } else if ([[NSUserDefaults standardUserDefaults] integerForKey:@"APIVersion"] != 1) {
        self.isRegister = YES;
        [self setTitle:NSLocalizedString(@"REGISTER", nil)];
        self.registerView = [[[NSBundle mainBundle] loadNibNamed:@"RegisterView" owner:self options:nil] objectAtIndex:0];
        [self.registerView setFrame:frame];
        [self.scrollView setFrame:self.view.frame];
        [self.scrollView setContentSize:CGSizeMake(320, 400)];
        
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureCaptured:)];
        [self.scrollView addGestureRecognizer:singleTap];
        
        [self.registerView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Apple-Wood.png"]]];
        [self.closeRegister setHidden:YES];
        [self.view addSubview:self.registerView];
    } else if ([[NSUserDefaults standardUserDefaults] stringForKey:@"targetAddress"]) {
        NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:@"targetAddress"];
        [[MBBController sharedManager] parseTargetAddress:s];
        self.destinationAddress.text = [[MBBController sharedManager] targetAddress];
        [self.reRegister setHidden:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark --- ReRegister

- (IBAction)reRegister:(id)sender {
    CGRect frame = self.view.frame;
    [self backgroundTappedDown:nil];
    
    [self setTitle:NSLocalizedString(@"REGISTER", nil)];
    self.isRegister = YES;
    self.registerView = [[[NSBundle mainBundle] loadNibNamed:@"RegisterView" owner:self options:nil] objectAtIndex:0];
    [self.registerView setFrame:frame];
    [self.scrollView setFrame:self.view.frame];
    [self.scrollView setContentSize:CGSizeMake(320, 400)];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureCaptured:)];
    [self.scrollView addGestureRecognizer:singleTap];
    
    [self.registerView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Apple-Wood.png"]]];
    [self.view addSubview:self.registerView];
}

- (IBAction)closeRegister:(id)sender {
    [self backgroundTappedDown:nil];
    [self.registerView removeFromSuperview];
    [self.scrollView removeFromSuperview];
    self.scrollView = nil;
    self.registerView = nil;
    [self.view setUserInteractionEnabled:YES];
    
    self.isRegister = NO;
    [self setTitle:NSLocalizedString(@"LOGIN", nil)];
}

#pragma mark - Keyboard

- (IBAction)backgroundTappedDown:(id)sender {
    [self.username resignFirstResponder];
    [self.password resignFirstResponder];
    [self.halfKeyEntry resignFirstResponder];
    [self.destinationAddress resignFirstResponder];
    [self.companyToken resignFirstResponder];
    [self.companyID resignFirstResponder];
    [self.usernameRegistration resignFirstResponder];
    [self.passwordRegistration resignFirstResponder];
    [self.deviceNameInput resignFirstResponder];
    [self.deviceDescription resignFirstResponder];
    [self.targetAddress resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (self.isOffline) {
        [self.halfKeyEntry resignFirstResponder];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enterKey:self];
        });
    } else if (!self.isRegister) {
        if ([textField isEqual:self.destinationAddress]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self login:self];
            });
        } else if ([textField isEqual:self.username]) {
            [self.username resignFirstResponder];
            [self.password becomeFirstResponder];
        } else if ([textField isEqual:self.password]) {
            [self.password resignFirstResponder];
            [self.destinationAddress becomeFirstResponder];
        } else if ([textField isEqual:self.companyToken]) {
            [self.companyToken resignFirstResponder];
            [self.username becomeFirstResponder];
        }
    } else {
        if ([textField isEqual:self.companyID]) {
            [self.companyID resignFirstResponder];
            [self.usernameRegistration becomeFirstResponder];
        } else if ([textField isEqual:self.usernameRegistration]) {
            [self.usernameRegistration resignFirstResponder];
            [self.passwordRegistration becomeFirstResponder];
        } else if ([textField isEqual:self.passwordRegistration]) {
            [self.passwordRegistration resignFirstResponder];
            [self.deviceNameInput becomeFirstResponder];
        } else if ([textField isEqual:self.deviceNameInput]) {
            [self.deviceNameInput resignFirstResponder];
            [self.deviceDescription becomeFirstResponder];
        } else if ([textField isEqual:self.deviceDescription]) {
            [self.deviceDescription resignFirstResponder];
            [self.targetAddress becomeFirstResponder];
        } else if ([textField isEqual:self.targetAddress]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self registerDevice:self];
            });
        }
    }
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.activeField = nil;
}

- (void)keyboardWasShown:(NSNotification*)aNotification {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) return;
    
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIScrollView *view = self.scrollView == nil ? self.mainScrollView : self.scrollView;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    view.contentInset = contentInsets;
    view.scrollIndicatorInsets = contentInsets;
    
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, self.activeField.frame.origin) ) {
        [view scrollRectToVisible:self.activeField.frame animated:YES];
    }
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) return;
    
    UIScrollView *view = self.scrollView == nil ? self.mainScrollView : self.scrollView;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    view.contentInset = contentInsets;
    view.scrollIndicatorInsets = contentInsets;
}

- (void)swapToKeyEntry {
    CGRect frame = self.view.frame;
    
    self.isOffline = YES;
    self.offlineView = [[[NSBundle mainBundle] loadNibNamed:@"OfflineEntry" owner:self options:nil] objectAtIndex:0];
    [self.offlineView setFrame:frame];
    [self.offlineView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Apple-Wood.png"]]];
    [self.view addSubview:self.offlineView];
}

- (IBAction)goOnline:(id)sender {
    [[MBBController sharedManager] moveOnline];
    [[MBBController sharedManager] setLoginFrequency:LF_EVERY_RESUME_FROM_BACKGROUND];
    
    [self.offlineView removeFromSuperview];
    self.offlineView = nil;
    self.isOffline = NO;
    
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"targetAddress"]) {
        NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:@"targetAddress"];
        [[MBBController sharedManager] parseTargetAddress:s];
        self.destinationAddress.text = [[MBBController sharedManager] targetAddress];
        [self.reRegister setHidden:YES];
    }
}

- (IBAction)enterKey:(id)sender {
    NSString *d = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    d = [d stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:d]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:d];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    
    NSString *db = [d stringByAppendingPathComponent:@"FILES"];
    BOOL dbExist = [[NSFileManager defaultManager] fileExistsAtPath:db];
    if (!dbExist) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FAIL", nil) message:NSLocalizedString(@"NO_DATABASE", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE", nil) otherButtonTitles:nil] show];
        return;
    }
    
    NSString *s = [[NSString alloc] initWithString:[[MBBController sharedManager] encryptionKey]];
    NSString *key = [s stringByAppendingString:self.halfKeyEntry.text];
    NSString *r = [self setupDatabaseWithLicense:[[MBBController sharedManager] license] andKey:key];
    if ([r length] > 0) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FAIL", nil) message:r delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE", nil) otherButtonTitles:nil] show];
        return;
    }
    
    int status;
    int found_and_fixed;
    msdbmaintain("FILES",NULL,MSCLEAN_FULL,false,&status,&found_and_fixed);
    
    // test encryption key
    char *sql = "SELECT FILE_ID FROM CENTRAL";
    NSArray *result = [SQLHelper execQuery:sql useDB:"FILES"];
    if (result == nil) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"INCORRECT", nil) message:NSLocalizedString(@"INCORRECT_KEY", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE", nil) otherButtonTitles:nil] show];
        return;
    }
    
    [[MBBController sharedManager] setIsAuthenticated:YES];
    if (![[MBBController sharedManager] didLoad]) {
        [self.delegate didReturnLoginFinished];
        [[MBBController sharedManager] setIsAlertShowing:NO];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
        return;
    }
    
    [[MBBController sharedManager] downloadTheTreeListStoreLocalCompletionHandler:^(NSMutableArray *downloadObjects) {
        [self hideHUDView];
        
        SEL sel = @selector(didLoadLoginFinished);
        [[MBBController sharedManager] setDidLoad:NO];
        [self.delegate performSelector:sel];
        
        [[MBBController sharedManager] setIsAlertShowing:NO];
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (IBAction)login:(id)sender {
    if ([self.destinationAddress.text length] <= 5)
        return;
    if ([self.companyToken.text length] == 0)
        return;
    
    [self.username resignFirstResponder];
    [self.password resignFirstResponder];
    [self.destinationAddress resignFirstResponder];
    [self.companyToken resignFirstResponder];
    
    [[MBBController sharedManager] parseTargetAddress:self.destinationAddress.text];
    
    if ([self.username.text length] == 0 || [self.password.text length] == 0)
        return;
    
    NSString *username = self.username.text;
    NSString *password = self.password.text;
    
    NSString *uuid = [[[MBBController sharedManager] readIdentificationFile] stringByAppendingString:[[MBBController sharedManager] returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *token = [[MBBController sharedManager] deviceToken];
    if (token == nil || [token length] == 0) token = @"";
    
    CLLocationCoordinate2D l = [[[MBBController sharedManager] getLastLocation] coordinate];
    NSString *post = [NSString stringWithFormat:@"&iRequestType=1&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@&strPushToken=%@&strLatitude=%f&strLongitude=%f",username,password,self.companyToken.text,uuid,token,l.latitude,l.longitude];
    NSMutableURLRequest *request = [self createRequest:post];
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [hud setMode:MBProgressHUDModeIndeterminate];
    [hud setLabelText:NSLocalizedString(@"LOGINING", nil)];
    [hud setTag:101];
    [self.view setUserInteractionEnabled:NO];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue new] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        NSLog(@"%lu",(long)[r statusCode]);
        if (connectionError) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self displayError:connectionError];
                return;
            });
        } else {
            NSError *error;
            id object = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self displayError:error];
                    return;
                });
            } else {
                if ([object[@"iDataClean"] intValue] == 1) {
                    [MBBPushRegister handleDeleteNotice];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self displayError:nil];
                    });
                } else if ([self isCaseOne:object]) {
                    NSString *r = [self setupDatabaseWithLicense:object[@"strLicenseKey"] andKey:object[@"strEncryptionKey"]];
                    if ([r length] > 0) {
                        NSDictionary *d = [NSDictionary dictionaryWithObject:r forKey:NSLocalizedDescriptionKey];
                        NSError *error = [NSError errorWithDomain:@"SDB" code:1 userInfo:d];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self displayError:error];
                        });
                        return;
                    }
                    
                    [[MBBController sharedManager] setLicense:object[@"strLicenseKey"]];
                    NSString *d = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
                    d = [d stringByAppendingPathComponent:@"Mobisec"];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:d]) {
                        [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
                        NSURL *url = [NSURL fileURLWithPath:d];
                        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
                    }
                    
                    NSString *db = [d stringByAppendingPathComponent:@"FILES"];
                    BOOL dbExist = [[NSFileManager defaultManager] fileExistsAtPath:db];
                    
                    if (!dbExist) {
                        char *sql = "CREATE DATABASE 'FILES' cipher='AES128'";
                        if (![SQLHelper executeSQL:sql useDB:"-"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "CREATE TABLE CENTRAL (FILE_ID CHAR(64) ENCRYPTED, MODIFY_DATE VARCHAR(255), ISDOWNLOADED BOOLEAN, ISFIRSTLATEST BOOLEAN, PAGECOUNT INT)";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "CREATE TABLE PAGES (FILE_ID CHAR(64), PAGE_NUMBER CHAR(3), PAGE BINARY LARGE OBJECT (4M) ENCRYPTED)";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "CREATE TABLE BOOKMARKS (FILE_ID CHAR(64))";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "CREATE TABLE LASTOPEN (FILE_ID CHAR(64), PAGE_ID CHAR(3))";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "LOCK LEVEL ON CENTRAL IS NULL";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "LOCK LEVEL ON PAGES IS NULL";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "LOCK LEVEL ON BOOKMARKS IS NULL";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        sql = "LOCK LEVEL ON LASTOPEN IS NULL";
                        if (![SQLHelper executeSQL:sql useDB:"FILES"]) {
                            [self hideHUDView];
                            return;
                        }
                        
                        [[NSUserDefaults standardUserDefaults] setObject:[[MBBController sharedManager] targetAddress] forKey:@"targetAddress"];
                        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:1] forKey:@"APIVersion"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                    
                    int status;
                    int found_and_fixed;
                    msdbmaintain("FILES",NULL,MSCLEAN_FULL,false,&status,&found_and_fixed);
                    
                    [[MBBController sharedManager] setIsAuthenticated:YES];
                    [[MBBController sharedManager] setUsername:username];
                    [[MBBController sharedManager] setPassword:password];
                    [[MBBController sharedManager] setCompanyToken:self.companyToken.text];
                    [[MBBController sharedManager] fetchOfflineNotices];
                    
                    if (![[MBBController sharedManager] didLoad]) {
                        [self.delegate didReturnLoginFinished];
                        [[MBBController sharedManager] setIsAlertShowing:NO];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.navigationController popViewControllerAnimated:YES];
                        });
                        return;
                    }
                    
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [[MBProgressHUD HUDForView:self.view] setLabelText:NSLocalizedString(@"RETRIEVING_LIST", nil)];
                    });
                    
                    [[MBBController sharedManager] downloadTheTreeListStoreLocalCompletionHandler:^(NSMutableArray *downloadObjects) {
                        [self hideHUDView];
                        
                        SEL sel = @selector(didLoadLoginFinished);
                        [[MBBController sharedManager] setDidLoad:NO];
                        [self.delegate performSelector:sel];
                        
                        [[MBBController sharedManager] setIsAlertShowing:NO];
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
            }
        }
    }];
}

- (IBAction)registerDevice:(id)sender {
    [self.companyID resignFirstResponder];
    [self.usernameRegistration resignFirstResponder];
    [self.passwordRegistration resignFirstResponder];
    [self.deviceNameInput resignFirstResponder];
    [self.deviceDescription resignFirstResponder];
    [self.targetAddress resignFirstResponder];
    
    if ([[self.companyID text] length] == 0) {
        return;
    } else if ([[[self usernameRegistration] text] length] == 0) {
        return;
    } else if ([[[self passwordRegistration] text] length] == 0) {
        return;
    } else if ([[[self deviceNameInput] text] length] == 0) {
        return;
    } else if ([[[self deviceDescription] text] length] == 0) {
        return;
    } else if ([[[self targetAddress] text] length] <= 5) {
        return;
    }
    
    [[MBBController sharedManager] parseTargetAddress:self.targetAddress.text];
    
    if (self.companyID.text.length == 0 || self.usernameRegistration.text.length == 0 || self.passwordRegistration.text.length == 0 ||
        self.deviceNameInput.text.length == 0 || self.deviceDescription.text.length == 0 || self.targetAddress.text.length == 0)
        return;
    
    NSString *username = self.usernameRegistration.text;
    NSString *password = self.passwordRegistration.text;
    NSString *osInformation = [[[UIDevice currentDevice] systemName] stringByAppendingString:[[UIDevice currentDevice] systemVersion]];
    
    NSString *uuid = [[[MBBController sharedManager] readIdentificationFile] stringByAppendingString:[[MBBController sharedManager] returnCurrentDate]];
    uuid = [uuid stringFromMD5];
    
    NSString *token = [[MBBController sharedManager] deviceToken];
    if (token == nil || [token length] == 0) token = @"";
    
    CLLocationCoordinate2D l = [[[MBBController sharedManager] getLastLocation] coordinate];
    NSString *post = [NSString stringWithFormat:@"&iRequestType=0&strUserAccount=%@&strPassword=%@&strCompanyToken=%@&strUUID=%@&strTerminalName=%@&strTerminalDescription=%@&strOsInformation=%@&strPushToken=%@&strLatitude=%f&strLongitude=%f",username,password,self.companyID.text,uuid,self.deviceNameInput.text,self.deviceDescription.text,osInformation,token,l.latitude,l.longitude];
    NSMutableURLRequest *request = [self createRequest:post];
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [hud setMode:MBProgressHUDModeIndeterminate];
    [hud setLabelText:NSLocalizedString(@"REGISTERING", nil)];
    [hud setTag:101];
    [self.view setUserInteractionEnabled:NO];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue new] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self displayError:connectionError];
            });
        } else {
            NSError *e;
            NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&e];
            if (e) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self displayError:e];
                    return;
                });
            } else {
                if ([self validateRegistration:response]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [MBProgressHUD hideHUDForView:self.view animated:YES];
                        MBProgressHUD *hud = (MBProgressHUD *)[self.view viewWithTag:101];
                        hud = nil;
                        
                        // registration control
                        [FDKeychain saveItem:[NSNumber numberWithInteger:2] forKey:@"SoftVersion" forService:@"SDB" error:nil];
                        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"APIVersion"];
                        
                        NSString *url = [[MBBController sharedManager] targetAddress];
                        [[NSUserDefaults standardUserDefaults] setObject:url forKey:@"targetAddress"];
                        self.destinationAddress.text = url;
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        
                        [self.registerView removeFromSuperview];
                        self.registerView = nil;
                        [self.view setUserInteractionEnabled:YES];
                        
                        self.isRegister = NO;
                        [self.reRegister setHidden:YES];
                        [self setTitle:NSLocalizedString(@"LOGIN", nil)];
                    });
                }
            }
        }
    }];
}

- (void)displayError:(NSError *)error {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *hud = (MBProgressHUD *)[self.view viewWithTag:101];
    hud = nil;
    
    NSLog(@"%@",[error localizedDescription]);
    [self.view setUserInteractionEnabled:YES];
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FAIL", nil) message:[error localizedDescription] delegate:self cancelButtonTitle:NSLocalizedString(@"YES", nil) otherButtonTitles:nil] show];
}

- (void)hideHUDView {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view setUserInteractionEnabled:YES];
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            MBProgressHUD *hud = (MBProgressHUD *)[self.view viewWithTag:101];
            hud = nil;
            return;
        });
    }
    
    [self.view setUserInteractionEnabled:YES];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *hud = (MBProgressHUD *)[self.view viewWithTag:101];
    hud = nil;
}

- (BOOL)validateRegistration:(NSDictionary *)object {
    switch ([object[@"iAuthResult"] intValue]) {
        case 0:{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showLoginFailedDueToBadInformation];
            });
            return NO;
            break;}
        case 1:
            return YES;
            break;
        default:
            break;
    }
    return NO;
}

- (BOOL)isCaseOne:(id)object {
    switch ([[object objectForKey:@"iAuthResult"] intValue]) {
        case 0: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showLoginFailedDueToBadInformation];
            });
            return NO;
            break; }
        case 1:
            return YES;
            break;
        case 2: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                MBProgressHUD *hud = (MBProgressHUD *)[self.view viewWithTag:101];
                hud = nil;
                
                [self.view setUserInteractionEnabled:YES];
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"LOCK", nil) message:NSLocalizedString(@"LOCK_REASON", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"YES", nil) otherButtonTitles:nil] show];
            });
            return NO;
            break; }
        default:
            return NO;
            break;
    }
}

- (void)showLoginFailedDueToBadInformation {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *hud = (MBProgressHUD *)[self.view viewWithTag:101];
    hud = nil;
    
    [self.view setUserInteractionEnabled:YES];
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FAIL", nil) message:NSLocalizedString(@"FAIL_REASON", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"YES", nil) otherButtonTitles:nil] show];
}

#pragma mark ------------- Networking

- (NSMutableURLRequest *)createRequest:(NSString *)data {
    NSString *initial = [[MBBController sharedManager] targetAddress];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/terminal/auth",initial]]];
    
    [request setHTTPMethod:@"POST"];
    NSData *postData = [data dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [request setHTTPBody:postData];
    return request;
}

#pragma mark --- Rotation

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    CGRect r = CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
    [self.registerView setFrame:r];
    [self.scrollView setFrame:r];
    [self.scrollView setContentSize:CGSizeMake(320, 400)];
    
    [self.offlineView setFrame:r];
    [self.mainScrollView setFrame:r];
}

- (void)singleTapGestureCaptured:(UITapGestureRecognizer *)gesture {
    [self backgroundTappedDown:nil];
}

#pragma mark - Database Setup

- (NSString *)setupDatabaseWithLicense:(NSString *)license andKey:(NSString *)key {
    char *l = (char*)[license UTF8String];
    setenv("MSLICENCE", l, 1);
    if (![[MBBController sharedManager] isEmpressInit]) {
        if (!msinit()) {
            return [NSString stringWithFormat: @"(%d) %s\n", mroperr, mrerrmsg()];
        }
        
        NSLog(@"Initialized");
        [[MBBController sharedManager] setIsEmpressInit:YES];
        
        char *ky = (char*)[[key stringFromMD5] UTF8String];
        char *k = (char*)ky;
        
        NSString *dbp = [NSString stringWithFormat:@"/private%@/%@",[[MBBController sharedManager] workPath],@"FILES"];
        if (!mrsetdbcipherkeyinfo([dbp UTF8String], k)) {
            NSLog(@"Set Key has Failed!");
            return [NSString stringWithFormat: @"(%d) %s\n", mroperr, mrerrmsg()];
        }
        
        [[MBBController sharedManager] setEncryptionKey:[key stringFromMD5]];
    } else {
        msend();
        [[MBBController sharedManager] setIsEmpressInit:NO];
        return [self setupDatabaseWithLicense:license andKey:key];
    }
    
    return nil;
}

@end
