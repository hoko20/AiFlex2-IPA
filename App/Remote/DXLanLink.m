#import "DXLanLink.h"
#import <Security/Security.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>

static NSString *const DXLanAddressKey=@"Dylix.LanLink.v1.address";
static NSString *const DXLanAutoKey=@"Dylix.LanLink.v1.auto";
static NSString *const DXLanTokenService=@"com.xuegao.dylix.lanlink.v1";
static NSString *const DXLanDefaultAddress=@"http://127.0.0.1:8790/mcp";

static NSError *LanError(NSString *message){return [NSError errorWithDomain:@"Dylix.LanLink" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}

static NSMutableDictionary *LanTokenQuery(void){
    return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService:DXLanTokenService,
              (__bridge id)kSecAttrAccount:@"plugin"} mutableCopy];
}
static NSString *LanStoredToken(void){
    NSMutableDictionary *q=LanTokenQuery();
    q[(__bridge id)kSecReturnData]=@YES;
    CFTypeRef result=NULL;
    if(SecItemCopyMatching((__bridge CFDictionaryRef)q,&result)!=errSecSuccess)return @"";
    NSData *data=CFBridgingRelease(result);
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]?:@"";
}
static BOOL LanStoreToken(NSString *token){
    NSMutableDictionary *q=LanTokenQuery();
    if(!token.length){SecItemDelete((__bridge CFDictionaryRef)q);return YES;}
    NSData *data=[token dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus status=SecItemUpdate((__bridge CFDictionaryRef)q,(__bridge CFDictionaryRef)@{(__bridge id)kSecValueData:data});
    if(status==errSecItemNotFound){
        q[(__bridge id)kSecValueData]=data;
        q[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
        status=SecItemAdd((__bridge CFDictionaryRef)q,NULL);
    }
    return status==errSecSuccess;
}

// 把 NSURLError 翻成能照着做的原因：端口没监听、令牌不对、明文被拦，处置完全不同。
static NSError *LanTransportError(NSURL *url,NSError *error){
    NSString *target=url.port?[NSString stringWithFormat:@"%@:%@",url.host?:@"?",url.port]:url.host?:@"地址";
    NSString *message=nil;
    switch(error.code){
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorCannotFindHost:
            message=[NSString stringWithFormat:@"连不上 %@：端口没有监听，或地址已经变了。请回到 AiFlex2 面板确认「MCP 服务」仍运行、端口与令牌一致。",target];break;
        case NSURLErrorNotConnectedToInternet:
            message=[NSString stringWithFormat:@"%@ 不可达：当前没有网络。跨设备连接需要两台设备在同一 Wi-Fi。",target];break;
        case NSURLErrorNetworkConnectionLost:
            message=[NSString stringWithFormat:@"连接 %@ 被中断：插件可能刚重启，或宿主退到后台被系统回收。",target];break;
        case NSURLErrorTimedOut:
            message=[NSString stringWithFormat:@"连接 %@ 超时：插件已挂起，或端口被别的程序占着不回包。",target];break;
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            message=[NSString stringWithFormat:@"系统拦截了明文 HTTP（%@）。",target];break;
        case NSURLErrorSecureConnectionFailed:
            message=[NSString stringWithFormat:@"%@ 的 TLS 握手失败：地址与证书不匹配。",target];break;
        default:
            message=[NSString stringWithFormat:@"连接 %@ 失败（%ld）%@",target,(long)error.code,error.localizedDescription.length?[@"：" stringByAppendingString:error.localizedDescription]:@""];break;
    }
    return [NSError errorWithDomain:@"Dylix.LanLink" code:error.code userInfo:@{NSLocalizedDescriptionKey:message}];
}

static NSArray *LanToolsFromBody(NSData *data,NSString *mime){
    if(!data.length)return nil;
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if(!text.length)return nil;
    id object=nil;
    if([mime.lowercaseString containsString:@"event-stream"]){
        // Streamable HTTP 允许用 SSE 回一帧；只取第一条带 result 的 data。
        for(NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]){
            if(![line hasPrefix:@"data:"])continue;
            NSString *payload=[[line substringFromIndex:5] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            id parsed=[NSJSONSerialization JSONObjectWithData:[payload dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if([parsed isKindOfClass:NSDictionary.class]&&parsed[@"result"]){object=parsed;break;}
        }
    }else{
        object=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }
    if(![object isKindOfClass:NSDictionary.class])return nil;
    if(object[@"error"])return nil;
    id result=object[@"result"];
    if(![result isKindOfClass:NSDictionary.class])return nil;
    return [result[@"tools"] isKindOfClass:NSArray.class]?result[@"tools"]:@[];
}

@interface DXLanLink ()
@property(nonatomic,copy) NSDictionary *status;
@property(nonatomic) NSUInteger generation;
@property(nonatomic,strong) NSURLSession *session;
@end

@implementation DXLanLink
+ (instancetype)shared{
    static DXLanLink *link;static dispatch_once_t once;
    dispatch_once(&once,^{link=[self new];});
    return link;
}
- (instancetype)init{
    if((self=[super init])){
        NSString *saved=[NSUserDefaults.standardUserDefaults stringForKey:DXLanAddressKey];
        _address=saved.length?saved:DXLanDefaultAddress;
        _token=LanStoredToken();
        _autoCheck=[NSUserDefaults.standardUserDefaults boolForKey:DXLanAutoKey];
        _status=@{@"state":@"idle",@"text":@"未检测",@"detail":@"填写面板上的地址与令牌后点「测试连接」。",@"tools":@[],@"checkedAt":@0};
    }
    return self;
}
- (void)setAddress:(NSString *)address{
    _address=[address copy]?:@"";
    [NSUserDefaults.standardUserDefaults setObject:_address forKey:DXLanAddressKey];
}
- (void)setToken:(NSString *)token{
    _token=[token copy]?:@"";
    LanStoreToken(_token);
}
- (void)setAutoCheck:(BOOL)autoCheck{
    _autoCheck=autoCheck;
    [NSUserDefaults.standardUserDefaults setBool:autoCheck forKey:DXLanAutoKey];
}
- (void)forget{
    _generation++;
    self.status=@{@"state":@"idle",@"text":@"未检测",@"detail":@"已清除最近一次检测结果，地址与令牌保留。",@"tools":@[],@"checkedAt":@0};
    [NSNotificationCenter.defaultCenter postNotificationName:@"DXLanLinkChanged" object:nil];
}
+ (BOOL)localURL:(NSURL *)url{
    NSString *host=url.host.lowercaseString;
    if(!host.length)return NO;
    if([host isEqual:@"localhost"]||[host isEqual:@"::1"]||[host isEqual:@"[::1]"]||[host hasSuffix:@".local"])return YES;
    struct in_addr v4;
    if(inet_pton(AF_INET,host.UTF8String,&v4)==1){
        uint32_t v=ntohl(v4.s_addr);
        return (v>>24)==127||(v>>24)==10||(v>>16)==0xc0a8||(v>>20)==0xac1||(v>>16)==0xa9fe;
    }
    struct in6_addr v6;
    if(inet_pton(AF_INET6,host.UTF8String,&v6)==1)return IN6_IS_ADDR_LINKLOCAL(&v6)||IN6_IS_ADDR_LOOPBACK(&v6)||((v6.s6_addr[0]&0xfe)==0xfc);
    return NO;
}
+ (NSArray<NSString *> *)suggestions{
    NSMutableArray *out=[NSMutableArray arrayWithObject:@"http://127.0.0.1:8790/mcp"];
    struct ifaddrs *list=NULL;
    if(getifaddrs(&list)==0){
        for(struct ifaddrs *item=list;item;item=item->ifa_next){
            if(!item->ifa_addr||item->ifa_addr->sa_family!=AF_INET)continue;
            if(!(item->ifa_flags&IFF_UP)||(item->ifa_flags&IFF_LOOPBACK))continue;
            char buffer[INET_ADDRSTRLEN]={0};
            struct sockaddr_in *address=(struct sockaddr_in *)item->ifa_addr;
            if(!inet_ntop(AF_INET,&address->sin_addr,buffer,sizeof(buffer)))continue;
            NSString *url=[NSString stringWithFormat:@"http://%s:8790/mcp",buffer];
            if(![out containsObject:url])[out addObject:url];
        }
        freeifaddrs(list);
    }
    return out;
}
- (void)probeWithCompletion:(void (^)(NSDictionary *, NSError *))completion{
    NSURL *url=[NSURL URLWithString:[self.address stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    if(!url||!url.host.length||![@[@"http",@"https"] containsObject:url.scheme.lowercaseString]){
        NSError *error=LanError(@"地址无效：请填完整地址，例如 http://127.0.0.1:8790/mcp");
        [self finishFailed:error];
        if(completion)completion(self.status,error);
        return;
    }
    if(![DXLanLink localURL:url]){
        NSError *error=LanError(@"只允许本机或局域网私有地址：这个连接会把令牌以明文 HTTP 发出去，公网地址请改用插件面板的其它方式。");
        [self finishFailed:error];
        if(completion)completion(self.status,error);
        return;
    }
    NSUInteger generation=++self.generation;
    self.status=@{@"state":@"checking",@"text":@"正在连接…",@"detail":url.absoluteString,@"tools":@[],@"checkedAt":@0};
    [NSNotificationCenter.defaultCenter postNotificationName:@"DXLanLinkChanged" object:nil];

    NSString *requestID=NSUUID.UUID.UUIDString;
    NSDictionary *body=@{@"jsonrpc":@"2.0",@"id":requestID,@"method":@"tools/list",@"params":@{}};
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod=@"POST";
    request.timeoutInterval=8;
    request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json, text/event-stream" forHTTPHeaderField:@"Accept"];
    [request setValue:@"2025-06-18" forHTTPHeaderField:@"MCP-Protocol-Version"];
    if(self.token.length)[request setValue:[@"Bearer " stringByAppendingString:self.token] forHTTPHeaderField:@"Authorization"];

    NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest=8;
    config.timeoutIntervalForResource=12;
    config.HTTPCookieStorage=nil;
    config.URLCache=nil;
    if(!self.session)self.session=[NSURLSession sessionWithConfiguration:config];
    __weak typeof(self) weak=self;
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            DXLanLink *link=weak;
            if(!link||generation!=link.generation)return;
            if(error){
                NSError *mapped=LanTransportError(url,error);
                [link finishFailed:mapped];
                if(completion)completion(link.status,mapped);
                return;
            }
            NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class]?(NSHTTPURLResponse *)response:nil;
            NSInteger code=http?http.statusCode:0;
            if(code==401||code==403){
                NSError *denied=LanError(@"端口通了，但令牌不对：请回到面板「MCP 服务」复制访问令牌后重填。");
                [link finishFailed:denied];
                if(completion)completion(link.status,denied);
                return;
            }
            if(code==404||code==410){
                NSError *missing=LanError(@"这个路径不是 MCP 接口：地址需要以 /mcp 结尾。");
                [link finishFailed:missing];
                if(completion)completion(link.status,missing);
                return;
            }
            if(code<200||code>=300){
                NSError *refused=LanError([NSString stringWithFormat:@"服务拒绝了请求（HTTP %ld）：确认面板里的「MCP 服务」处于开启状态。",(long)code]);
                [link finishFailed:refused];
                if(completion)completion(link.status,refused);
                return;
            }
            NSArray *tools=LanToolsFromBody(data,http.MIMEType);
            if(!tools){
                NSError *bad=LanError(@"端口有响应，但返回内容不是 MCP 工具清单：地址可能填成了别的服务。");
                [link finishFailed:bad];
                if(completion)completion(link.status,bad);
                return;
            }
            NSMutableArray *names=[NSMutableArray new];
            for(NSDictionary *tool in tools)if([tool isKindOfClass:NSDictionary.class]&&[tool[@"name"] isKindOfClass:NSString.class])[names addObject:tool[@"name"]];
            NSString *detail=names.count?[NSString stringWithFormat:@"可用：%@",[names componentsJoinedByString:@" · "]]:@"已连通，但插件当前没有公布工具。";
            link.status=@{@"state":@"connected",@"text":[NSString stringWithFormat:@"已连接 · %lu 个工具",(unsigned long)names.count],@"detail":detail,@"tools":names,@"checkedAt":@(NSDate.date.timeIntervalSince1970)};
            [NSNotificationCenter.defaultCenter postNotificationName:@"DXLanLinkChanged" object:nil];
            if(completion)completion(link.status,nil);
        });
    }] resume];
}
- (void)finishFailed:(NSError *)error{
    self.status=@{@"state":@"failed",@"text":@"连接失败",@"detail":error.localizedDescription?:@"未知原因",@"tools":@[],@"checkedAt":@(NSDate.date.timeIntervalSince1970)};
    [NSNotificationCenter.defaultCenter postNotificationName:@"DXLanLinkChanged" object:nil];
}
@end

