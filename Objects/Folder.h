//
//  Folder.h
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Folder : NSObject

@property (nonatomic) NSString *folderName;

@property (nonatomic) int folderID;
@property (nonatomic) int folderLevel;
@property (nonatomic) int parentID;

@property (nonatomic) NSString *folderDescription;
@property (nonatomic) NSMutableArray *children;

@property (nonatomic) NSString *createDate;
@property (nonatomic) NSString *modifyDate;

@end
