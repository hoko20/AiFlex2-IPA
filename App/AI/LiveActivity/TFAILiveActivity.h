#import <Foundation/Foundation.h>
void TFAILiveUpdate(NSString *stage,NSUInteger count,NSUInteger steps);
void TFAILiveEnd(BOOL success);

BOOL TFAILiveEnabled(void);
void TFAISetLiveActivityEnabled(BOOL enabled);
// 开关关闭时清掉上次进程遗留的实时活动，启动时调用一次。
void TFAILiveCleanupIfDisabled(void);

NSString *TFAILiveStatus(void);
