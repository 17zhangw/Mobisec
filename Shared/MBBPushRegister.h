//
//  MBBPushRegister.h
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MBBPushRegister : NSObject

+ (void)registerPushNotificationWithTokenData:(NSData *)data;
+ (void)handleSilentPushNotification:(NSDictionary *)push;
+ (void)handleDeleteNotice;

@end
