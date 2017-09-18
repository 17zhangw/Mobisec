//
//  File.m
//  Mobisec
//
//  Copyright (c) 2015 williamzhang. All rights reserved.
//

#import "File.h"

@implementation File

- (NSString *)description {
    NSString *s = [NSString stringWithFormat:@"File ID: %d\\n Is Downloaded: %@\\nCan Download: %@",_fileID,_isDownloaded ? @"YES" : @"NO",_canDownload ? @"YES":@"NO"];
    return s;
}

@end
