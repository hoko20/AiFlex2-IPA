# 任务清单：远程 Theos 打包接入

> 状态更新 2026-11-21：核对源码后确认 T1–T4 已全部实现并接入编译；
> T5 的静态检查可在本机完成，CI 与真机验证需在 macOS + 设备环境执行。
> 服务端地址/域名相关示例已从本规格中脱敏，实际地址在 App 设置页填写。
>
> 关于全局品牌清理：源码中绝大多数 `Dylix` / `TweakForge` 是技术标识符（钥匙串
> service、NSUserDefaults key、文件路径、URL scheme、bundle id、类名、通知名、
> 证书 CN），改动会破坏用户数据与签名兼容性，故保留。仅修正了确属功能性问题的
> 部分：应用显示名统一为 AiFlex2、版本号对齐 1.1.3(272)、更新检查的 IPA 文件名
> 正则兼容新命名。

## T1 远程构建内核
- [x] 新建 `App/Remote/DXRemoteBuild.h`：配置读写、`DXRemoteBuildProbe`、`DXRemoteBuildJob` 声明。
- [x] 新建 `App/Remote/DXRemoteBuild.m`：
  - [x] URL 规范化与 `DXPost`（含 `Referer`、multipart、600s 超时、非 2xx 错误）。
  - [x] `DXRemoteMakefile` / `DXRemoteControl` / `DXRemoteFilter`（缺文件时按 `MobileCompiler.json` 生成）。
  - [x] `DXRemoteZip`（libarchive，排除构建产物与大目录，50MB/3000 项/120s 上限）。
  - [x] 构建流程：upload_project → build(mode=select) → 解析 `日志|HTML` → 提取 `/deb_files/` → 下载到 `Documents/RemoteBuilds/…` → best-effort delete_project。
  - [x] `cancel` 与主队列回调。

## T2 远程构建界面
- [x] 新建 `App/Shell/DXRemoteBuildUI.h`，导出两个入口。
- [x] 新建 `App/Shell/DXRemoteBuildUI.m`：
  - [x] 设置页：服务器地址（默认空，placeholder 提示）、越狱类型、目标架构、注入环境、测试服务器。
  - [x] 日志页：状态卡 + 日志 TextView + 复制 + 产物分享；未配置时提示并跳设置；退出时取消任务。

## T3 外壳接入
- [x] `App/Shell/DXShell.m`：import 两个头文件；工程卡菜单加「远程构建」；新增 `remoteBuildProject:`（未配置地址时弹「去设置」引导，不发请求）。
- [x] `App/Shell/DXShell.m`：设置「构建」组改为 2 行（远程构建 / 构建默认设置），接好 push 与 detail。

## T4 构建脚本
- [x] `scripts/build.py` 主 App 源列表加入 `App/Shell/DXRemoteBuildUI.m`。

## T5 验证与交付
- [x] `python -m py_compile scripts/build.py`；grep 校验关键符号引用（本机静态检查通过）。
- [ ] 提交并等待 CI 构建成功（需 macOS + gh CLI）。
- [ ] `gh api` 取回 artifact，校验包内 `AiFlex2IPA` 为 arm64 Mach-O。
- [ ] 输出 IPA 下载链接与真机自测步骤。
