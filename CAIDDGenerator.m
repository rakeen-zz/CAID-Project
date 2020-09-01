//
//  CAIDDGenerator.m
//  Params
//
//  Created by jesse on 2020/7/17.
//  Copyright © 2020 none. All rights reserved.
//

#import "CAIDDGenerator.h"
#import <sys/sysctl.h>
#import <UIKit/UIDevice.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <CommonCrypto/CommonDigest.h>

@implementation CAIDDGenerator

#pragma mark utils

//object to json string
+ (NSString *)objToString:(id)obj {
    NSError *error = nil;
    NSData *data = nil;
    NSString *ret = nil;
    @try {
        data = [NSJSONSerialization dataWithJSONObject:[self convertToJson:obj]
                                               options:(NSJSONWritingOptions)0
                                                 error:&error];
    }
    @catch (NSException *exception) {
        NSLog(@"exception jso:%@", exception);
    }
    if (error) {
        NSLog(@"error jso:%@", error);
    } else {
        ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return ret;
}

//convert foundation to json type
+ (id)convertToJson:(id)obj {
    if ([obj isKindOfClass:NSString.class] || [obj isKindOfClass:NSNumber.class] || [obj isKindOfClass:NSNull.class]) {
        return obj;
    }
    if ([obj isKindOfClass:NSArray.class]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self convertToJson:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey = key;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                NSLog(@"property key error:%@",stringKey);
            }
            id v = [self convertToJson:obj[key]];
            d[stringKey] = v;
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }
    NSString *s = [obj description];
    NSLog(@"property values error:%@", s);
    return s;
}

static NSLock *objectLocker;

+(NSLock *) getObjLocker {
    static dispatch_once_t onceObjLocler;
    dispatch_once(&onceObjLocler, ^{
        objectLocker = [[NSLock alloc] init];
    });
    return objectLocker;
}

static void *queueSpecKey = nil;

+(dispatch_queue_t) getSerQueue {
    static dispatch_once_t once;
    static dispatch_queue_t _request_queue;
    dispatch_once(&once, ^{
        _request_queue = dispatch_queue_create([[NSString stringWithFormat:@"com.caid.%@", self] UTF8String], NULL);
        void *nonNullUnusedPointer = (__bridge void *)self;
        queueSpecKey = &queueSpecKey;
        dispatch_queue_set_specific(_request_queue, queueSpecKey, nonNullUnusedPointer, NULL);
    });
    return _request_queue;
}

static bool check_nsstring(NSString *arg) {
    if (!arg || ![arg isKindOfClass:[NSString class]]
        || ![arg respondsToSelector:@selector(length)] || arg.length == 0) {
        return false;
    }
    return true;
}

#pragma mark params

//device model
+ (NSString *) getDeviceModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return platform;
}

//device system version
+ (NSString *) getSystemVersion {
    return [NSString stringWithFormat:@"%@",[UIDevice currentDevice].systemVersion];
}

//file system size
+(NSString *)getDiskSize {
    int64_t space = -1;
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (!error) {
        space = [[attrs objectForKey:NSFileSystemSize] longLongValue];
    }
    if(space < 0) {
        space = -1;
    }
    return [NSString stringWithFormat:@"%lld",space];
}

