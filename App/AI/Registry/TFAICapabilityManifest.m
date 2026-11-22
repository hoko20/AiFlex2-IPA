#import "TFAICapabilityManifest.h"
#import "TFAIToolRegistry.h"

// 这是一份"自我描述"，只读。它回答三件事：现在有什么、确定做不到什么、哪些只能试了才知道。
// 所有结论都来自本轮 environment / 已注册 schema / 工具上下文，不做推测式扩张。

static BOOL Flag(NSDictionary *source, NSString *key) {
    return [source[key] isKindOfClass:NSNumber.class] && [source[key] boolValue];
}

static NSString *Text(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSDictionary *CapabilityEntry(NSDictionary *capabilities, NSString *key) {
    NSDictionary *entry = [capabilities[key] isKindOfClass:NSDictionary.class] ? capabilities[key] : nil;
    if (!entry) return @{@"state": @"unknown", @"source": @"本轮环境未提供"};
    return @{@"state": Text(entry[@"state"]).length ? Text(entry[@"state"]) : @"unknown",
             @"source": Text(entry[@"source"])};
}

static NSString *PresetLabel(NSString *preset) {
    if ([preset isEqual:@"full"] || [preset isEqual:@"full_push"] || [preset isEqual:@"full_download"] || [preset isEqual:@"full_network"]) return @"本会话已授权当前项目，写入/构建直接执行（上传下载仍按子权限）";
    if ([preset isEqual:@"scoped"]) return @"本会话已允许在选定文件范围内自动构建，源码修改仍要预览";
    if ([preset isEqual:@"ask"]) return @"只读：写入、构建、Git 变更都需要切换模式";
    return @"逐次批准：写入、构建、Git 变更每次都弹确认";
}

NSDictionary *TFAICapabilityManifest(NSDictionary *environment,
                                     NSArray *schemas,
                                     NSDictionary *toolContext,
                                     BOOL detailed) {
    environment = [environment isKindOfClass:NSDictionary.class] ? environment : @{};
    // 能力全集直接来自本轮 schema：工具没注册就不出现，operation 枚举也不手写，避免清单与实际漂移。
    NSMutableArray *names = [NSMutableArray new];
    NSMutableDictionary *operations = [NSMutableDictionary new];
    for (NSDictionary *schema in ([schemas isKindOfClass:NSArray.class] ? schemas : @[])) {
        if (![schema isKindOfClass:NSDictionary.class]) continue;
        NSString *name = Text(schema[@"name"]);
        if (!name.length || [names containsObject:name]) continue;
        [names addObject:name];
        NSDictionary *properties = [schema[@"parameters"][@"properties"] isKindOfClass:NSDictionary.class] ? schema[@"parameters"][@"properties"] : nil;
        NSArray *values = [properties[@"operation"][@"enum"] isKindOfClass:NSArray.class] ? properties[@"operation"][@"enum"] : nil;
        if (!values.count) continue;
        NSMutableDictionary *entry = [@{@"operations": values} mutableCopy];
        NSArray *gestures = [properties[@"kind"][@"enum"] isKindOfClass:NSArray.class] ? properties[@"kind"][@"enum"] : nil;
        if (gestures.count) entry[@"gestures"] = gestures;
        operations[name] = entry;
    }
    NSDictionary *context = [toolContext isKindOfClass:NSDictionary.class] ? toolContext : @{};

    NSDictionary *modelCapabilities = [environment[@"modelCapabilities"] isKindOfClass:NSDictionary.class] ? environment[@"modelCapabilities"] : @{};
    NSDictionary *permission = [environment[@"permission"] isKindOfClass:NSDictionary.class] ? environment[@"permission"] : @{};
    NSString *preset = Text(permission[@"preset"]).length ? Text(permission[@"preset"]) : @"assisted";
    NSString *mode = Text(environment[@"mode"]).length ? Text(environment[@"mode"]) : @"ask";
    BOOL readOnly = Flag(environment, @"recoveryReadOnly") || [mode isEqual:@"ask"];
    BOOL hasProject = Flag(environment, @"hasProject");
    BOOL flexContext = Flag(environment, @"flexContextAvailable");
    BOOL flexLive = Flag(environment, @"flexLiveAvailable");
    BOOL flexTouch = Flag(environment, @"flexTouchAvailable");
    // 环境里没有 toolContext 时（每轮精简注入）用 environment 的同类字段兜底。
    BOOL compiler = context.count ? Flag(context, @"compilerAvailable") : YES;
    BOOL sandbox = context.count ? Flag(context, @"sandboxAvailable") : NO;
    BOOL web = context.count ? Flag(context, @"webEnabled") : YES;
    BOOL remote = context.count ? Flag(context, @"remoteAvailable") : NO;
    BOOL isolation = context.count ? Flag(context, @"isolationEnabled") : NO;
    BOOL foreground = context.count ? Flag(context, @"foreground") : YES;

    NSMutableArray *can = [NSMutableArray new];
    NSMutableArray *cannot = [NSMutableArray new];
    NSMutableArray *unknown = [NSMutableArray new];

    // 恒定的硬边界：无论权限多高都不成立的能力。
    [cannot addObject:@"没有任意系统 shell：不能执行 make、brew、apt、xcodebuild，也不能运行新生成的二进制"];
    [cannot addObject:@"不能安装到真机、不能 respring；build_project 成功只代表编译打包通过，不代表已注入或运行"];
    [cannot addObject:@"不能读取未授权目录；文件夹授权是只读实时目录，不授予项目写权限"];
    [cannot addObject:@"不能解密 App Store 加密二进制；classdump 只恢复近似声明，Swift 与裁剪信息可能缺失"];
    [cannot addObject:@"不索取、不回显 API Key、PAT、证书、钥匙串明文"];
    [cannot addObject:@"不能创建 Git 远端或修改账号认证；没有对应工具就引导用户走界面"];

    if (readOnly) [cannot addObject:[mode isEqual:@"ask"] ? @"问答模式只读：写入、构建、Git 变更需要用户切换开发模式" : @"中断恢复轮只读：不重放修改、构建或上传"];
    else if (hasProject) [can addObject:@"在已关联项目内读取、提案、应用修改、本机构建 dylib/deb、本机 Git 提交"];
    else [cannot addObject:@"未关联项目：不能读写项目文件、构建或 Git；需先 list_projects 再 select_project"];

    if (!compiler) [cannot addObject:@"本机编译器组件缺失（clang/lld/SDK.zip 不齐）：当前无法构建，需先在软件内安装 SDK"];
    if (!sandbox) [cannot addObject:@"iSH Linux 环境不可用：没有终端、没有 Linux 命令"];
    if (!web) [cannot addObject:@"联网读取已关闭：web_read / web_search / github_query 不可用"];
    if (web && !readOnly) [can addObject:@"联网读取网页、搜索、按官方 API 查询 GitHub（只读，不做写入）"];
    if (remote) [can addObject:@"局域网远程服务在运行，插件端可连入本机 App"];
    if (isolation) [can addObject:@"可用隔离环境运行目标 App 与读取插件日志"];

    if (flexContext && flexLive) [can addObject:@"实时读取 FLEX 现场：视图树、屏幕元素、对象信息、类信息与已加载镜像"];
    else if (flexContext) [cannot addObject:@"FLEX 现场心跳已断开：只能读已发布的过期快照，需在目标 App 重新选择对象"];
    else [cannot addObject:@"当前没有 FLEX 现场：不能读目标 App 视图，也不能对它操作"];

    if (flexTouch) [can addObject:@"可投递真实触摸手势（点击/长按/拖动/缩放），但 delivered 不等于业务生效，须重新观察确认"];
    else if (flexContext) [cannot addObject:@"未声明触摸能力：不能投递手势，只能读取现场"];

    if (flexContext) [cannot addObject:@"FLEX 读取以外的目标 App 修改只能通过写插件实现，不能直接改目标 App 代码或数据"];

    // 需要调用/读取才知道的部分，明确标成"未验证"，避免模型把声明当事实。
    [unknown addObject:@"模型是否真的支持图片输入、工具调用与思考：见 model.capabilities 的 state 与 source，unknown 表示仅按模型族建议，未实测"];
    [unknown addObject:@"目标 App 是否允许注入、设备是否越狱：由配对端环境决定，只能从工具返回的错误判断"];
    [unknown addObject:@"插件侧对话窗口状态（是否收起、自动允许、屏幕常亮、targetReady）：需 chat_status"];
    [unknown addObject:@"SDK 与最低系统是否可用：以 read_project_config 与实际安装状态为准"];
    [unknown addObject:@"远端可达性与令牌有效性：只有真正上传/下载失败才能确认"];

    NSMutableDictionary *manifest = [@{
        @"version": @1,
        @"app": @{@"name": @"AiFlex2",
                  @"version": Text(environment[@"version"]),
                  @"build": Text(environment[@"build"]),
                  @"os": Text(environment[@"os"])},
        @"model": @{@"id": Text(environment[@"model"]),
                    @"name": Text(environment[@"modelName"]),
                    @"protocol": Text(environment[@"protocol"]),
                    @"capabilities": @{@"image": CapabilityEntry(modelCapabilities, @"image"),
                                       @"tools": CapabilityEntry(modelCapabilities, @"tools"),
                                       @"stream": CapabilityEntry(modelCapabilities, @"stream"),
                                       @"thinking": CapabilityEntry(modelCapabilities, @"thinking")}},
        @"permission": @{@"preset": preset,
                         @"lifetime": Text(permission[@"lifetime"]).length ? Text(permission[@"lifetime"]) : @"current_session",
                         @"approval": PresetLabel(preset),
                         @"readOnly": @(readOnly)},
        @"mode": mode,
        @"workspace": @{@"hasProject": @(hasProject),
                        @"foreground": @(foreground),
                        @"compiler": @(compiler),
                        @"sandbox": @(sandbox),
                        @"web": @(web),
                        @"remote": @(remote),
                        @"isolation": @(isolation)},
        @"flex": @{@"snapshot": @(flexContext),
                   @"live": @(flexLive),
                   @"touch": @(flexTouch),
                   @"targetApp": Text(environment[@"flexTargetApp"]),
                   @"selectionClass": Text(environment[@"flexSelectionClass"]),
                   @"sensitiveRead": @"逐次确认：截图、头文件、网络与沙箱内容属于敏感读取",
                   @"control": @"逐次确认：激活控件、滚动、窗口切换受控制授权约束"},
        @"tools": @{@"count": @(names.count), @"operations": operations},
        @"can": can,
        @"cannot": cannot,
        @"unknown": unknown,
        @"note": @"清单只反映本轮实际注册的工具与已确认环境；tools.operations 是当前可用的操作全集（与插件侧 MCP 暴露的同源），不在其中的操作没有注册，不要假设存在。can 之外不要声称已具备，unknown 里的项目不要当成已支持。清单不授予权限，也不能据此跳过确认。"
    } mutableCopy];

    if (detailed) {
        NSMutableDictionary *tools = [manifest[@"tools"] mutableCopy];
        tools[@"names"] = [names sortedArrayUsingSelector:@selector(compare:)];
        NSMutableArray *modules = [NSMutableArray new];
        for (NSString *module in TFAIToolRegistry.modules)
            [modules addObject:@{@"module": module, @"enabled": @([TFAIToolRegistry enabled:module])}];
        tools[@"modules"] = modules;
        manifest[@"tools"] = tools;
        manifest[@"raw"] = @{@"flexTouchAvailable": @(flexTouch),
                             @"attachmentCount": environment[@"attachmentReferenceCount"] ?: @0,
                             @"contextBudgetKiB": environment[@"contextPolicy"][@"textBudgetKiB"] ?: @0,
                             @"backgroundStatus": environment[@"backgroundStatus"] ?: @{}};
    }
    return manifest;
}
