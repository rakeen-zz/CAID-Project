//
//  CAIDDGenerator.h
//  Params
//
//  Created by jesse on 2020/7/17.
//  Copyright © 2020 none. All rights reserved.
//

#define CAID_VERSION @"00"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CAIDDGenerator : NSObject

+(NSString *) currentCAID;

+(NSString *) cachedCAID;

+(void)cacheCAID:(NSString *)current;

@end

NS_ASSUME_NONNULL_END
