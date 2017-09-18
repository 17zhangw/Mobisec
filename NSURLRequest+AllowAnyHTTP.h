//
//  NSURLRequest+AllowAnyHTTP.h
//  QV-Pocket
//
//  Copyright © 2016 iData. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (AllowAnyHTTP)
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString*)host;
@end
