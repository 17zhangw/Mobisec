//
//  SQLHelper.m
//  Mobisec
//
//  Copyright (c) 2015 William Zhang. All rights reserved.
//

#import "SQLHelper.h"

@implementation SQLHelper

+ (NSArray *)execQuery:(char *)query useDB:(char *)db {
    int		i;
	int		flg;
	char*		s;
	mrretrdes*	ret;
    
	if (ptrnil(ret = mrexecquery(db, query, NULL)))
	{
        NSLog(@"Exec Query Failed");
        NSLog(@"%@",[NSString stringWithFormat: @"(%d) %s\n", mroperr, mrerrmsg()]);
		return nil;
	}
    
    NSMutableArray *array = [NSMutableArray array];
	int ncols = mrrsget_ncols (ret);
	
	while ((flg = mrget(ret)) == MSMR_GET_OK)
	{
		for (i = 1; i <= ncols; i++)
		{
            s = mrrsget_string (ret, i);
            NSString *ss;
            if (s != NULL)
                ss = [NSString stringWithUTF8String:s];
            else
                ss = @"";
            char* attr_name;
            mrrsget_colinfo(ret, i, &attr_name,NULL,NULL);
            
            [array addObject:ss];
		}
	}
    
	if (flg != MSMR_GET_EOR) {
		mrgetend (ret);
        NSLog(@"%@",[NSString stringWithFormat: @"(%d) %s\n", mroperr, mrerrmsg()]);
        return nil;
	}
    
	mrgetend (ret);
	return array;
}

+ (Boolean)executeSQL:(char*)sql useDB:(char*)db {
    if (!mrexecdirect(db, sql)) {
        NSLog(@"Failed!");
        NSLog(@"%@",[NSString stringWithFormat: @"(%d) %s\n", mroperr, mrerrmsg()]);
        return NO;
    } else {
        NSLog(@"Succeeded!");
        return YES;
    }
}

@end
