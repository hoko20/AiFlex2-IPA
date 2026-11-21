# AiFlex2 接入远程 Theos 打包服务（网页版后端）

## 1. 目标

让 AiFlex2 IPA 在保留「本机编译」的同时，新增「远程构建」通道：把本机工程打包上传到用户自行配置的 PHP + Theos 打包站（`<你的打包站>/api.php`，地址在 App 设置页填写，不内置任何具体域名），由服务器完成 Theos 编译，App 下载 deb/dylib 到本机并出现在「产物」页。

不新写服务端。只做客户端对接。

## 2. 已确认的服务端契约（来自 api.php，只读）

| 项 | 值 |
| --- | --- |
| 入口 | `<base>/api.php`，仅接受 POST |
| 反爬校验 | `Referer` 的 host 必须等于 `HTTP_HOST`，否则 403 HTML |
| `action=upload_project` | multipart 字段 `project_zip`（≤50MB，必须真 ZIP）→ `{"success":true,"project_name":"upload_..."}` |
| `action=build` | `mode=select` 时必填 `project_name` / `makefile` / `control`，可选 `tweak_xm`、`filter_plist`；另有 `target=deb|dylib`、`inject_mode=jailbreak|ipa_substrate|ipa_standalone`、`arch_mode=fat|arm64|arm64e`、`package_scheme=rootful|rootless|roothide` |
| build 响应 | 纯文本 `日志内容 + "|" + 结果HTML`（不是 JSON）；成功时 HTML 内含 `/deb_files/<urlencoded 文件名>` |
| `action=caps` | 返回 JSON，用于连通性测试 |
| `action=delete_project` | 删除 `temp_build/<project_name>`，用于上传后清理 |
| 产物目录 | 服务器站点根下的 `deb_files/` 目录，产物已重命名为 `<tweak>_<project>_<YmdHis>_<rand>.deb/.dylib` |

`mode=select` 不会在编译后删除工程目录，所以客户端在构建结束（无论成败）后 best-effort 调用 `delete_project`，避免上传的临时工程堆积。

服务端固定：`theos_path=/opt/theos`、`build_script=/opt/theos/theos_build.sh`、SDK 17.0、部署目标 12.0。

## 3. 方案与取舍

- **新建工程没有 Makefile/control**：`TMCStudioCreateController` 只生成源码 + `MobileCompiler.json` + `<name>.plist`（ObjC 模板）或不生成 control（纯 dylib）。远程构建必须上传 Makefile/control，所以客户端在缺少这些文件时按 `MobileCompiler.json` 现生成。
- **有 Makefile 的导入工程**：原样上传（服务端会把 `$(THEOS)` 替换为 `/opt/theos` 并做 `make -n` 预检），失败日志直接回显，不隐藏。
- **ZIP 打包复用 libarchive**：与 `ShareExtension/TFShareFolderArchive.m` 同一套 `archive_write_*` API，避免新增依赖；排除 `.git/build/dist/.theos/packages/.StudioTrash` 与二进制产物。
- **产物落盘位置**：`Documents/RemoteBuilds/<工程名>-<Ymd-Hms>/`。现有「产物」页是递归扫描 `Documents` 下的 `.deb/.dylib`，因此无需改动产物页即可显示、左滑重命名/删除。
- **配置存 NSUserDefaults**：`DXRemoteBuildServer`（**默认留空，首次使用必须填写**）、`DXRemoteBuildScheme`（默认 `rootless`）、`DXRemoteBuildArch`（默认 `fat`）、`DXRemoteBuildInject`（默认 `ipa_standalone`）。
- **地址未配置时**：设置页「远程构建」入口正常可进（用于填写地址）；工程菜单点击「远程构建」先弹提示「请先配置远程打包服务器」，并给出「去设置」按钮，不发起任何网络请求。
- **不自动切换**：工程卡片「编译」始终只走本机编译；远程构建只能从「⋯ → 远程构建」手动触发，本机编译失败也不会自动改走远程。
- **ATS**：`scripts/build.py` 已写入 `NSAppTransportSecurity.NSAllowsArbitraryLoads = True`，http 站点可用。
- **超时**：服务端 `set_time_limit(300)`，客户端请求超时 600s / 资源 900s。

## 4. 新增与修改文件

### 4.1 新增 `App/Remote/DXRemoteBuild.h`

公开接口（`NS_ASSUME_NONNULL_BEGIN`）：

