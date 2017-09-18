//
//  NSURLRequest+AllowAnyHTTP.m
//  QV-Pocket
//
//  Copyright © 2016 iData. All rights reserved.
//

#import "NSURLRequest+AllowAnyHTTP.h"

@implementation NSURLRequest (AllowAnyHTTP)
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString*)host
{
    return YES;
}
@end
