#import <Foundation/Foundation.h>

// 本轮能力清单：把"现在到底能做什么"整理成可读、可判定的结构，供模型自省。
// 只描述已注册工具与已确认的运行环境，不授予任何权限；清单本身是只读数据。
//
// environment: AIRuntime.promptEnvironment（含 model/protocol/permission/mode/flex* 等）
// toolNames:   本轮实际发送给模型的 schema 名称（硬边界的来源）
// toolContext: TFAIToolContext() 的返回；为 nil 时退化为只看 environment
// detailed:    YES 时附带工具名、模块开关与逐项来源，用于 read_app_state；NO 为每轮注入的精简版
FOUNDATION_EXPORT NSDictionary *TFAICapabilityManifest(NSDictionary *environment,
                                                       NSArray<NSString *> *toolNames,
                                                       NSDictionary *toolContext,
                                                       BOOL detailed);