```objc
NSString *DXRemoteBuildServer(void);
void DXRemoteBuildSetServer(NSString *server);
NSString *DXRemoteBuildScheme(void);
void DXRemoteBuildSetScheme(NSString *scheme);   // rootful | rootless | roothide
NSString *DXRemoteBuildArch(void);
void DXRemoteBuildSetArch(NSString *arch);       // fat | arm64 | arm64e
NSString *DXRemoteBuildInject(void);
void DXRemoteBuildSetInject(NSString *inject);   // jailbreak | ipa_substrate | ipa_standalone
BOOL DXRemoteBuildConfigured(void);              // Server 非空且可解析为 http/https URL

void DXRemoteBuildProbe(void (^completion)(BOOL ok, NSString *message));

@interface DXRemoteBuildJob : NSObject
+ (instancetype)runProject:(NSString *)root
                  progress:(void (^)(NSString *line))progress
                completion:(void (^)(BOOL success,
                                     NSArray<NSString *> *localArtifacts,
                                     NSString *summary))completion;
- (void)cancel;
@end
```

`progress` 与 `completion` 一律回主队列。

### 4.2 新增 `App/Remote/DXRemoteBuild.m`

内部实现要点：

1. **URL 规范化** `DXBaseURL(void)`
   - 去首尾空白；无 `://` 前缀时补 `https://`；去掉末尾 `/`；`NSURLComponents` 校验 scheme=http/https 且 host 非空。
2. **POST 封装** `DXPost(NSString *base, NSDictionary<NSString*,NSString*> *fields, NSDictionary<NSString*,NSData*> *files, void (^done)(NSData *body, NSURLResponse *response, NSError *error))`
   - URL = `<base>/api.php`；
   - `Referer: <base>/`、`User-Agent: AiFlex2/<CFBundleShortVersionString>`；
   - 无文件时 `application/x-www-form-urlencoded`；有文件时 multipart（boundary `AiFlex2-<UUID>`，字段名 `project_zip`、filename `<工程名>.zip`、`Content-Type: application/zip`）；
   - `NSURLSessionConfiguration.ephemeral`，`timeoutIntervalForRequest=600`、`timeoutIntervalForResource=900`；
   - 返回前把非 2xx 转成 `NSError`（附响应前 200 字，便于识别 403「禁止直接访问」）。
3. **连通性** `DXRemoteBuildProbe`：`action=caps` → 2xx 且 JSON `success==true` 视为可用；403 时提示「服务器拒绝直接请求（Referer 校验），请确认地址是该打包站首页」。
4. **读取工程配置** `DXProjectConfig(root)`：解析 `MobileCompiler.json`（不存在则空字典）。
5. **Makefile** `DXRemoteMakefile(root, config)`：
   - `root/Makefile` 存在且非空 → 原样返回；
   - 否则：`product = config[@"productName"] ?: 工程目录名`，清洗为 `[A-Za-z0-9_]`，首字符非字母则前缀 `T`；
   - `sources = config[@"sources"]`，否则扫描根目录与一层子目录的 `.xm/.x/.m/.mm/.c/.cpp`（≤200）；
   - `frameworks = config[@"frameworks"] ?: @[@"Foundation",@"UIKit"]`；
   - 判定：任一源码扩展名 `xm`/`x` → tweak；否则 `config[@"package"] == @NO` → library；其余 → tweak；
   - tweak 模板：
     ```
     TWEAK_NAME = <product>
     <product>_FILES = <sources...>
     <product>_FRAMEWORKS = <frameworks...>
     include $(THEOS)/makefiles/common.mk
     include $(THEOS_MAKE_PATH)/tweak.mk
     ```
     library 模板把 `TWEAK_NAME` 换成 `LIBRARY_NAME`、末行换成 `library.mk`；
   - **不写 TARGET / ARCHS**：SDK 与架构由服务端脚本的 `ARCHS` 环境变量与本机设置决定，避免硬编码 SDK 版本导致换服务器即失败。
