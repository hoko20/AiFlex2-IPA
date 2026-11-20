#import "DXRemoteBuildUI.h"
#import "../Remote/DXRemoteBuild.h"

#pragma mark - 视觉

static UIColor *DXRAccent(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.62 green:0.68 blue:1.00 alpha:1]
            : [UIColor colorWithRed:0.27 green:0.35 blue:0.82 alpha:1];
    }];
}

static UIColor *DXRCanvas(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.055 green:0.063 blue:0.078 alpha:1]
            : [UIColor colorWithRed:0.953 green:0.965 blue:0.980 alpha:1];
    }];
}

static UIColor *DXRCard(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.094 green:0.106 blue:0.133 alpha:1]
            : UIColor.whiteColor;
    }];
}

static UIView *DXRSurface(void) {
    UIView *view = [UIView new];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = DXRCard();
    view.layer.cornerRadius = 18;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    return view;
}

static UILabel *DXRText(NSString *text, UIFont *font, UIColor *color) {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

static UIButton *DXRButton(NSString *title, NSString *symbol, BOOL primary, void (^handler)(void)) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config = primary ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration grayButtonConfiguration];
    config.title = title;
    config.image = [UIImage systemImageNamed:symbol];
    config.imagePadding = 6;
    config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    config.baseForegroundColor = primary ? UIColor.whiteColor : UIColor.labelColor;
    if (primary) config.baseBackgroundColor = DXRAccent();
    config.contentInsets = NSDirectionalEdgeInsetsMake(11, 14, 11, 14);
    button.configuration = config;
    [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
        if (handler) handler();
    }] forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static NSString *DXRLastLine(NSString *text) {
    NSArray<NSString *> *lines = [text componentsSeparatedByString:@"\n"];
    for (NSInteger index = (NSInteger)lines.count - 1; index >= 0; index--) {
        NSString *line = [lines[index] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (line.length) return line;
    }
    return @"";
}

#pragma mark - 选项

static NSArray<NSString *> *DXRemoteOptionTitles(void) {
    return @[@"越狱类型", @"目标架构", @"注入环境"];
}

static NSArray<NSArray<NSString *> *> *DXRemoteOptionValues(void) {
    return @[
        @[@"rootful", @"rootless", @"roothide"],
        @[@"fat", @"arm64", @"arm64e"],
        @[@"jailbreak", @"ipa_substrate", @"ipa_standalone"],
    ];
}

static NSArray<NSArray<NSString *> *> *DXRemoteOptionLabels(void) {
    return @[
        @[@"有根 Rootful（安装到 /）", @"无根 Rootless（安装到 /var/jb）", @"隐根 RootHide（动态 .jbroot）"],
        @[@"arm64 + arm64e", @"仅 arm64", @"仅 arm64e"],
        @[@"越狱注入（Substrate / ElleKit）", @"IPA 注入 · 自带 Substrate", @"IPA 注入 · 免依赖"],
    ];
}

static NSString *DXRemoteCurrentValue(NSInteger row) {
    if (row == 0) return DXRemoteBuildScheme();
    if (row == 1) return DXRemoteBuildArch();
    return DXRemoteBuildInject();
}

static void DXRemoteApplyValue(NSInteger row, NSString *value) {
    if (row == 0) DXRemoteBuildSetScheme(value);
    else if (row == 1) DXRemoteBuildSetArch(value);
    else DXRemoteBuildSetInject(value);
}

static NSString *DXRemoteCurrentLabel(NSInteger row) {
    NSArray<NSString *> *values = DXRemoteOptionValues()[row];
    NSInteger index = [values indexOfObject:DXRemoteCurrentValue(row)];
    return index == NSNotFound ? @"未设置" : DXRemoteOptionLabels()[row][index];
}

#pragma mark - 设置

@interface DXRemoteBuildSettingsController : UITableViewController <UITextFieldDelegate>
@property(nonatomic,strong) UITextField *serverField;
@property(nonatomic,strong) UIActivityIndicatorView *probeSpinner;
@property(nonatomic,assign) BOOL probing;
- (void)presentOptionsForRow:(NSInteger)row cell:(UITableViewCell *)cell;
- (void)probe;
@end

@implementation DXRemoteBuildSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"远程构建";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.backgroundColor = DXRCanvas();
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 18, 0, 18);
    self.probeSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.serverField) DXRemoteBuildSetServer(self.serverField.text);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 1 ? 3 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"服务器", @"构建选项", @"连接"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"填写打包站根地址（api.php 所在站点）。构建时会上传工程 zip，编译完成后自动下载 deb / dylib。首次使用必须填写。";
    }
    if (section == 1) return @"与打包站网页里的选项保持一致。";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = DXRCard();
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    if (indexPath.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (!self.serverField) {
            self.serverField = [UITextField new];
            self.serverField.placeholder = @"https://your-domain.com";
            self.serverField.font = [UIFont systemFontOfSize:15];
            self.serverField.keyboardType = UIKeyboardTypeURL;
            self.serverField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            self.serverField.autocorrectionType = UITextAutocorrectionTypeNo;
            self.serverField.clearButtonMode = UITextFieldViewModeWhileEditing;
            self.serverField.returnKeyType = UIReturnKeyDone;
            self.serverField.delegate = self;
        }
        self.serverField.text = DXRemoteBuildServer();
        self.serverField.translatesAutoresizingMaskIntoConstraints = NO;
        [self.serverField removeFromSuperview];
        [cell.contentView addSubview:self.serverField];
        [NSLayoutConstraint activateConstraints:@[
            [self.serverField.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:18],
            [self.serverField.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-18],
            [self.serverField.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [self.serverField.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4],
            [self.serverField.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        ]];
    } else if (indexPath.section == 1) {
        cell.textLabel.text = DXRemoteOptionTitles()[indexPath.row];
        cell.detailTextLabel.text = DXRemoteCurrentLabel(indexPath.row);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text = @"测试服务器";
        cell.textLabel.textColor = DXRAccent();
        cell.selectionStyle = self.probing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
        if (self.probing) {
            [self.probeSpinner startAnimating];
            cell.accessoryView = self.probeSpinner;
        } else {
            [self.probeSpinner stopAnimating];
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [self.serverField becomeFirstResponder];
    } else if (indexPath.section == 1) {
        [self presentOptionsForRow:indexPath.row cell:[tableView cellForRowAtIndexPath:indexPath]];
    } else {
        [self probe];
    }
}

- (void)presentOptionsForRow:(NSInteger)row cell:(UITableViewCell *)cell {
    NSArray<NSString *> *values = DXRemoteOptionValues()[row];
    NSArray<NSString *> *labels = DXRemoteOptionLabels()[row];
    NSString *current = DXRemoteCurrentValue(row);
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:DXRemoteOptionTitles()[row] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSUInteger index = 0; index < values.count; index++) {
        NSString *title = [values[index] isEqual:current] ? [@"✓ " stringByAppendingString:labels[index]] : labels[index];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            DXRemoteApplyValue(row, values[index]);
            [weakSelf.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = cell;
    sheet.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)probe {
    if (self.probing) return;
    [self.serverField resignFirstResponder];
    DXRemoteBuildSetServer(self.serverField.text);
    self.probing = YES;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];
    __weak typeof(self) weakSelf = self;
    DXRemoteBuildProbe(^(BOOL ok, NSString *message) {
        weakSelf.probing = NO;
        [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:ok ? @"连接正常" : @"连接失败" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    });
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    DXRemoteBuildSetServer(textField.text);
}

@end

#pragma mark - 构建日志

@interface DXRemoteBuildLogController : UIViewController
@property(nonatomic,copy) NSString *root;
@property(nonatomic,strong) DXRemoteBuildJob *job;
@property(nonatomic,strong) UIImageView *statusIcon;
@property(nonatomic,strong) UILabel *statusTitle;
@property(nonatomic,strong) UILabel *statusDetail;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) UITextView *logView;
@property(nonatomic,strong) UIButton *artifactsButton;
@property(nonatomic,strong) NSArray<NSString *> *artifacts;
@property(nonatomic,assign) BOOL started;
@property(nonatomic,assign) BOOL finished;
@property(nonatomic,assign) BOOL askedSetup;
- (void)showSetupAlert;
- (void)start;
- (void)appendLog:(NSString *)line;
- (void)shareArtifacts;
@end

@implementation DXRemoteBuildLogController

- (instancetype)initWithRoot:(NSString *)root {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _root = [root copy];
        _artifacts = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.root.lastPathComponent;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = DXRCanvas();

    UIView *statusCard = DXRSurface();
    [self.view addSubview:statusCard];

    self.statusIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.circle.fill"]];
    self.statusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIcon.tintColor = DXRAccent();
    self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    [statusCard addSubview:self.statusIcon];

    self.statusTitle = DXRText(@"准备远程构建", [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold], UIColor.labelColor);
    self.statusDetail = DXRText(@"正在检查配置…", [UIFont systemFontOfSize:12], UIColor.secondaryLabelColor);
    self.statusDetail.numberOfLines = 2;
    [statusCard addSubview:self.statusTitle];
    [statusCard addSubview:self.statusDetail];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = DXRAccent();
    [statusCard addSubview:self.spinner];

    UIView *logCard = DXRSurface();
    logCard.layer.cornerRadius = 16;
    [self.view addSubview:logCard];

    self.logView = [UITextView new];
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logView.backgroundColor = UIColor.clearColor;
    self.logView.textColor = UIColor.labelColor;
    self.logView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.logView.editable = NO;
    self.logView.selectable = YES;
    self.logView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    self.logView.showsVerticalScrollIndicator = YES;
    self.logView.text = @"";
    [logCard addSubview:self.logView];

    __weak typeof(self) weakSelf = self;
    UIButton *copyButton = DXRButton(@"复制日志", @"doc.on.doc", NO, ^{
        UIPasteboard.generalPasteboard.string = weakSelf.logView.text ?: @"";
    });
    self.artifactsButton = DXRButton(@"分享产物", @"square.and.arrow.up", YES, ^{
        [weakSelf shareArtifacts];
    });
    self.artifactsButton.hidden = YES;
    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[copyButton, self.artifactsButton]];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 10;
    actions.distribution = UIStackViewDistributionFillEqually;
    [self.view addSubview:actions];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [statusCard.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [statusCard.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [statusCard.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],

        [self.statusIcon.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:16],
        [self.statusIcon.centerYAnchor constraintEqualToAnchor:statusCard.centerYAnchor],
        [self.statusIcon.widthAnchor constraintEqualToConstant:26],
        [self.statusIcon.heightAnchor constraintEqualToConstant:26],

        [self.statusTitle.leadingAnchor constraintEqualToAnchor:self.statusIcon.trailingAnchor constant:12],
        [self.statusTitle.topAnchor constraintEqualToAnchor:statusCard.topAnchor constant:14],
        [self.statusTitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.spinner.leadingAnchor constant:-10],

        [self.statusDetail.leadingAnchor constraintEqualToAnchor:self.statusTitle.leadingAnchor],
        [self.statusDetail.topAnchor constraintEqualToAnchor:self.statusTitle.bottomAnchor constant:3],
        [self.statusDetail.trailingAnchor constraintLessThanOrEqualToAnchor:self.spinner.leadingAnchor constant:-10],
        [self.statusDetail.bottomAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:-14],

        [self.spinner.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-16],
        [self.spinner.centerYAnchor constraintEqualToAnchor:statusCard.centerYAnchor],

        [actions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [actions.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [actions.heightAnchor constraintEqualToConstant:46],

        [logCard.topAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:12],
        [logCard.bottomAnchor constraintEqualToAnchor:actions.topAnchor constant:-12],
        [logCard.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [logCard.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],

        [self.logView.topAnchor constraintEqualToAnchor:logCard.topAnchor],
        [self.logView.bottomAnchor constraintEqualToAnchor:logCard.bottomAnchor],
        [self.logView.leadingAnchor constraintEqualToAnchor:logCard.leadingAnchor],
        [self.logView.trailingAnchor constraintEqualToAnchor:logCard.trailingAnchor],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.askedSetup) return;
    self.askedSetup = YES;
    if (!DXRemoteBuildConfigured()) {
        [self showSetupAlert];
    } else {
        [self start];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.started && !self.finished) {
        self.finished = YES;
        [self.job cancel];
    }
}

- (void)showSetupAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未配置打包服务器"
                                                                   message:@"远程构建需要先在「设置 → 构建 → 远程构建」填写打包站地址。本机「编译」不受影响。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [weakSelf.navigationController popViewControllerAnimated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UINavigationController *navigation = weakSelf.navigationController;
        [navigation popViewControllerAnimated:NO];
        [navigation pushViewController:DXRemoteBuildSettingsController() animated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)start {
    if (self.started) return;
    self.started = YES;
    self.finished = NO;
    [self.spinner startAnimating];
    self.statusTitle.text = @"正在构建";
    self.statusDetail.text = @"正在打包工程…";
    __weak typeof(self) weakSelf = self;
    self.job = [DXRemoteBuildJob runProject:self.root progress:^(NSString *line) {
        [weakSelf appendLog:line];
        NSString *stage = DXRLastLine(line);
        if (stage.length > 90) stage = [[stage substringToIndex:90] stringByAppendingString:@"…"];
        if (stage.length) weakSelf.statusDetail.text = stage;
    } completion:^(BOOL success, NSArray<NSString *> *artifacts, NSString *summary) {
        weakSelf.finished = YES;
        [weakSelf.spinner stopAnimating];
        weakSelf.statusIcon.image = [UIImage systemImageNamed:success ? @"checkmark.circle.fill" : @"xmark.octagon.fill"];
        weakSelf.statusIcon.tintColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
        weakSelf.statusTitle.text = success ? @"构建成功" : @"构建失败";
        weakSelf.statusDetail.text = [summary componentsSeparatedByString:@"\n"].firstObject;
        weakSelf.artifacts = artifacts ?: @[];
        weakSelf.artifactsButton.hidden = weakSelf.artifacts.count == 0;
        [weakSelf appendLog:summary];
    }];
}

- (void)appendLog:(NSString *)line {
    if (!line.length) return;
    NSString *existing = self.logView.text ?: @"";
    NSString *text = [existing stringByAppendingFormat:@"%@\n", line];
    if (text.length > 60000) text = [text substringFromIndex:text.length - 60000];
    self.logView.text = text;
    if (text.length) [self.logView scrollRangeToVisible:NSMakeRange(text.length - 1, 1)];
}

- (void)shareArtifacts {
    if (!self.artifacts.count) return;
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (NSString *path in self.artifacts) [urls addObject:[NSURL fileURLWithPath:path]];
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
    share.popoverPresentationController.sourceView = self.artifactsButton;
    share.popoverPresentationController.sourceRect = self.artifactsButton.bounds;
    [self presentViewController:share animated:YES completion:nil];
}

@end

#pragma mark - 入口

UIViewController *DXRemoteBuildSettingsController(void) {
    return [[DXRemoteBuildSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
}

UIViewController *DXRemoteBuildLogController(NSString *projectRoot) {
    return [[DXRemoteBuildLogController alloc] initWithRoot:projectRoot];
}
