# 说明
CAID(China Anonymization ID)是使用iOS系统非隐私参数，用一套统一规则生成的用于匿名化标识苹 果设备的ID。
在iOS生态中，开发者遵守统一生成规则对同一设备生成的ID相同，开发者之间通过CAID交互即可实现 同一设备的识别，用于满足各业务场景中设备标识的需要。
CAID的生成，不采集隐私数据，仅传输加密后的结果，且加密结果不可逆，可有效保护终端用户的隐私 和数据安全。
因为CAID不依赖于苹果IDFA，能独立于IDFA生成设备标识ID，可作为 iOS14 中设备标识的替代方案， 以及iOS14 以下获取不到IDFA时的补充方案，来提升获取设备ID的成功率。
本文档将介绍如果获取CAID生成所需的参数，及CAID生成的规则。 本文档适用于iOS 8.0及以上操作系统。

# 相关参数获取
## 所需头文件
···
#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <UIKit/UIDevice.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h> #import <CoreTelephony/CTCarrier.h>
#import <CommonCrypto/CommonDigest.h>
···

1. 手机型号
代码：
‘’‘
//device model
+ (NSString *) getDeviceModel {
    size_t size;
sysctlbyname("hw.machine", NULL, &size, NULL, 0);
char *machine = malloc(size);
sysctlbyname("hw.machine", machine, &size, NULL, 0); NSString *platform = [NSString stringWithCString:machine
encoding:NSUTF8StringEncoding];
    free(machine);
    return platform;
}
’‘’