6. **control** `DXRemoteControl(root, config)`：有 `root/control` 用它；否则生成 `Package: com.aiflex2.<product>`、`Name`、`Version: 1.0.0`、`Architecture: iphoneos-arm64`、`Description`、`Maintainer/Author: AiFlex2`、`Section: Tweaks`（服务端会按 scheme 重写 Architecture）。
7. **Filter.plist** `DXRemoteFilter(root, config)`：优先取根目录 `<工程名>.plist` 或任一含 `Filter` 键的 `.plist`（排除 `MobileCompiler.json`、`Info.plist`）；否则生成 `{Filter:{Bundles:[config[@"bundleID"] ?: @"com.apple.springboard"]}}`。
8. **Tweak.xm**：存在则读取文本，否则传空（`mode=select` 允许空）。
9. **ZIP** `DXRemoteZip(root, error)`：`archive_write_new/set_format_zip/open_filename`，相对路径入包；跳过目录 `.git build dist .theos packages .StudioTrash node_modules`；跳过文件后缀 `.deb .dylib .o .a` 与 `.DS_Store`；上限 3000 项 / 50MB / 120s；写入 `NSTemporaryDirectory()/DXRemoteBuild-<UUID>/<工程名>.zip`，调用方清理父目录。
10. **构建流程**（`DXRemoteBuildJob runProject:progress:completion:`，串行后台队列）：
    1. `progress(@"检查远程构建配置…")` → 未配置则失败并提示去「设置 → 远程构建」；
    2. 打包 ZIP → `progress(@"工程已打包（x.x MB），正在上传…")`；
    3. `upload_project` → JSON `project_name`，失败读 `message`；
    4. `progress(@"已上传，服务器开始编译…")` → `action=build`（`mode=select` + 第 5–8 步内容 + 三项构建选项）；
    5. 解析响应：在首个 `|<div` 处切分（退化时用最后一个 `|`）；日志追加到 progress（按 8KB 分段）；
    6. 正则 `deb_files/([A-Za-z0-9%._~-]+)` 收集链接并 `stringByRemovingPercentEncoding`；无链接 → 失败，summary 取日志末 40 行；
    7. 逐个 GET 下载到 `Documents/RemoteBuilds/<工程名>-<yyyyMMdd-HHmmss>/`，文件名保持服务器产物名；
    8. best-effort `delete_project`；
    9. `completion(YES, 本地路径数组, @"成功，已下载 N 个产物")`；任一步失败 → `completion(NO, @[], 原因)`，同时把服务器日志带出。
    - `cancel` 取消当前 NSURLSessionTask 并停止后续步骤。
11. 所有 `progress/completion` 通过 `dispatch_async(dispatch_get_main_queue(), …)` 回调。

### 4.3 新增 `App/Shell/DXRemoteBuildUI.h`

```objc
UIViewController *DXRemoteBuildSettingsController(void);
UIViewController *DXRemoteBuildLogController(NSString *projectRoot);
```

### 4.4 新增 `App/Shell/DXRemoteBuildUI.m`

- **`DXRemoteBuildSettingsController`**（`UITableViewController` insetGrouped，`DXCanvas` 背景）：
  - 第 0 组「服务器」：一行 `UITextField` 输入地址（`keyboardType=URL`、`autocorrectionType=No`、`autocapitalizationType=None`，placeholder `https://your-domain.com`），`textFieldDidEndEditing` 立即保存；footer「填写你的 Theos 打包站地址（api.php 所在站点根地址）。构建时会上传工程 zip，编译完成后自动下载 deb/dylib。首次使用必须填写。」
  - 第 1 组「构建选项」：三行 ActionSheet 选择——越狱类型（有根 Rootful / 无根 Rootless / 隐根 RootHide）、目标架构（arm64 + arm64e / arm64 / arm64e）、注入环境（越狱注入 / IPA 注入·自带 Substrate / IPA 注入·免依赖）；detail 显示当前值，选中即保存并刷新。
  - 第 2 组「连接」：「测试服务器」行，点击后禁用并显示 `UIActivityIndicatorView`，`DXRemoteBuildProbe` 回调用 alert 显示「连接正常」或具体错误。
  - footer 说明产物保存位置。
- **`DXRemoteBuildLogController`**：
  - 大标题为工程名，`viewDidLoad` 立即启动 `DXRemoteBuildJob`；
  - 顶部状态卡（`DXSurface`）：spinner + 阶段文案；结束后换成 ✅/❌ 图标与 summary；
  - 中部日志 `UITextView`（`monospacedSystemFontOfSize:11`，只读，`DXCard` 背景，圆角 16，最多保留 60000 字符）；
  - 底部按钮「复制日志」（`UIPasteboard`）；
  - 成功时把产物以 `UIStackView` 行展示（图标 + 文件名 + 大小），点击 `UIActivityViewController` 分享；
  - 未配置服务器时先弹 alert「请先在设置 → 远程构建填写服务器地址」，并提供「去设置」跳转 `DXRemoteBuildSettingsController`；
  - `viewWillDisappear` 且任务未完成时调用 `cancel`。
  - 视觉沿用 `DXAccent/DXSurface/DXText` 等外壳函数（把这些静态函数声明在 `DXShell.h` 不现实，UI 文件内按相同色值自建同名局部函数，保持一致）。

