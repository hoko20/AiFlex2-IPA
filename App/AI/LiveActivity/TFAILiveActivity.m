#import "TFAILiveActivity.h"
#import <objc/message.h>
#import <dlfcn.h>
static NSString *bridgeError;
static NSString * const TFAILiveEnabledKey = @"TFAI.Background.LiveActivityEnabled";
static Class ActivityBridge(void){if(@available(iOS 16.2,*)){static Class cls;static dispatch_once_t once;dispatch_once(&once,^{NSString *path=[NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"TFTaskActivity.framework/TFTaskActivity"];if(dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL)){cls=NSClassFromString(@"TFTaskLiveActivity");if(!cls)bridgeError=@"实时活动类未加载";}else{const char *error=dlerror();bridgeError=error?@(error):@"实时活动框架未加载";NSLog(@"[AI Live Activity] %@",bridgeError);}});return cls;}return Nil;}
static void AXFinishLive(BOOL success){Class cls=ActivityBridge();if(cls)((void(*)(id,SEL,BOOL))objc_msgSend)(cls,NSSelectorFromString(@"finish:"),success);}
BOOL TFAILiveEnabled(void){return [NSUserDefaults.standardUserDefaults boolForKey:TFAILiveEnabledKey];}
void TFAISetLiveActivityEnabled(BOOL enabled){BOOL wasEnabled=TFAILiveEnabled();[NSUserDefaults.standardUserDefaults setBool:enabled forKey:TFAILiveEnabledKey];if(!enabled&&wasEnabled)AXFinishLive(YES);}
// Gate before touching the bridge: when disabled we never even dlopen the framework.
void TFAILiveUpdate(NSString *stage,NSUInteger count,NSUInteger steps){if(!TFAILiveEnabled())return;Class cls=ActivityBridge();if(cls)((void(*)(id,SEL,id,NSInteger,NSInteger))objc_msgSend)(cls,NSSelectorFromString(@"update:count:steps:"),stage,count,steps);}
void TFAILiveEnd(BOOL success){if(!TFAILiveEnabled())return;AXFinishLive(success);}

NSString *TFAILiveStatus(void){if(!TFAILiveEnabled())return @"已关闭（省电）";Class cls=ActivityBridge();if(cls)return ((id(*)(id,SEL))objc_msgSend)(cls,NSSelectorFromString(@"status"));return bridgeError?:@"当前系统未启用实时活动";}
