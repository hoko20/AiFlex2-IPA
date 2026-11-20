#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 远程构建配置（NSUserDefaults）。服务器地址默认留空，首次使用必须填写。
NSString *DXRemoteBuildServer(void);
void DXRemoteBuildSetServer(NSString *server);
NSString *DXRemoteBuildScheme(void);   // rootful | rootless | roothide
void DXRemoteBuildSetScheme(NSString *scheme);
NSString *DXRemoteBuildArch(void);     // fat | arm64 | arm64e
void DXRemoteBuildSetArch(NSString *arch);
NSString *DXRemoteBuildInject(void);   // jailbreak | ipa_substrate | ipa_standalone
void DXRemoteBuildSetInject(NSString *inject);
BOOL DXRemoteBuildConfigured(void);

// 连通性测试；completion 回主队列。
void DXRemoteBuildProbe(void (^completion)(BOOL ok, NSString *message));

// 上传本机工程 → 服务器 Theos 编译 → 下载产物到 Documents/RemoteBuilds。
// progress / completion 均回主队列。
@interface DXRemoteBuildJob : NSObject
+ (instancetype)runProject:(NSString *)root
                  progress:(void (^)(NSString *line))progress
                completion:(void (^)(BOOL success, NSArray<NSString *> *localArtifacts, NSString *summary))completion;
- (void)cancel;
@end

NS_ASSUME_NONNULL_END
