//
//  AppDelegate.m
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "AppDelegate.h"
#import "MBBController.h"
#import "AuthViewController.h"
#import "MBBPushRegister.h"

#import "NSString+MD5Addition.h"
#import "FDKeychain.h"

#import "RNDecryptor.h"
#import "RNEncryptor.h"

@interface AppDelegate ()
@property (nonatomic, strong) UIImageView *placeHolder;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[MBBController sharedManager] setLoginFrequency:LF_EVERY_RESUME_FROM_BACKGROUND];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings *s = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
        [application registerUserNotificationSettings:s];
        [application registerForRemoteNotifications];
    } else { 
        [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert];
    }
    
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documents]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSURL *url = [NSURL fileURLWithPath:documents];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }

    // generate UUID
    documents = [documents stringByAppendingPathComponent:@"Identification"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documents]) {
        NSString *uuid = [[NSUUID UUID] UUIDString];
        [uuid writeToFile:documents atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
    
    [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"Aged-Paper"] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    [[UIToolbar appearance] setTintColor:[UIColor whiteColor]];
    [[UIToolbar appearance] setBackgroundImage:[UIImage imageNamed:@"Aged-Paper"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    UIImageView *i = [[UIImageView alloc] initWithFrame:self.window.frame];
    [i setImage:[UIImage imageNamed:@"background"]];
    self.placeHolder = i;
    [self.window addSubview:self.placeHolder];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (self.placeHolder) {
        [self.placeHolder removeFromSuperview];
        self.placeHolder = nil;
    }
    
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documents]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:documents];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
        return;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:documents error:nil];
    if (![[attributes objectForKey:NSURLIsExcludedFromBackupKey] boolValue]) {
        NSURL *url = [NSURL fileURLWithPath:documents];
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [MBBPushRegister registerPushNotificationWithTokenData:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (application.applicationState == UIApplicationStateActive) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"INFO", nil) message:userInfo[@"aps"][@"alert"] delegate:nil cancelButtonTitle:NSLocalizedString(@"CLOSE", nil) otherButtonTitles:nil] show];
    }
    completionHandler(UIBackgroundFetchResultNewData);
}

@end
