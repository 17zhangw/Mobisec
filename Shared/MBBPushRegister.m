//
//  MBBPushRegister.m
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import "MBBPushRegister.h"
#import "MBBController.h"

#import <CommonCrypto/CommonHMAC.h>
#import "RNEncryptor.h"
#import "NSString+MD5Addition.h"
#import "FDKeychain.h"

@implementation MBBPushRegister

+ (void)registerPushNotificationWithTokenData:(NSData *)data {
    NSString *token = [[[data description] 
                        stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]]
                        stringByReplacingOccurrencesOfString:@" "
                        withString:@""];
    [[MBBController sharedManager] setDeviceToken:token];
}

+ (void)handleSilentPushNotification:(NSDictionary *)push {
    
}

+ (void)handleDeleteNotice {
    NSString *d = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    d = [d stringByAppendingPathComponent:@"Mobisec"];
    d = [d stringByAppendingPathComponent:@"FILES"];
    [[NSFileManager defaultManager] removeItemAtPath:d error:nil];
    
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    [[NSFileManager defaultManager] removeItemAtPath:[documents stringByAppendingPathComponent:@"info.dat"] error:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"targetAddress"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documents = [documents stringByAppendingPathComponent:@"Mobisec"];
    NSString *photoDirectory = [documents stringByAppendingPathComponent:@"PHOTOS"];
    [[NSFileManager defaultManager] removeItemAtPath:photoDirectory error:nil];
}

+ (NSString *)reverseString:(NSString *)name {
    int len = [name length];
    NSMutableString *reverseName = [[NSMutableString alloc] initWithCapacity:len];
    for(int i=len-1;i>=0;i--) {
        [reverseName appendString:[NSString stringWithFormat:@"%c",[name characterAtIndex:i]]];
    }
    return reverseName;
}

@end
