#import "TFAILiveActivity.h"
#import <objc/message.h>
#import <dlfcn.h>
static NSString *bridgeError;
static NSString * const TFAILiveEnabledKey = @"TFAI.Background.LiveActivityEnabled";
// 记录「可能还有实时活动挂在系统里」。进程被杀时静态变量丢失，只能靠这个标志
// 在下次启动/关开关时把残留清掉，否则灵动岛会一直挂着。
static NSString * const TFAILiveDirtyKey = @"TFAI.Background.LiveActivityDirty";
static Class ActivityBridge(void){if(@available(iOS 16.2,*)){static Class cls;static dispatch_once_t once;dispatch_once(&once,^{NSString *path=[NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"TFTaskActivity.framework/TFTaskActivity"];if(dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL)){cls=NSClassFromString(@"TFTaskLiveActivity");if(!cls)bridgeError=@"实时活动类未加载";}else{const char *error=dlerror();bridgeError=error?@(error):@"实时活动框架未加载";NSLog(@"[AI Live Activity] %@",bridgeError);}});return cls;}return Nil;}
static void AXFinishLive(BOOL success){Class cls=ActivityBridge();if(cls)((void(*)(id,SEL,BOOL))objc_msgSend)(cls,NSSelectorFromString(@"finish:"),success);}
// 只清理系统里的实例，不依赖内存中的 current，用于收拾上次进程的残留。
static void AXEndAllLive(void){Class cls=ActivityBridge();if(cls)((void(*)(id,SEL))objc_msgSend)(cls,NSSelectorFromString(@"endAll"));}
static BOOL AXLiveDirty(void){return [NSUserDefaults.standardUserDefaults boolForKey:TFAILiveDirtyKey];}
static void AXSetLiveDirty(BOOL dirty){[NSUserDefaults.standardUserDefaults setBool:dirty forKey:TFAILiveDirtyKey];}
BOOL TFAILiveEnabled(void){return [NSUserDefaults.standardUserDefaults boolForKey:TFAILiveEnabledKey];}
void TFAISetLiveActivityEnabled(BOOL enabled){BOOL wasEnabled=TFAILiveEnabled();[NSUserDefaults.standardUserDefaults setBool:enabled forKey:TFAILiveEnabledKey];if(enabled)return;
 // 关闭时必须按「结束 + 清残留」两步走：finish 只结束内存里的实例，
 // 而重启后内存里没有实例，残留的实时活动就会一直显示。
 if(wasEnabled||AXLiveDirty()){AXFinishLive(YES);AXEndAllLive();}
 AXSetLiveDirty(NO);
}
// 启动自检：开关处于关闭状态却还留着上次的实时活动时清一次。
// 从未开启过的用户不会走到这里，也就不会多加载框架。
void TFAILiveCleanupIfDisabled(void){if(TFAILiveEnabled())return;if(!AXLiveDirty())return;AXEndAllLive();AXSetLiveDirty(NO);}
// Gate before touching the bridge: when disabled we never even dlopen the framework.
void TFAILiveUpdate(NSString *stage,NSUInteger count,NSUInteger steps){if(!TFAILiveEnabled())return;Class cls=ActivityBridge();if(cls){((void(*)(id,SEL,id,NSInteger,NSInteger))objc_msgSend)(cls,NSSelectorFromString(@"update:count:steps:"),stage,count,steps);if(!AXLiveDirty())AXSetLiveDirty(YES);}}
void TFAILiveEnd(BOOL success){if(!TFAILiveEnabled()){ // 关闭状态下也要收尾，避免刚关掉开关时留着半截活动
  if(AXLiveDirty()){AXEndAllLive();AXSetLiveDirty(NO);}
  return;}
 AXFinishLive(success);AXSetLiveDirty(NO);}

NSString *TFAILiveStatus(void){if(!TFAILiveEnabled())return @"已关闭（省电）";Class cls=ActivityBridge();if(cls)return ((id(*)(id,SEL))objc_msgSend)(cls,NSSelectorFromString(@"status"));return bridgeError?:@"当前系统未启用实时活动";}
