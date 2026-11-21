#import <Foundation/Foundation.h>
void TFAILiveUpdate(NSString *stage,NSUInteger count,NSUInteger steps);
void TFAILiveEnd(BOOL success);

BOOL TFAILiveEnabled(void);
void TFAISetLiveActivityEnabled(BOOL enabled);

NSString *TFAILiveStatus(void);