//carrier
+(NSString* )getCarrierName {
    #if TARGET_IPHONE_SIMULATOR
        return @"SIMULATOR";
    #else
    static dispatch_queue_t _queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _queue = dispatch_queue_create([[NSString stringWithFormat:@"com.carr.%@", self] UTF8String], NULL);
    });
    __block NSString *  carr = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(_queue, ^(){
        CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = nil;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 12.1) {
            if ([info respondsToSelector:@selector(serviceSubscriberCellularProviders)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
                NSArray *carrierKeysArray = [info.serviceSubscriberCellularProviders.allKeys sortedArrayUsingSelector:@selector(compare:)];
                carrier = info.serviceSubscriberCellularProviders[carrierKeysArray.firstObject];
                if (!carrier.mobileNetworkCode) {
                    carrier = info.serviceSubscriberCellularProviders[carrierKeysArray.lastObject];
                }
#pragma clang diagnostic pop
            }
        }
        if(!carrier) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored  "-Wdeprecated-declarations"
            carrier = info.subscriberCellularProvider;
#pragma clang diagnostic pop
        }
        if (carrier != nil) {
            NSString *networkCode = [carrier mobileNetworkCode];
            NSString *countryCode = [carrier mobileCountryCode];
            
            if (countryCode && [countryCode isEqualToString:@"460"] && networkCode) {
            
                if ([networkCode isEqualToString:@"00"] || [networkCode isEqualToString:@"02"] || [networkCode isEqualToString:@"07"] || [networkCode isEqualToString:@"08"]) {
                    carr= @"中国移动";
                }
                if ([networkCode isEqualToString:@"01"] || [networkCode isEqualToString:@"06"] || [networkCode isEqualToString:@"09"]) {
                    carr= @"中国联通";
                }
                if ([networkCode isEqualToString:@"03"] || [networkCode isEqualToString:@"05"] || [networkCode isEqualToString:@"11"]) {
                    carr= @"中国电信";
                }
                if ([networkCode isEqualToString:@"04"]) {
                    carr= @"中国卫通";
                }
                if ([networkCode isEqualToString:@"20"]) {
                    carr= @"中国铁通";
                }
            }else {
                carr = [carrier.carrierName copy];
            }
        }
        if (carr.length <= 0) {
            carr =  @"unknown";
        }
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_time_t  t = dispatch_time(DISPATCH_TIME_NOW, 0.5* NSEC_PER_SEC);
    dispatch_semaphore_wait(semaphore, t);
    return [carr copy];
#endif
}

//system update time
+(NSString *)getSysU {
    NSString *result = nil;
    NSString *information = @"L3Zhci9tb2JpbGUvTGlicmFyeS9Vc2VyQ29uZmlndXJhdGlvblByb2ZpbGVzL1B1YmxpY0luZm8vTUNNZXRhLnBsaXN0";
    NSData *data=[[NSData alloc]initWithBase64EncodedString:information options:0];
    NSString *dataString = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:dataString error:&error];
    if (fileAttributes) {
        id singleAttibute = [fileAttributes objectForKey:NSFileCreationDate];
        if ([singleAttibute isKindOfClass:[NSDate class]]) {
            NSDate *dataDate = singleAttibute;
            result = [NSString stringWithFormat:@"%f",[dataDate timeIntervalSince1970]];
        }
    }
    return result;
}

//system boot time
+(NSString *) getSysB {
    struct timeval boottime;
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    size_t size = sizeof(boottime);
    time_t uptime = -1;
    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0)
    {
        uptime = boottime.tv_sec;
    }
    NSString *result = [NSString stringWithFormat:@"%ld",uptime];
    return result;
}


//device user name
+(NSString *) getDeviceUName {
    NSString *result = [NSString stringWithFormat:@"%@",[UIDevice currentDevice].name];
    return [[self class] getMD5:result  ? result : @"unknown"];
}

//device RAM
+(NSString *)getRAM {
    size_t size = sizeof(long);
    unsigned long results;
    int mib[2] = {CTL_HW, HW_PHYSMEM};
    sysctl(mib, 2, &results, &size, NULL, 0);
    return [NSString stringWithFormat:@"%lu",results];
}

//country coude
+(NSString *)getCountryCode {
    NSLocale *currentLocale = [NSLocale currentLocale];
    NSString *countryCode = [currentLocale objectForKey:NSLocaleCountryCode];
    return countryCode;
}

