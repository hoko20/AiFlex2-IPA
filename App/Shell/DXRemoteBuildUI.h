#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 设置 → 构建 → 远程构建
UIViewController *DXRemoteBuildSettingsController(void);
// 工程卡片菜单「远程构建」进入的日志页
UIViewController *DXRemoteBuildLogController(NSString *projectRoot);

NS_ASSUME_NONNULL_END
