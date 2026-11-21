#import "DXFlexPluginInfo.h"
#import "../AI/Agent/TFAIMCP.h"

@interface DXFlexPluginInfo : UITableViewController
@property NSDictionary *manifest;
@end

static UIColor *PluginAccent(void) {
 return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t){
  return t.userInterfaceStyle==UIUserInterfaceStyleDark?[UIColor colorWithRed:.62 green:.68 blue:1 alpha:1]:[UIColor colorWithRed:.27 green:.35 blue:.82 alpha:1];
 }];
}

@implementation DXFlexPluginInfo
- (void)viewDidLoad {
 [super viewDidLoad];self.title=@"AiFlex2 插件";self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=72;
 NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"FLEXPlugin/manifest.json"];
 id value=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]?:NSData.data options:0 error:nil];
 self.manifest=[value isKindOfClass:NSDictionary.class]?value:@{};
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section==0?1:section==1?4:section==2?2:1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @[@"插件简介",@"可用能力",@"分享安装包",@"MCP 联调"][section]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
 if(section==0)return @"AiFlex2 运行在你选择注入的目标 App 内；AiFlex2 IPA 通过已配对的局域网或本机连接接收现场数据和工具结果。同一设备可使用仅本机模式，无需 Wi-Fi。";
 if(section==1)return @"敏感读取与视图控制受 AiFlex2 工具权限约束。AiFlex2 IPA 不会因分享安装包而自动注入目标 App。";
 if(section==2)return @"在目标设备上使用适合其环境的安装方式。deb 面向 rootless 环境；dylib 供需要独立插件文件的工作流使用。";
 if(section==3)return @"在 AiFlex2 面板复制服务地址与令牌后导入。同一设备可用 127.0.0.1，跨设备请填局域网 IP；导入后到 AI 会话的 MCP 设置中启用并逐项授权工具。";
 return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
 UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];cell.detailTextLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;cell.detailTextLabel.numberOfLines=0;
 if(indexPath.section==0){cell.textLabel.text=[NSString stringWithFormat:@"AiFlex2 %@",self.manifest[@"version"]?:@""];cell.detailTextLabel.text=@"三指或四指长按 0.5 秒唤出 FLEX。在目标 App 内查看视图、类、网络与沙盒现场，并通过 AiFlex2 AI 会话调用受控实时工具。";cell.imageView.image=[UIImage systemImageNamed:@"puzzlepiece.extension"];cell.selectionStyle=UITableViewCellSelectionStyleNone;}
 if(indexPath.section==1){cell.textLabel.text=@[@"现场与对象",@"AI 会话",@"工具权限",@"自主交互与扩展页面"][indexPath.row];cell.detailTextLabel.text=@[@"选中对象、视图树、类信息及运行时镜像",@"收起后会话继续运行，从 FLEX 菜单的 AiFlex2 AI 返回同一会话",@"本会话一次总授权，敏感读取与控制共用，无时间限制；可随时撤销",@"按系统能力开放点击、双击、长按、拖动、缩放、旋转；支持文本输入、原生控件、xx.h 与反汇编导航。触摸实现参考 KIF / EarlGrey（Apache-2.0），许可随包附带。"][indexPath.row];cell.imageView.image=[UIImage systemImageNamed:@[@"viewfinder",@"bubble.left.and.text.bubble.right",@"lock.shield",@"hand.tap"][indexPath.row]];cell.selectionStyle=UITableViewCellSelectionStyleNone;}
 if(indexPath.section==2){NSString *kind=indexPath.row==0?@"deb":@"dylib";NSDictionary *file=self.manifest[@"files"][kind];NSString *name=file[@"name"];NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[@"FLEXPlugin" stringByAppendingPathComponent:name?:@""]];NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];BOOL available=[attrs[NSFileType] isEqual:NSFileTypeRegular];cell.textLabel.text=indexPath.row==0?@"分享 rootless deb":@"分享独立 dylib";cell.detailTextLabel.text=available?[NSString stringWithFormat:@"%@ · %@",name,[NSByteCountFormatter stringFromByteCount:[attrs[NSFileSize] longLongValue] countStyle:NSByteCountFormatterCountStyleFile]]:@"安装包缺失";cell.imageView.image=[UIImage systemImageNamed:@"square.and.arrow.up"];cell.accessoryType=available?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;cell.userInteractionEnabled=available;cell.textLabel.enabled=available;}
 if(indexPath.section==3){cell.textLabel.text=@"连接 AiFlex2 MCP";cell.detailTextLabel.text=@"导入服务地址与 Bearer 令牌，让 AI 读取目标 App 的运行时信息";cell.imageView.image=[UIImage systemImageNamed:@"network"];}
 cell.imageView.tintColor=PluginAccent();
 return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 [tableView deselectRowAtIndexPath:indexPath animated:YES];
 if(indexPath.section==3){[self connectMCP];return;}
 if(indexPath.section!=2)return;
 NSString *kind=indexPath.row==0?@"deb":@"dylib";NSString *name=self.manifest[@"files"][kind][@"name"];
 if(![name isKindOfClass:NSString.class]||![name isEqual:name.lastPathComponent])return;
 NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[@"FLEXPlugin" stringByAppendingPathComponent:name]];
 NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];if(![attrs[NSFileType] isEqual:NSFileTypeRegular])return;
 UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
 UITableViewCell *cell=[tableView cellForRowAtIndexPath:indexPath];share.popoverPresentationController.sourceView=cell;share.popoverPresentationController.sourceRect=cell.bounds;[self presentViewController:share animated:YES completion:nil];
}
- (void)connectMCP {
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"连接 AiFlex2 MCP" message:@"填写 AiFlex2 面板显示的地址与令牌。同一设备可用 127.0.0.1，跨设备请填局域网 IP。" preferredStyle:UIAlertControllerStyleAlert];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.text=@"http://127.0.0.1:8790/mcp";f.placeholder=@"服务地址";f.keyboardType=UIKeyboardTypeURL;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.autocorrectionType=UITextAutocorrectionTypeNo;}];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"Bearer 令牌（无鉴权可留空）";f.secureTextEntry=YES;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.autocorrectionType=UITextAutocorrectionTypeNo;}];
 [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
 __weak typeof(self) weak=self;
 [a addAction:[UIAlertAction actionWithTitle:@"导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
  NSString *url=[a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSString *token=[a.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSMutableDictionary *server=[NSMutableDictionary dictionaryWithDictionary:@{@"type":@"http",@"url":url?:@""}];
  if(token.length)server[@"headers"]=@{@"Authorization":[@"Bearer " stringByAppendingString:token]};
  NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"mcpServers":@{@"aiflex2":server}} options:0 error:nil];
  NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
  NSError *error=nil;
  BOOL ok=[[TFAIMCP shared] importJSON:json error:&error];
  UIAlertController *result=[UIAlertController alertControllerWithTitle:ok?@"已导入":@"导入失败" message:ok?@"导入不等于 AI 可用：请到「当前 AI 会话 → Agent 能力 → MCP 服务 → aiflex2」，先在顶部选择本会话并打开“用于当前会话”，再点“发现工具”，最后逐项打开下方工具开关。三步完成后 AI 才会看到这些工具；只导入或只发现都不够。":error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
  [result addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
  [weak presentViewController:result animated:YES completion:nil];
 }]];
 [self presentViewController:a animated:YES completion:nil];
}
@end

UIViewController *DXFlexPluginInfoController(void) { return [[DXFlexPluginInfo alloc]initWithStyle:UITableViewStyleInsetGrouped]; }