+(NSString *)getStringTotal {
    NSString *disk = [[self class] getDiskSize];
    NSString *model = [[self class] getDeviceModel];
    NSString *mem = [[self class] getRAM];
    NSString *v = [[self class] getSystemVersion];
    NSString *sysU = [[self class] getSysU];
    
    NSString *source1 = [NSString stringWithFormat:@"%@++%@++%@++%@++%@",disk,model,mem,v,sysU];
    NSLog(@"source1:%@",source1);
    NSString *param1 = [[self class] getMD5:source1 ? source1 : @"unknown"];
    NSLog(@"param1:%@",param1);
    
    NSString *uName = [[self class] getDeviceUName];
    NSString *carrier = [[self class] getCarrierName];
    NSString *country = [[self class] getCountryCode];
    NSString *sysB = [[self class] getSysB];
    
    NSString *source2 = [NSString stringWithFormat:@"%@++%@++%@++%@",uName,carrier,country,sysB];
    NSLog(@"source2:%@",source2);
    NSString *param2 = [[self class] getMD5:source2 ? source2 : @"unknown"];
    NSLog(@"param2:%@",param2);
    
    NSString *result = [NSString stringWithFormat:@"%@_%@",param1,param2];
    NSLog(@"result:%@",result);
    return result;
}

+(NSString *)getMD5:(NSString *)source {
    if (!check_nsstring(source)) {
        return nil;
    }
    const char *cStr = [source UTF8String];
    if (cStr == NULL) {
        return nil;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    return result;
}

#pragma mark security cache

static NSString * const caid_service = @"com.data.caid.service";
static NSString * const caid_account_source = @"com.data.caid.account.source";

+(BOOL) cacheSource:(NSString *)source {
    return [[self class] set:source service:caid_service acc:caid_account_source];
}

+(NSString *) cachedSource {
    return [[self class] pForService:caid_service acc:caid_account_source];
}

//setPassword:forService:account:
+ (BOOL)set:(NSString *)passwordString service:(NSString *)v acc:(NSString *)t{
    OSStatus status = -1001;
    NSData *password = [passwordString dataUsingEncoding:NSUTF8StringEncoding];
    if (password && v && t) {
        [self del:v acc:t];
        NSMutableDictionary *query = [self _qForService:v acc:t];
        [query setObject:password forKey:(__bridge id)kSecValueData];
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    return (status == errSecSuccess);
}

//deletePasswordForService:account:
+ (BOOL)del:(NSString *)s acc:(NSString *)a {
    OSStatus status = -1001;
    if (s && a) {
        NSMutableDictionary *query = [self _qForService:s acc:a];
        status = SecItemDelete((__bridge CFDictionaryRef)query);
    }
    return (status == errSecSuccess);
}

//passwordForService:account
+ (NSString *)pForService:(NSString *)s acc:(NSString *)a {
    OSStatus status = -1001;
    if (!s || !a) {
        return nil;
    }
    CFTypeRef result = NULL;
    NSMutableDictionary *query = [self _qForService:s acc:a];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != noErr) {
        return nil;
    }
    NSData *resultData = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
}

//_queryForService:account:
+ (NSMutableDictionary *)_qForService:(NSString *)s acc:(NSString *)a {
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:3];
    [dic setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    if (s) {
        [dic setObject:s forKey:(__bridge id)kSecAttrService];
    }
    if (a) {
        [dic setObject:a forKey:(__bridge id)kSecAttrAccount];
    }
    return dic;
}

#pragma mark public interface

//获取设备实时CAID
+(NSString *) currentCAID {
    NSString *totalString = [[[self class] getStringTotal] copy];
    return [NSString stringWithFormat:@"%@_%@",CAID_VERSION,totalString];
}

//获取缓存在钥匙链的 CAID
+(NSString *) cachedCAID {
    __block NSString *result = nil;
    if (dispatch_get_specific(queueSpecKey)) {
        result = [[[self class] cachedSource] copy];
    }else {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        dispatch_async([[self class] getSerQueue], ^{
            result = [[[self class] cachedSource] copy];
            dispatch_semaphore_signal(semaphore);
        });
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, .5f* NSEC_PER_SEC));
    }
    return result;
}

+(void)cacheCAID:(NSString *)current {
    if (!check_nsstring(current)) {
        NSLog(@"function cacheCAID: param is invalid!!");
        return;
    }
    NSString *currentCAID = [current copy];
    dispatch_async([[self class] getSerQueue], ^{
        [[self class] cacheSource:currentCAID];
    });
}

@end
