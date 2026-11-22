#import "../AIContracts.h"
@interface TFAIMCP : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)servers;
- (BOOL)importJSON:(NSString *)text error:(NSError **)error;
- (BOOL)setEnvironment:(NSDictionary *)environment server:(NSString *)identifier error:(NSError **)error;
- (void)cancelSession:(NSString *)session;
- (NSArray<NSDictionary *> *)auditForSession:(NSString *)session;
- (NSDictionary *)diagnostics:(NSString *)identifier session:(NSString *)session;
- (void)remove:(NSString *)identifier;
- (void)setEnabled:(BOOL)enabled server:(NSString *)identifier session:(NSString *)session;
- (BOOL)enabled:(NSString *)identifier session:(NSString *)session;
- (BOOL)setAllowed:(BOOL)allowed tool:(NSString *)name server:(NSString *)identifier error:(NSError **)error;
- (void)discover:(NSString *)identifier completion:(TFAIResult)completion;
- (void)discover:(NSString *)identifier session:(NSString *)session launchApproved:(BOOL)approved completion:(TFAIResult)completion;
// 轻量存活探测：只发一次 tools/list，不改变工具清单，用来发现"显示已连接但链路已断"。
- (void)probe:(NSString *)identifier session:(NSString *)session completion:(void (^)(BOOL ok, NSError *error))completion;
- (NSArray *)schemas:(NSString *)session;
// 已发现但尚未授权过滤的工具清单，供服务页展示与刷新（发现可能由开关自动触发）。
- (NSArray<NSDictionary *> *)discoveredTools:(NSString *)identifier;
- (void)call:(NSString *)name arguments:(NSDictionary *)arguments session:(NSString *)session completion:(TFAIResult)completion;
+ (BOOL)availableTool:(NSDictionary *)tool;
- (NSDictionary *)approvalInfo:(NSString *)name session:(NSString *)session;
- (void)call:(NSString *)name arguments:(NSDictionary *)arguments session:(NSString *)session approved:(BOOL)approved completion:(TFAIResult)completion;
+ (BOOL)readOnlyTool:(NSDictionary *)tool;
@end
