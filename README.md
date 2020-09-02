# 说明
        CAID(China Anonymization ID)是使用iOS系统非隐私参数，用一套统一规则生成的用于匿名化标识苹 果设备的ID。
        在iOS生态中，开发者遵守统一生成规则对同一设备生成的ID相同，开发者之间通过CAID交互即可实现 同一设备的识别，用于满足各业务场景中设备标识的需要。    
        CAID的生成，不采集隐私数据，仅传输加密后的结果，且加密结果不可逆，可有效保护终端用户的隐私 和数据安全。
        因为CAID不依赖于苹果IDFA，能独立于IDFA生成设备标识ID，可作为 iOS14 中设备标识的替代方案， 以及iOS14 以下获取不到IDFA时的补充方案，来提升获取设备ID的成功率。
        本文档将介绍如果获取CAID生成所需的参数，及CAID生成的规则。 本文档适用于iOS 8.0及以上操作系统。

# CAID的生成
## 生成CAID所依赖的设备指纹项
- 手机型号：例如：iPhone7,2
- 手机系统版本：例如：12.4.5
- 硬盘存储容量：例如63989469184
- 运营商名称：例如：中国联通 
- 系统更新时间：例如：1584021510.578670
- 系统启动时间：例如：1596547081
- 手机用户名：例如：rakeen的iphone
- 手机国家代码：例如：CN
- 设备内存大小：例如：1037041664
## 生成CAID的算法
        版本号_md5（硬盘存储容量++手机型号++设备内存大小++手机系统版本++系统更新时间）_md5(md5(手机用户名)++运营商名称++手机国家代码++系统启动时间)
        版本号当前为00，其中的“md5”是指用md5算法对数据进行hash，其结果用16进制表示成长度为32的由[0-9][A-F]组成的字符串（全部使用大写）
        CAID例子：00_6AC3BA5F0D4B9194D3867E2AEC7F5B20_955EAED409D0B4400EB6CBC71094B1F1
## CAID在App的客户端的缓存及更新
        可以将CAID缓存在客户端的KeyChain中
        当新生成的CAID与KeyChain中的缓存不一致时，可以通知服务器端进行更新

# 相关参数获取
## 所需头文件

        #import <Foundation/Foundation.h>  

        #import <sys/sysctl.h>  

        #import <UIKit/UIDevice.h>  

        #import <CoreTelephony/CTTelephonyNetworkInfo.h>  

        #import <CoreTelephony/CTCarrier.h>  

        #import <CommonCrypto/CommonDigest.h>

`

1. 手机型号
代码：

        //device model
        + (NSString *) getDeviceModel {
                size_t size;
                sysctlbyname("hw.machine", NULL, &size, NULL, 0);
                char *machine = malloc(size);
                sysctlbyname("hw.machine", machine, &size, NULL, 0); 
                NSString *platform = [NSString stringWithCString:machine
                        encoding:NSUTF8StringEncoding];
                free(machine);
                return platform;
        }
   
   
2. 手机系统版本  
代码：

        //device system version
        + (NSString *) getSystemVersion {
                return [NSString stringWithFormat:@"%@",[UIDevice currentDevice].systemVersion]; 
        }

3. 硬盘存储容量
代码：

        //file system size
        +(NSString *)getDiskSize {
                int64_t space = -1;
                NSError *error = nil;
                NSDictionary *attrs = [[NSFileManager defaultManager]
                        attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
                if (!error) {
                        space = [[attrs objectForKey:NSFileSystemSize] longLongValue];
                }
                if(space < 0) { 
                        space = -1;
                }
                return [NSString stringWithFormat:@"%lld",space];
        }

4. 运营商信息
代码：

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
                        CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init]; CTCarrier *carrier = nil;
                        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 12.1) {
                                if ([info respondsToSelector:@selector(serviceSubscriberCellularProviders)]) { #pragma clang diagnostic push
                                        #pragma clang diagnostic ignored "-Wunguarded-availability-new"
                                        NSArray *carrierKeysArray = [info.serviceSubscriberCellularProviders.allKeys
                                                sortedArrayUsingSelector:@selector(compare:)];
                                        carrier = info.serviceSubscriberCellularProviders[carrierKeysArray.firstObject]; 
                                        if (!carrier.mobileNetworkCode) {
                                                carrier = info.serviceSubscriberCellularProviders[carrierKeysArray.lastObject];
                                        }
                                        #pragma clang diagnostic pop
                                } 
                        }
                        if(!carrier) {
                                #pragma clang diagnostic push
                                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                                carrier = info.subscriberCellularProvider; #pragma clang diagnostic pop
                        }
                        if (carrier != nil) {
                                NSString *networkCode = [carrier mobileNetworkCode];
                                NSString *countryCode = [carrier mobileCountryCode];
                                if (countryCode && [countryCode isEqualToString:@"460"] &&networkCode) {
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
                                carr = @"unknown";
                        }
                        dispatch_semaphore_signal(semaphore);
                });
                dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, 0.5* NSEC_PER_SEC);
                dispatch_semaphore_wait(semaphore, t);
                return [carr copy];
                #endif
            }

5.系统版本更新时间 代码:

        //system update time
        +(NSString *)getSysU {
                NSString *result = nil;
                NSString *information =
                        @"L3Zhci9tb2JpbGUvTGlicmFyeS9Vc2VyQ29uZmlndXJhdGlvblByb2ZpbGVzL1B1YmxpY0luZm8vTU
                                NNZXRhLnBsaXN0";
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
6.手机开机时间(会有秒级误差?) 
代码:

        //system boot time
        +(NSString *) getSysB {
                struct timeval boottime;
                int mib[2] = {CTL_KERN, KERN_BOOTTIME};
                size_t size = sizeof(boottime);
                time_t uptime = -1;
                if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0) {
                        uptime = boottime.tv_sec; 
                }
                NSString *result = [NSString stringWithFormat:@"%ld",uptime];
                return result;
        }
  
7.手机用户名摘要(MD5后上报) 
代码:

        //device user name
        +(NSString *) getDeviceUName {
                NSString *result = [NSString stringWithFormat:@"%@",[UIDevice currentDevice].name];
                return [[self class] getMD5:result ? result : @"unknown"];
        }
8.手机国家代码 
代码:

        //country coude
        +(NSString *)getCountryCode {
                NSLocale *currentLocale = [NSLocale currentLocale];
                NSString *countryCode = [currentLocale objectForKey:NSLocaleCountryCode];
                return countryCode;
        }
9.设备内存大小 
代码:

        //device RAM
        +(NSString *)getRAM {
                unsigned long long physicalMemory = [[NSProcessInfo processInfo] physicalMemory];
                NSString *strResult = [NSString stringWithFormat:@"%llu",physicalMemory];
                return [strResult copy];
        }
