//
//  SQLHelper.h
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SQLHelper : NSObject

+ (NSArray *)execQuery:(char *)query useDB:(char *)db;
+ (Boolean)executeSQL:(char*)sql useDB:(char*)db;

@end
