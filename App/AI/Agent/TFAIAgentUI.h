#import <UIKit/UIKit.h>
UIViewController *TFAIAgentSettingsController(NSString *root,NSString *sessionID);
UIViewController *TFAIAgentSettingsControllerWithBrowserAction(NSString *root,NSString *sessionID,void (^onAsk)(NSString *url));
// 直接打开「MCP 服务」列表页（服务管理、工具授权、会话开关），不再绕 Agent 能力首页。
UIViewController *TFAIMCPServicesController(NSString *sessionID);