#pragma mark - 页面

@interface DXLanLinkPage : UITableViewController
@property(nonatomic) BOOL busy;
@end

@implementation DXLanLinkPage
- (instancetype)init{return [super initWithStyle:UITableViewStyleInsetGrouped];}
- (void)viewDidLoad{
    [super viewDidLoad];
    self.title=@"局域网连接";
    self.tableView.rowHeight=UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight=64;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"检测" style:UIBarButtonItemStylePlain target:self action:@selector(probe)];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:@"DXLanLinkChanged" object:nil];
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)changed:(NSNotification *)note{self.busy=[DXLanLink.shared.status[@"state"] isEqual:@"checking"];[self.tableView reloadData];}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    DXLanLink *link=DXLanLink.shared;
    NSTimeInterval checked=[link.status[@"checkedAt"] doubleValue];
    if(link.autoCheck&&!self.busy&&NSDate.date.timeIntervalSince1970-checked>30)[self probe];
}
- (void)probe{
    if(self.busy)return;
    self.busy=YES;
    [self.tableView reloadData];
    __weak typeof(self) weak=self;
    [DXLanLink.shared probeWithCompletion:^(NSDictionary *status,NSError *error){
        DXLanLinkPage *page=weak;
        if(!page)return;
        page.busy=NO;
        [page.tableView reloadData];
        if(error){
            UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"连接失败" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [page presentViewController:alert animated:YES completion:nil];
        }
    }];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return 3;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return section==0?3:(section==1?1:1);}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    return @[@"插件地址",@"连接检测",@"诊断"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
    if(section==0)return @"地址与令牌都在 AiFlex2 面板的「MCP 服务」里：同机使用 127.0.0.1，跨设备填手机的局域网 IP。令牌只存钥匙串，不写入配置文件或日志。";
    if(section==1)return @"检测只发一次 tools/list，不调用任何工具；宿主在后台被挂起时会连接超时，这是系统限制，把宿主切回前台即可恢复。";
    return @"这里只负责 App 到插件的连接本身。读屏、界面控制等操作仍走 FLEX 桥接，脚本与方法追踪请在插件内或电脑端 AI 里调用。";
}
- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon{
    UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    UIListContentConfiguration *content=[UIListContentConfiguration subtitleCellConfiguration];
    content.text=title;
    content.secondaryText=detail;
    content.secondaryTextProperties.color=UIColor.secondaryLabelColor;
    content.secondaryTextProperties.numberOfLines=0;
    content.image=[UIImage systemImageNamed:icon];
    content.imageProperties.tintColor=self.view.tintColor;
    cell.contentConfiguration=content;
    return cell;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    DXLanLink *link=DXLanLink.shared;
    NSDictionary *status=link.status;
    if(indexPath.section==0){
        if(indexPath.row==0){
            UITableViewCell *cell=[self cellWithTitle:@"状态" detail:status[@"detail"]?:@"" icon:[status[@"state"] isEqual:@"connected"]?@"checkmark.circle":([status[@"state"] isEqual:@"failed"]?@"exclamationmark.triangle":@"clock")];
            cell.selectionStyle=UITableViewCellSelectionStyleNone;
            UILabel *value=[UILabel new];
            value.text=status[@"text"];
            value.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
            value.textColor=[status[@"state"] isEqual:@"connected"]?UIColor.systemGreenColor:([status[@"state"] isEqual:@"failed"]?UIColor.systemOrangeColor:UIColor.secondaryLabelColor);
            [value sizeToFit];
            cell.accessoryView=value;
            return cell;
        }
        if(indexPath.row==1){
            UITableViewCell *cell=[self cellWithTitle:@"地址" detail:link.address icon:@"network"];
            cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        UITableViewCell *cell=[self cellWithTitle:@"访问令牌" detail:link.token.length?@"已保存（钥匙串）":@"未填写；面板关闭授权保护时可留空" icon:@"key"];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    if(indexPath.section==1){
        UITableViewCell *cell=[self cellWithTitle:self.busy?@"正在检测…":@"测试连接" detail:self.busy?@"等待插件响应":@"按当前地址与令牌请求一次工具清单" icon:@"bolt.horizontal"];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        cell.userInteractionEnabled=!self.busy;
        return cell;
    }
    UITableViewCell *cell=[self cellWithTitle:@"自动检测" detail:link.autoCheck?@"打开页面时连接一次":@"仅手动检测" icon:@"arrow.triangle.2.circlepath"];
    UISwitch *toggle=[UISwitch new];
    toggle.on=link.autoCheck;
    [toggle addAction:[UIAction actionWithHandler:^(UIAction *action){link.autoCheck=toggle.on;[tableView reloadData];}] forControlEvents:UIControlEventValueChanged];
    cell.accessoryView=toggle;
    cell.selectionStyle=UITableViewCellSelectionStyleNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DXLanLink *link=DXLanLink.shared;
    if(indexPath.section==1){[self probe];return;}
    if(indexPath.section==2)return;
    if(indexPath.row==0)return;
    __weak typeof(self) weak=self;
    if(indexPath.row==1){
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"插件地址" message:@"形如 http://192.168.1.8:8790/mcp。只接受本机或局域网私有地址。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
            field.text=link.address;
            field.placeholder=@"http://127.0.0.1:8790/mcp";
            field.keyboardType=UIKeyboardTypeURL;
            field.autocapitalizationType=UITextAutocapitalizationTypeNone;
            field.autocorrectionType=UITextAutocorrectionTypeNo;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"本机地址" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){link.address=DXLanDefaultAddress;[weak.tableView reloadData];}]];
        [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            NSString *value=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            link.address=value.length?value:DXLanDefaultAddress;
            [weak.tableView reloadData];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"访问令牌" message:@"从面板「MCP 服务 → 访问令牌」复制。只存钥匙串。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.text=link.token;
        field.placeholder=@"Bearer 令牌";
        field.secureTextEntry=YES;
        field.autocapitalizationType=UITextAutocapitalizationTypeNone;
        field.autocorrectionType=UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if(link.token.length)[alert addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){link.token=@"";[weak.tableView reloadData];}]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        link.token=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [weak.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

UIViewController *DXLanLinkController(void){return [DXLanLinkPage new];}