### 4.5 修改 `App/Shell/DXShell.m`

1. 顶部 `#import "../Remote/DXRemoteBuild.h"`、`#import "DXRemoteBuildUI.h"`。
2. 工程卡片菜单（当前 [DXShell.m:476](App/Shell/DXShell.m#L476)）：
   ```objc
   more.menu = [UIMenu menuWithTitle:@"" children:@[
       [UIAction actionWithTitle:@"远程构建" image:[UIImage systemImageNamed:@"icloud.and.arrow.up"] identifier:nil
                         handler:^(UIAction *action){ [weakSelf remoteBuildProject:root]; }],
       [UIAction actionWithTitle:@"删除工程" image:[UIImage systemImageNamed:@"trash"] identifier:nil
                         handler:^(UIAction *action){ [weakSelf confirmTrashProject:root name:name]; }],
   ]];
   ```
3. 新增 `- (void)remoteBuildProject:(NSString *)root`：`pushViewController:DXRemoteBuildLogController(root)`。
4. 设置页「构建」分组（[DXShell.m:823-825](App/Shell/DXShell.m#L823-L825) 与 [850-852](App/Shell/DXShell.m#L850-L852)）：
   - `numberOfRowsInSection:1` 由 1 改为 2；
   - 行 0「远程构建」detail 显示 `DXRemoteBuildServer()` 的 host；行 1「构建默认设置」；
   - `didSelect`：行 0 push `DXRemoteBuildSettingsController()`，行 1 保持 push `TMCStudioBuildPreferencesController()`。

### 4.6 修改 `scripts/build.py`

主 App 编译源文件列表（[build.py:221](scripts/build.py#L221)）在 `App/Shell/DXShell.m` 之后加入：

```python
str(ROOT / 'App/Shell/DXRemoteBuildUI.m')
```

`App/Remote/*.m` 已是 glob，`DXRemoteBuild.m` 自动参与编译，无需改动。

## 5. 不做的事

- 不修改 `api.php` 或任何服务端文件。
- 不新建 Python/Node 服务端。
- 不改产物页、构建队列、本机编译链路。
- 不引入第三方网络库（只用 NSURLSession + libarchive）。

## 6. 验证

1. 静态检查：`grep` 确认新文件的 4 个入口符号（`DXRemoteBuildServer`、`DXRemoteBuildProbe`、`DXRemoteBuildJob`、`DXRemoteBuildLogController`）均被引用；`python -m py_compile scripts/build.py`。
2. 提交并触发 CI（`.github/workflows/build-ipa.yml`），等 workflow 成功，下载 artifact 校验 IPA 内 `AiFlex2IPA` 存在且 Mach-O arm64。
3. 真机自测清单：
   - 设置 → 构建 → 远程构建：地址初始为空；未填时点工程菜单「远程构建」应弹出「去设置」引导且不发请求；填入你的站点地址后「测试服务器」返回「连接正常」；
   - 新建 Logos 工程 → 工程卡片 ⋯ → 远程构建：日志依次出现「打包/上传/编译/下载」，结束显示成功与产物；
   - 「产物」页出现服务器命名的 `.deb`/`.dylib`，可左滑重命名/删除；
   - 断网或错误地址：状态卡显示失败原因与服务器日志尾部，不崩溃、不卡死；
   - 纯 dylib 工程（target=dylib）同样能下载到 `.dylib`。

## 7. 风险

- 服务器 `api.php` 的 `Referer` 校验：客户端已显式携带；若站点启用 Basic Auth，需要后续在设置页加账号密码（本版不做）。
- 生成式 Makefile 只覆盖常见单目标工程；聚合 Makefile（多子项目）原样上传，失败原因由服务器日志回显。
- 服务器 SDK/部署目标固定为 17.0/12.0，生成的 Makefile 不写 `TARGET`，避免硬编码。
