#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
// App 侧唯一的插件连接：由 App 主动连到插件面板里的局域网地址（默认 127.0.0.1:8790）。
// 只保存一份地址与令牌，做存活检测与工具清单展示；不再维护 MCP 服务列表与会话授权。
@interface DXLanLink : NSObject
+ (instancetype)shared;
@property(nonatomic,copy) NSString *address;   // http://127.0.0.1:8790/mcp
@property(nonatomic,copy) NSString *token;     // 面板上的访问令牌，存钥匙串
@property(nonatomic) BOOL autoCheck;           // 打开页面/聊天页时自动检测一次
@property(nonatomic,readonly) NSDictionary *status;
// status: state(idle/checking/connected/failed) text detail tools checkedAt
- (void)probeWithCompletion:(nullable void (^)(NSDictionary *status, NSError *_Nullable error))completion;
- (void)forget;
// 只接受本机或私有网段地址，避免把令牌发到公网明文接口。
+ (BOOL)localURL:(NSURL *)url;
// 本机回环 + 当前 Wi-Fi 地址，供快速填入。
+ (NSArray<NSString *> *)suggestions;
@end
UIViewController *DXLanLinkController(void);
NS_ASSUME_NONNULL_END
