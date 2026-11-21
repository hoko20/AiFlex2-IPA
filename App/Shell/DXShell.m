#import "DXShell.h"
#import "../Studio.h"
#import "../StorageSpace.h"
#import "../AI/AIV2Contracts.h"
#import "../AI/AIContracts.h"
#import "../AI/UI/TFAIPersonaUI.h"
#import "../AI/Agent/TFAIBuildQueue.h"
#import "../AI/Agent/TFAIAgentUI.h"
extern BOOL TMCStudioTrashProject(NSString *root, NSError **error);
#import "../Remote/DXFlexPluginInfo.h"
#import "../Remote/DXRemoteBuild.h"
#import "DXRemoteBuildUI.h"

extern UIViewController *TFAIISHToolsController(NSString *session);

#pragma mark - 视觉基础

static UIColor *DXAccent(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.62 green:0.68 blue:1.00 alpha:1]
            : [UIColor colorWithRed:0.27 green:0.35 blue:0.82 alpha:1];
    }];
}

static UIColor *DXCanvas(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.055 green:0.063 blue:0.078 alpha:1]
            : [UIColor colorWithRed:0.953 green:0.965 blue:0.980 alpha:1];
    }];
}

static UIColor *DXCard(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.094 green:0.106 blue:0.133 alpha:1]
            : UIColor.whiteColor;
    }];
}

static UILabel *DXText(NSString *text, UIFont *font, UIColor *color) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

static UIView *DXSurface(void) {
    UIView *view = [UIView new];
    view.backgroundColor = DXCard();
    view.layer.cornerRadius = 20;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    return view;
}

static UIView *DXChip(NSString *text, UIColor *tint) {
    UILabel *label = DXText(text, [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold], tint);
    UIView *chip = [UIView new];
    chip.backgroundColor = [tint colorWithAlphaComponent:0.13];
    chip.layer.cornerRadius = 7;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [chip addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:8],
        [label.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-8],
        [label.topAnchor constraintEqualToAnchor:chip.topAnchor constant:4],
        [label.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor constant:-4],
    ]];
    return chip;
}

static UIButton *DXPrimaryButton(NSString *title, NSString *symbol, void (^handler)(void)) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.title = title;
    config.image = [UIImage systemImageNamed:symbol];
    config.imagePadding = 7;
    config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    config.baseBackgroundColor = DXAccent();
    config.baseForegroundColor = UIColor.whiteColor;
    config.contentInsets = NSDirectionalEdgeInsetsMake(13, 16, 13, 16);
    button.configuration = config;
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
        if (handler) handler();
    }] forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static UIButton *DXGhostButton(NSString *title, NSString *symbol, void (^handler)(void)) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config = [UIButtonConfiguration grayButtonConfiguration];
    config.title = title;
    config.image = [UIImage systemImageNamed:symbol];
    config.imagePadding = 7;
    config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    config.baseForegroundColor = UIColor.labelColor;
    config.contentInsets = NSDirectionalEdgeInsetsMake(13, 16, 13, 16);
    button.configuration = config;
    [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
        if (handler) handler();
    }] forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static UIControl *DXMenuRow(NSString *title, NSString *subtitle, NSString *symbol, void (^handler)(void)) {
    UIControl *row = [UIControl new];
    UIView *iconBox = [UIView new];
    iconBox.translatesAutoresizingMaskIntoConstraints = NO;
    iconBox.backgroundColor = [DXAccent() colorWithAlphaComponent:0.12];
    iconBox.layer.cornerRadius = 11;
    iconBox.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = DXAccent();
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBox addSubview:icon];
    UILabel *titleLabel = DXText(title, [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold], UIColor.labelColor);
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *subtitleLabel = DXText(subtitle, [UIFont systemFontOfSize:12], UIColor.secondaryLabelColor);
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = UIColor.tertiaryLabelColor;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:iconBox];
    [row addSubview:titleLabel];
    [row addSubview:subtitleLabel];
    [row addSubview:chevron];
    [NSLayoutConstraint activateConstraints:@[
        [iconBox.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [iconBox.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconBox.widthAnchor constraintEqualToConstant:34],
        [iconBox.heightAnchor constraintEqualToConstant:34],
        [icon.widthAnchor constraintEqualToConstant:18],
        [icon.heightAnchor constraintEqualToConstant:18],
        [icon.centerXAnchor constraintEqualToAnchor:iconBox.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconBox.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconBox.trailingAnchor constant:12],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:13],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-10],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-10],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-13],
        [chevron.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14],
        [chevron.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:10],
        [chevron.heightAnchor constraintEqualToConstant:16],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:62],
    ]];
    [row addAction:[UIAction actionWithHandler:^(UIAction *action) {
        if (handler) handler();
    }] forControlEvents:UIControlEventTouchUpInside];
    return row;
}

static void DXApplyWindowTheme(UIViewController *controller) {
    NSInteger theme = [NSUserDefaults.standardUserDefaults integerForKey:@"StudioTheme"];
    UIUserInterfaceStyle style = theme == 1 ? UIUserInterfaceStyleDark : theme == 2 ? UIUserInterfaceStyleLight : UIUserInterfaceStyleUnspecified;
    controller.overrideUserInterfaceStyle = style;
    controller.navigationController.overrideUserInterfaceStyle = style;
    controller.view.window.overrideUserInterfaceStyle = style;
}

static NSDictionary *DXConfig(NSString *root) {
    NSData *data = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"MobileCompiler.json"]];
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *DXControlValue(NSString *root, NSString *key) {
    NSString *text = [NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"control"] encoding:NSUTF8StringEncoding error:nil];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        if (![[line substringToIndex:colon.location] isEqualToString:key]) continue;
        return [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return nil;
}

static NSString *DXFreeSpace(void) {
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    NSNumber *bytes = attributes[NSFileSystemFreeSize];
    if (!bytes) return @"空间未知";
    double gb = bytes.doubleValue / 1073741824.0;
    if (gb >= 1) return [NSString stringWithFormat:@"可用 %.1f GB", gb];
    return [NSString stringWithFormat:@"可用 %.0f MB", bytes.doubleValue / 1048576.0];
}

static UIStackView *DXScrollStack(UIViewController *controller, UIScrollView **outScroll) {
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.showsVerticalScrollIndicator = NO;
    [controller.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:controller.view.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor],
    ]];
    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-32],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40],
    ]];
    if (outScroll) *outScroll = scroll;
    return stack;
}

#pragma mark - 工作台

@interface DXWorkbenchController : UIViewController
@property(nonatomic,strong) UIStackView *projectStack;
@property(nonatomic,strong) UILabel *storageLabel;
@property(nonatomic,strong) UILabel *queueLabel;
@property(nonatomic,strong) UILabel *queueDetailLabel;
@property(nonatomic,strong) UILabel *countLabel;
@property(nonatomic,assign) BOOL selecting;
@property(nonatomic,strong) NSMutableSet<NSString *> *selectedRoots;
@property(nonatomic,strong) UIBarButtonItem *deleteItem;
@end

@implementation DXWorkbenchController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DXCanvas();
    self.title = @"工作台";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.selectedRoots = [NSMutableSet set];
    [self installNormalBarItems];

    UIStackView *stack = DXScrollStack(self, NULL);
    UIStackView *header = [UIStackView new];
    header.axis = UILayoutConstraintAxisVertical;
    header.spacing = 5;
    [header addArrangedSubview:DXText(@"工作台", [UIFont systemFontOfSize:30 weight:UIFontWeightBold], UIColor.labelColor)];
    [header addArrangedSubview:DXText(@"本机编译 · MCP 运行时联调", [UIFont systemFontOfSize:13 weight:UIFontWeightMedium], UIColor.secondaryLabelColor)];
    [stack addArrangedSubview:header];
    [stack setCustomSpacing:14 afterView:header];

    UIView *status = DXSurface();
    UIStackView *statusRow = [UIStackView new];
    statusRow.translatesAutoresizingMaskIntoConstraints = NO;
    statusRow.axis = UILayoutConstraintAxisHorizontal;
    statusRow.distribution = UIStackViewDistributionFillEqually;
    statusRow.spacing = 4;
    [status addSubview:statusRow];
    [NSLayoutConstraint activateConstraints:@[
        [statusRow.leadingAnchor constraintEqualToAnchor:status.leadingAnchor constant:8],
        [statusRow.trailingAnchor constraintEqualToAnchor:status.trailingAnchor constant:-8],
        [statusRow.topAnchor constraintEqualToAnchor:status.topAnchor constant:12],
        [statusRow.bottomAnchor constraintEqualToAnchor:status.bottomAnchor constant:-12],
    ]];
    self.storageLabel = [self statusCellIn:statusRow symbol:@"internaldrive" caption:@"存储" value:@"—"];
    self.queueLabel = [self statusCellIn:statusRow symbol:@"hammer" caption:@"构建" value:@"—"];
    [self statusCellIn:statusRow symbol:@"checkmark.seal" caption:@"工具链" value:@"就绪"];
    [stack addArrangedSubview:status];

    UIView *queueCard = DXSurface();
    UIStackView *queueRow = [UIStackView new];
    queueRow.translatesAutoresizingMaskIntoConstraints = NO;
    queueRow.axis = UILayoutConstraintAxisHorizontal;
    queueRow.alignment = UIStackViewAlignmentCenter;
    queueRow.spacing = 12;
    UIView *queueBox = [UIView new];
    queueBox.translatesAutoresizingMaskIntoConstraints = NO;
    queueBox.backgroundColor = [DXAccent() colorWithAlphaComponent:0.12];
    queueBox.layer.cornerRadius = 11;
    queueBox.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageView *queueIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"hammer"]];
    queueIcon.translatesAutoresizingMaskIntoConstraints = NO;
    queueIcon.tintColor = DXAccent();
    queueIcon.contentMode = UIViewContentModeScaleAspectFit;
    [queueBox addSubview:queueIcon];
    [NSLayoutConstraint activateConstraints:@[
        [queueBox.widthAnchor constraintEqualToConstant:34],
        [queueBox.heightAnchor constraintEqualToConstant:34],
        [queueIcon.widthAnchor constraintEqualToConstant:17],
        [queueIcon.heightAnchor constraintEqualToConstant:17],
        [queueIcon.centerXAnchor constraintEqualToAnchor:queueBox.centerXAnchor],
        [queueIcon.centerYAnchor constraintEqualToAnchor:queueBox.centerYAnchor],
    ]];
    UIStackView *queueText = [UIStackView new];
    queueText.axis = UILayoutConstraintAxisVertical;
    queueText.spacing = 1;
    [queueText addArrangedSubview:DXText(@"构建队列", [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold], UIColor.labelColor)];
    self.queueDetailLabel = DXText(@"空闲", [UIFont systemFontOfSize:11], UIColor.secondaryLabelColor);
    [queueText addArrangedSubview:self.queueDetailLabel];
    [queueRow addArrangedSubview:queueBox];
    [queueRow addArrangedSubview:queueText];
    UIButton *queueOpen = DXGhostButton(@"查看", @"list.bullet.rectangle", ^{
        [self.navigationController pushViewController:TFAIBuildQueueController() animated:YES];
    });
    [queueRow addArrangedSubview:queueOpen];
    [queueCard addSubview:queueRow];
    [NSLayoutConstraint activateConstraints:@[
        [queueRow.leadingAnchor constraintEqualToAnchor:queueCard.leadingAnchor constant:12],
        [queueRow.trailingAnchor constraintEqualToAnchor:queueCard.trailingAnchor constant:-12],
        [queueRow.topAnchor constraintEqualToAnchor:queueCard.topAnchor constant:10],
        [queueRow.bottomAnchor constraintEqualToAnchor:queueCard.bottomAnchor constant:-10],
    ]];
    [stack addArrangedSubview:queueCard];

    UIStackView *actions = [UIStackView new];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 10;
    actions.distribution = UIStackViewDistributionFillEqually;
    [actions addArrangedSubview:DXPrimaryButton(@"新建工程", @"plus", ^{ [self createProject]; })];
    [actions addArrangedSubview:DXGhostButton(@"导入工程", @"square.and.arrow.down", ^{ [self importProject]; })];
    [stack addArrangedSubview:actions];
    [stack setCustomSpacing:24 afterView:actions];

    UIStackView *section = [UIStackView new];
    section.axis = UILayoutConstraintAxisHorizontal;
    section.alignment = UIStackViewAlignmentCenter;
    UILabel *title = DXText(@"本机工程", [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold], UIColor.labelColor);
    UIView *spacer = [UIView new];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    self.countLabel = DXText(@"0", [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium], UIColor.secondaryLabelColor);
    [section addArrangedSubview:title];
    [section addArrangedSubview:spacer];
    [section addArrangedSubview:self.countLabel];
    [stack addArrangedSubview:section];
    [stack setCustomSpacing:12 afterView:section];

    self.projectStack = [UIStackView new];
    self.projectStack.axis = UILayoutConstraintAxisVertical;
    self.projectStack.spacing = 12;
    [stack addArrangedSubview:self.projectStack];
}

- (UILabel *)statusCellIn:(UIStackView *)row symbol:(NSString *)symbol caption:(NSString *)caption value:(NSString *)value {
    UIStackView *cell = [UIStackView new];
    cell.axis = UILayoutConstraintAxisVertical;
    cell.spacing = 3;
    cell.alignment = UIStackViewAlignmentCenter;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.tintColor = DXAccent();
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon.heightAnchor constraintEqualToConstant:18].active = YES;
    UILabel *captionLabel = DXText(caption, [UIFont systemFontOfSize:10 weight:UIFontWeightMedium], UIColor.tertiaryLabelColor);
    UILabel *valueLabel = DXText(value, [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold], UIColor.labelColor);
    valueLabel.textAlignment = NSTextAlignmentCenter;
    [cell addArrangedSubview:icon];
    [cell addArrangedSubview:captionLabel];
    [cell addArrangedSubview:valueLabel];
    [row addArrangedSubview:cell];
    return valueLabel;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DXApplyWindowTheme(self);
    if (self.selecting) {
        self.selecting = NO;
        [self.selectedRoots removeAllObjects];
        [self installNormalBarItems];
    }
    [self reload];
}

- (void)installNormalBarItems {
    __weak typeof(self) weakSelf = self;
    UIBarButtonItem *select = [[UIBarButtonItem alloc] initWithTitle:@"选择" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelection)];
    UIAction *clear = [UIAction actionWithTitle:@"清空全部工程" image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(UIAction *action) { [weakSelf confirmClearAllProjects]; }];
    clear.attributes = UIMenuElementAttributesDestructive;
    UIBarButtonItem *more = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:[UIMenu menuWithTitle:@"" children:@[clear]]];
    self.navigationItem.rightBarButtonItems = @[select, more];
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationController.toolbarHidden = YES;
    self.toolbarItems = nil;
    self.deleteItem = nil;
}

- (void)installSelectionBarItems {
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelection)];
    self.deleteItem = [[UIBarButtonItem alloc] initWithTitle:@"删除（0）" style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelectedProjects)];
    self.deleteItem.tintColor = UIColor.systemRedColor;
    self.navigationItem.rightBarButtonItems = @[self.deleteItem, cancel];
    UIBarButtonItem *all = [[UIBarButtonItem alloc] initWithTitle:@"全选" style:UIBarButtonItemStylePlain target:self action:@selector(selectAllProjects)];
    all.enabled = TFAIInternalProjects().count > 0;
    self.navigationItem.leftBarButtonItem = all;
    self.navigationController.toolbarHidden = YES;
    self.toolbarItems = nil;
    [self updateSelectionToolbar];
}

- (void)updateSelectionToolbar {
    self.deleteItem.title = [NSString stringWithFormat:@"删除（%lu）", (unsigned long)self.selectedRoots.count];
    self.deleteItem.enabled = self.selectedRoots.count > 0;
}

- (void)toggleSelection {
    self.selecting = !self.selecting;
    [self.selectedRoots removeAllObjects];
    if (self.selecting) [self installSelectionBarItems];
    else [self installNormalBarItems];
    [self reload];
}

- (void)selectAllProjects {
    [self.selectedRoots removeAllObjects];
    for (NSDictionary *project in TFAIInternalProjects()) [self.selectedRoots addObject:project[@"root"]];
    [self reload];
    [self updateSelectionToolbar];
}

- (void)toggleProjectTap:(UITapGestureRecognizer *)gesture {
    NSString *root = gesture.view.accessibilityIdentifier;
    if (!root.length) return;
    if ([self.selectedRoots containsObject:root]) [self.selectedRoots removeObject:root];
    else [self.selectedRoots addObject:root];
    [self reload];
    [self updateSelectionToolbar];
}

- (void)deleteSelectedProjects {
    NSArray<NSDictionary *> *projects = [TFAIInternalProjects() filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *project, NSDictionary *bindings) {
        return [self.selectedRoots containsObject:project[@"root"]];
    }]];
    if (!projects.count) return;
    [self confirmTrashProjects:projects title:@"删除所选工程？"];
}

- (void)confirmClearAllProjects {
    NSArray<NSDictionary *> *projects = TFAIInternalProjects();
    if (!projects.count) return;
    [self confirmTrashProjects:projects title:@"清空全部工程？"];
}

- (void)confirmTrashProjects:(NSArray<NSDictionary *> *)projects title:(NSString *)title {
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:[NSString stringWithFormat:@"将把 %lu 个工程移入回收站保留 7 天，期间可恢复。", (unsigned long)projects.count] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSMutableArray<NSString *> *failures = [NSMutableArray array];
        for (NSDictionary *project in projects) {
            NSError *error = nil;
            if (!TMCStudioTrashProject(project[@"root"], &error)) [failures addObject:[NSString stringWithFormat:@"%@：%@", project[@"name"] ?: [project[@"root"] lastPathComponent], error.localizedDescription ?: @"无法移动到回收站"]];
        }
        [weakSelf.selectedRoots removeAllObjects];
        if (weakSelf.selecting) {
            weakSelf.selecting = NO;
            [weakSelf installNormalBarItems];
        }
        [weakSelf reload];
        if (failures.count) {
            UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"部分工程未删除" message:[failures componentsJoinedByString:@"\n"] preferredStyle:UIAlertControllerStyleAlert];
            [failure addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:failure animated:YES completion:nil];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reload {
    NSArray<NSDictionary *> *projects = TFAIInternalProjects();
    self.countLabel.text = [NSString stringWithFormat:@"%lu 个", (unsigned long)projects.count];
    self.storageLabel.text = DXFreeSpace();
    NSUInteger tasks = TFAIBuildQueue.shared.tasks.count;
    self.queueLabel.text = tasks ? [NSString stringWithFormat:@"%lu 个", (unsigned long)tasks] : @"空闲";
    self.queueDetailLabel.text = tasks ? [NSString stringWithFormat:@"%lu 个任务进行中", (unsigned long)tasks] : @"空闲，暂无任务";

    for (UIView *view in self.projectStack.arrangedSubviews.copy) {
        [self.projectStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    if (!projects.count) {
        [self.projectStack addArrangedSubview:[self emptyCard]];
        return;
    }
    for (NSDictionary *project in projects) {
        [self.projectStack addArrangedSubview:[self cardForProject:project]];
    }
}

- (UIView *)emptyCard {
    UIView *card = DXSurface();
    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox"]];
    icon.tintColor = DXAccent();
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon.heightAnchor constraintEqualToConstant:34].active = YES;
    UILabel *title = DXText(@"还没有工程", [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold], UIColor.labelColor);
    UILabel *detail = DXText(@"新建一个 dylib 或 deb 工程，开始写代码并本机编译。", [UIFont systemFontOfSize:12], UIColor.secondaryLabelColor);
    detail.textAlignment = NSTextAlignmentCenter;
    UIButton *button = DXPrimaryButton(@"新建工程", @"plus", ^{ [self createProject]; });
    [stack addArrangedSubview:icon];
    [stack addArrangedSubview:title];
    [stack addArrangedSubview:detail];
    [stack addArrangedSubview:button];
    [stack setCustomSpacing:16 afterView:detail];
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:22],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-22],
    ]];
    return card;
}

- (UIView *)cardForProject:(NSDictionary *)project {
    NSString *root = project[@"root"];
    NSString *name = project[@"name"] ?: root.lastPathComponent;
    NSDictionary *config = DXConfig(root);
    BOOL library = [config[@"package"] isEqual:@NO];
    NSArray *sources = [config[@"sources"] isKindOfClass:NSArray.class] ? config[@"sources"] : @[];
    NSString *bundle = DXControlValue(root, @"Package") ?: config[@"name"] ?: @"未设置包标识";

    UIView *card = DXSurface();
    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];

    UIView *iconBox = [UIView new];
    iconBox.translatesAutoresizingMaskIntoConstraints = NO;
    iconBox.backgroundColor = [DXAccent() colorWithAlphaComponent:0.12];
    iconBox.layer.cornerRadius = 12;
    iconBox.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"curlybraces.square"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = DXAccent();
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBox addSubview:icon];
    [NSLayoutConstraint activateConstraints:@[
        [iconBox.widthAnchor constraintEqualToConstant:42],
        [iconBox.heightAnchor constraintEqualToConstant:42],
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22],
        [icon.centerXAnchor constraintEqualToAnchor:iconBox.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconBox.centerYAnchor],
    ]];

    UIStackView *texts = [UIStackView new];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 3;
    UILabel *nameLabel = DXText(name, [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold], UIColor.labelColor);
    UILabel *bundleLabel = DXText(bundle, [UIFont systemFontOfSize:12], UIColor.secondaryLabelColor);
    bundleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [texts addArrangedSubview:nameLabel];
    [texts addArrangedSubview:bundleLabel];

    UIStackView *top = [UIStackView new];
    top.axis = UILayoutConstraintAxisHorizontal;
    top.spacing = 12;
    top.alignment = UIStackViewAlignmentCenter;
    [top addArrangedSubview:iconBox];
    [top addArrangedSubview:texts];
    [texts setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
    [more setImage:[UIImage systemImageNamed:@"ellipsis.circle"] forState:UIControlStateNormal];
    more.tintColor = UIColor.tertiaryLabelColor;
    more.showsMenuAsPrimaryAction = YES;
    __weak typeof(self) weakSelf = self;
    more.menu = [UIMenu menuWithTitle:@"" children:@[
        [UIAction actionWithTitle:@"远程构建" image:[UIImage systemImageNamed:@"icloud.and.arrow.up"] identifier:nil handler:^(UIAction *action){ [weakSelf remoteBuildProject:root]; }],
        [UIAction actionWithTitle:@"删除工程" image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(UIAction *action){ [weakSelf confirmTrashProject:root name:name]; }],
    ]];
    if (self.selecting) {
        BOOL chosen = [self.selectedRoots containsObject:root];
        UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:chosen ? @"checkmark.circle.fill" : @"circle"]];
        check.tintColor = chosen ? DXAccent() : UIColor.tertiaryLabelColor;
        check.contentMode = UIViewContentModeScaleAspectFit;
        [check.widthAnchor constraintEqualToConstant:24].active = YES;
        [check.heightAnchor constraintEqualToConstant:24].active = YES;
        [top addArrangedSubview:check];
        card.layer.borderWidth = 2;
        card.layer.borderColor = (chosen ? DXAccent() : UIColor.clearColor).CGColor;
        card.accessibilityIdentifier = root;
        [card addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleProjectTap:)]];
    } else {
        [top addArrangedSubview:more];
    }
    [stack addArrangedSubview:top];

    UIStackView *chips = [UIStackView new];
    chips.axis = UILayoutConstraintAxisHorizontal;
    chips.spacing = 8;
    [chips addArrangedSubview:DXChip(library ? @"dylib" : @"deb", DXAccent())];
    [chips addArrangedSubview:DXChip([NSString stringWithFormat:@"%lu 个源文件", (unsigned long)sources.count], UIColor.secondaryLabelColor)];
    [stack addArrangedSubview:chips];

    UIStackView *actions = [UIStackView new];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 10;
    actions.distribution = UIStackViewDistributionFillEqually;
    [actions addArrangedSubview:DXGhostButton(@"编辑", @"square.and.pencil", ^{ [self openProject:root]; })];
    [actions addArrangedSubview:DXPrimaryButton(@"编译", @"hammer", ^{ [self buildProject:root]; })];
    [stack addArrangedSubview:actions];
    if (self.selecting) actions.hidden = YES;
    return card;
}

- (void)confirmTrashProject:(NSString *)root name:(NSString *)name {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"删除工程？" message:[NSString stringWithFormat:@"“%@”将移入回收站保留 7 天，期间可恢复。", name] preferredStyle:UIAlertControllerStyleAlert];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error = nil;
        if (!TMCStudioTrashProject(root, &error)) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除失败" message:error.localizedDescription ?: @"无法移动到回收站" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:alert animated:YES completion:nil];
            return;
        }
        [weakSelf reload];
    }]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)createProject {
    [self.navigationController pushViewController:TMCStudioCreateController() animated:YES];
}

- (void)importProject {
    __weak typeof(self) weak = self;
    TMCStudioImportProject(self, ^(NSString *root) {
        if (root.length) [weak openProject:root];
    });
}

- (void)openProject:(NSString *)root {
    UIViewController *editor = TMCStudioEditorController(root);
    if (editor) [self.navigationController pushViewController:editor animated:YES];
}

- (void)buildProject:(NSString *)root {
    if (!TMCStudioResumeBuild(root, self.navigationController)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法开始构建" message:@"工程目录可能已移动，请重新创建或导入。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)remoteBuildProject:(NSString *)root {
    [self.navigationController pushViewController:DXRemoteBuildLogController(root) animated:YES];
}

@end

#pragma mark - AI

@interface DXAIHubController : UIViewController
@end

@implementation DXAIHubController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DXCanvas();
    self.title = @"AI";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    UIStackView *stack = DXScrollStack(self, NULL);
    UIView *hero = DXSurface();
    UIStackView *heroStack = [UIStackView new];
    heroStack.translatesAutoresizingMaskIntoConstraints = NO;
    heroStack.axis = UILayoutConstraintAxisVertical;
    heroStack.spacing = 8;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    icon.tintColor = DXAccent();
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon.heightAnchor constraintEqualToConstant:26].active = YES;
    [heroStack addArrangedSubview:icon];
    [heroStack addArrangedSubview:DXText(@"AI 助手", [UIFont systemFontOfSize:22 weight:UIFontWeightBold], UIColor.labelColor)];
    UILabel *detail = DXText(@"连接目标 App 内的 AiFlex2 运行时，读现场、改代码、再编译。", [UIFont systemFontOfSize:13], UIColor.secondaryLabelColor);
    [heroStack addArrangedSubview:detail];
    [hero addSubview:heroStack];
    [NSLayoutConstraint activateConstraints:@[
        [heroStack.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:18],
        [heroStack.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-18],
        [heroStack.topAnchor constraintEqualToAnchor:hero.topAnchor constant:20],
        [heroStack.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-20],
    ]];
    [stack addArrangedSubview:hero];
    [stack setCustomSpacing:16 afterView:hero];

    UIView *menu = DXSurface();
    UIStackView *rows = [UIStackView new];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 0;
    [menu addSubview:rows];
    [NSLayoutConstraint activateConstraints:@[
        [rows.leadingAnchor constraintEqualToAnchor:menu.leadingAnchor],
        [rows.trailingAnchor constraintEqualToAnchor:menu.trailingAnchor],
        [rows.topAnchor constraintEqualToAnchor:menu.topAnchor constant:4],
        [rows.bottomAnchor constraintEqualToAnchor:menu.bottomAnchor constant:-4],
    ]];
    __weak typeof(self) weak = self;
    [rows addArrangedSubview:DXMenuRow(@"新会话", @"选择构建项目并开始对话", @"bubble.left.and.text.bubble.right", ^{
        TMCStudioNewAISession(weak.navigationController);
    })];
    [rows addArrangedSubview:[self separator]];
    [rows addArrangedSubview:DXMenuRow(@"历史会话", @"继续之前的对话", @"clock.arrow.circlepath", ^{
        UIViewController *list = TMCStudioAISessionList(weak.navigationController);
        if (list) [weak.navigationController pushViewController:list animated:YES];
    })];
    [rows addArrangedSubview:[self separator]];
    [rows addArrangedSubview:DXMenuRow(@"人设与提示词", @"设定助手风格和系统提示", @"person.crop.circle", ^{
        [weak.navigationController pushViewController:TFAIPersonaController() animated:YES];
    })];
    [rows addArrangedSubview:[self separator]];
    [rows addArrangedSubview:DXMenuRow(@"模型与供应商", @"API 地址、密钥与用量", @"slider.horizontal.3", ^{
        [weak.navigationController pushViewController:TFAISettingsController(nil) animated:YES];
    })];
    [rows addArrangedSubview:[self separator]];
    [rows addArrangedSubview:DXMenuRow(@"MCP 连接", @"服务、工具授权与会话开关", @"network", ^{
        [weak.navigationController pushViewController:TFAIMCPServicesController(nil) animated:YES];
    })];
    [stack addArrangedSubview:menu];

    UILabel *note = DXText(@"运行时工具受手机端授权控制：只读、敏感读取、界面控制、脚本与方法追踪分别开放。", [UIFont systemFontOfSize:11], UIColor.tertiaryLabelColor);
    [stack addArrangedSubview:note];
}

- (UIView *)separator {
    UIView *line = [UIView new];
    line.backgroundColor = UIColor.separatorColor;
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    UIView *wrapper = [UIView new];
    [wrapper addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [line.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:60],
        [line.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [line.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
        [line.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],
    ]];
    return wrapper;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DXApplyWindowTheme(self);
}

@end

#pragma mark - 产物

// 「产物」页只读取编译器发布的专用目录 Documents/构建产物，不递归整个沙盒。
// 每次构建成功后 TMCDocumentPublishBuild 会把可交付的 deb / dylib 连同日志、报告
// 复制到这里（见 DocumentPresentation.h）；Build-<UUID> 工作目录与 DebugSymbols
// 调试副本都是隐藏的中间文件，从不被复制进来。这样既避免全盘扫描的内存开销，
// 也从源头杜绝中间产物混入列表。
static NSString *DXArtifactRoot(void) {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:@"构建产物"];
}

@interface DXArtifactsController : UITableViewController
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@property(nonatomic,strong) UIRefreshControl *refresh;
@property(nonatomic,assign) BOOL selecting;
@property(nonatomic,strong) NSMutableSet<NSString *> *selectedPaths;
@property(nonatomic,strong) UIBarButtonItem *deleteItem;
@end

@implementation DXArtifactsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"产物";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.backgroundColor = DXCanvas();
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 74;
    self.refresh = [UIRefreshControl new];
    [self.refresh addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refresh;
    self.selectedPaths = [NSMutableSet set];
    [self installNormalBarItems];
}

- (void)installNormalBarItems {
    __weak typeof(self) weakSelf = self;
    UIBarButtonItem *select = [[UIBarButtonItem alloc] initWithTitle:@"选择" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelection)];
    UIAction *clear = [UIAction actionWithTitle:@"清空全部产物" image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(UIAction *action) { [weakSelf confirmClearAll]; }];
    clear.attributes = UIMenuElementAttributesDestructive;
    UIBarButtonItem *more = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:[UIMenu menuWithTitle:@"" children:@[clear]]];
    self.navigationItem.rightBarButtonItems = @[select, more];
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationController.toolbarHidden = YES;
    self.toolbarItems = nil;
    self.deleteItem = nil;
}

- (void)installSelectionBarItems {
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelection)];
    self.deleteItem = [[UIBarButtonItem alloc] initWithTitle:@"删除（0）" style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelectedItems)];
    self.deleteItem.tintColor = UIColor.systemRedColor;
    self.navigationItem.rightBarButtonItems = @[self.deleteItem, cancel];
    UIBarButtonItem *all = [[UIBarButtonItem alloc] initWithTitle:@"全选" style:UIBarButtonItemStylePlain target:self action:@selector(selectAllItems)];
    all.enabled = self.items.count > 0;
    self.navigationItem.leftBarButtonItem = all;
    self.navigationController.toolbarHidden = YES;
    self.toolbarItems = nil;
    [self updateSelectionToolbar];
}

- (void)updateSelectionToolbar {
    self.deleteItem.title = [NSString stringWithFormat:@"删除（%lu）", (unsigned long)self.selectedPaths.count];
    self.deleteItem.enabled = self.selectedPaths.count > 0;
}

- (void)toggleSelection {
    self.selecting = !self.selecting;
    [self.selectedPaths removeAllObjects];
    if (self.selecting) [self installSelectionBarItems];
    else [self installNormalBarItems];
    [self.tableView reloadData];
}

- (void)selectAllItems {
    [self.selectedPaths removeAllObjects];
    for (NSDictionary *item in self.items) [self.selectedPaths addObject:item[@"path"]];
    [self.tableView reloadData];
    [self updateSelectionToolbar];
}

- (void)confirmClearAll {
    if (!self.items.count) return;
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空全部产物？" message:[NSString stringWithFormat:@"将删除本机 %lu 个 deb / dylib 文件，无法恢复。", (unsigned long)self.items.count] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [weakSelf removeItems:weakSelf.items];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteSelectedItems {
    NSArray *items = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return [self.selectedPaths containsObject:item[@"path"]];
    }]];
    if (!items.count) return;
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除所选产物？" message:[NSString stringWithFormat:@"将删除 %lu 个文件，无法恢复。", (unsigned long)items.count] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [weakSelf removeItems:items];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)removeItems:(NSArray<NSDictionary *> *)items {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    for (NSDictionary *item in items) {
        NSError *error = nil;
        if (![NSFileManager.defaultManager removeItemAtPath:item[@"path"] error:&error]) [failures addObject:[NSString stringWithFormat:@"%@：%@", item[@"name"], error.localizedDescription ?: @"删除失败"]];
    }
    [self.selectedPaths removeAllObjects];
    if (self.selecting) {
        self.selecting = NO;
        [self installNormalBarItems];
    }
    [self load];
    if (failures.count) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"部分文件未删除" message:[failures componentsJoinedByString:@"\n"] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DXApplyWindowTheme(self);
    [self load];
}

- (void)load {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *root = DXArtifactRoot();
        NSMutableArray<NSDictionary *> *found = [NSMutableArray array];
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = @"MM-dd HH:mm";
        NSFileManager *fm = NSFileManager.defaultManager;
        // 只遍历「构建产物」下的构建批次目录，再取其内的 deb / dylib。
        // 目录结构固定为 构建产物/<批次>/<产物>，两层浅枚举即可，不递归整个沙盒。
        for (NSString *batch in [fm contentsOfDirectoryAtPath:root error:nil]) {
            if ([batch hasPrefix:@"."]) continue;
            NSString *batchPath = [root stringByAppendingPathComponent:batch];
            BOOL isDirectory = NO;
            if (![fm fileExistsAtPath:batchPath isDirectory:&isDirectory] || !isDirectory) continue;
            for (NSString *name in [fm contentsOfDirectoryAtPath:batchPath error:nil]) {
                NSString *ext = name.pathExtension.lowercaseString;
                if (![ext isEqualToString:@"deb"] && ![ext isEqualToString:@"dylib"]) continue;
                NSString *path = [batchPath stringByAppendingPathComponent:name];
                NSDictionary *attributes = [fm attributesOfItemAtPath:path error:nil];
                NSNumber *size = attributes[NSFileSize];
                if (!size.unsignedLongLongValue) continue;
                NSDate *date = attributes[NSFileModificationDate] ?: NSDate.date;
                [found addObject:@{
                    @"path": path,
                    @"name": name,
                    @"type": ext.uppercaseString,
                    @"date": date,
                    @"detail": [NSString stringWithFormat:@"%@ · %@ · %@", ext.uppercaseString, [NSByteCountFormatter stringFromByteCount:size.longLongValue countStyle:NSByteCountFormatterCountStyleFile], [formatter stringFromDate:date]],
                    @"folder": batch,
                }];
            }
        }
        [found sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [b[@"date"] compare:a[@"date"]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.items = found;
            NSMutableSet<NSString *> *valid = [NSMutableSet set];
            for (NSDictionary *item in found) if ([self.selectedPaths containsObject:item[@"path"]]) [valid addObject:item[@"path"]];
            self.selectedPaths = valid;
            [self.refresh endRefreshing];
            [self.tableView reloadData];
            [self emptyState];
            if (self.selecting) [self updateSelectionToolbar];
        });
    });
}

- (void)emptyState {
    if (self.items.count) { self.tableView.backgroundView = nil; return; }
    UILabel *label = DXText(@"还没有产物\n编译成功后，交付的 deb / dylib 会显示在这里\n构建过程中的临时文件不在此列", [UIFont systemFontOfSize:13], UIColor.secondaryLabelColor);
    label.textAlignment = NSTextAlignmentCenter;
    self.tableView.backgroundView = label;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = item[@"name"];
    content.secondaryText = [NSString stringWithFormat:@"%@ · %@", item[@"detail"], item[@"folder"]];
    content.image = [UIImage systemImageNamed:[item[@"type"] isEqual:@"DEB"] ? @"shippingbox.fill" : @"gearshape.2.fill"];
    content.imageProperties.tintColor = DXAccent();
    content.imageProperties.maximumSize = CGSizeMake(26, 26);
    content.textProperties.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    content.textProperties.numberOfLines = 1;
    content.secondaryTextProperties.font = [UIFont systemFontOfSize:11];
    content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    cell.contentConfiguration = content;
    cell.accessoryType = self.selecting ? ([self.selectedPaths containsObject:item[@"path"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone) : UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"重命名" handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        [weakSelf renameItem:item completion:completion];
    }];
    rename.backgroundColor = DXAccent();
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        [weakSelf deleteItem:item completion:completion];
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove, rename]];
}

- (void)renameItem:(NSDictionary *)item completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名产物" message:item[@"name"] preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = item[@"name"];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.returnKeyType = UIReturnKeyDone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { completion(NO); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *extension = [item[@"type"] lowercaseString];
        if (!name.length || [name containsString:@"/"] || [name isEqual:@"."] || [name isEqual:@".."]) { completion(NO); return; }
        if (!name.pathExtension.length) name = [name stringByAppendingPathExtension:extension];
        NSString *destination = [[item[@"path"] stringByDeletingLastPathComponent] stringByAppendingPathComponent:name];
        NSError *error = nil;
        if ([NSFileManager.defaultManager fileExistsAtPath:destination] || ![NSFileManager.defaultManager moveItemAtPath:item[@"path"] toPath:destination error:&error]) {
            UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"重命名失败" message:error.localizedDescription ?: @"同名文件已存在" preferredStyle:UIAlertControllerStyleAlert];
            [failure addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:failure animated:YES completion:nil];
            completion(NO);
            return;
        }
        [weakSelf load];
        completion(YES);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteItem:(NSDictionary *)item completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    // UIContextualAction 的 completion 必须等用户真的做出选择后再回调一次。
    // 之前这里在弹框刚出现时就同步回调 NO，滑动行立刻回弹，看起来像"删除没生效"。
    __block BOOL finished = NO;
    void (^finish)(BOOL) = ^(BOOL handled) {
        if (finished) return;
        finished = YES;
        if (completion) completion(handled);
    };
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除产物？" message:[NSString stringWithFormat:@"“%@”将从本机删除，无法恢复。", item[@"name"]] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        finish(NO);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error = nil;
        if (![NSFileManager.defaultManager removeItemAtPath:item[@"path"] error:&error]) {
            UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"删除失败" message:error.localizedDescription ?: @"无法删除该文件" preferredStyle:UIAlertControllerStyleAlert];
            [failure addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:failure animated:YES completion:nil];
            finish(NO);
            return;
        }
        [weakSelf load];
        finish(YES);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.items[indexPath.row];
    if (self.selecting) {
        if ([self.selectedPaths containsObject:item[@"path"]]) [self.selectedPaths removeObject:item[@"path"]];
        else [self.selectedPaths addObject:item[@"path"]];
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self updateSelectionToolbar];
        return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:item[@"path"]]] applicationActivities:nil];
    share.popoverPresentationController.sourceView = tableView;
    share.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:share animated:YES completion:nil];
}

@end

#pragma mark - 设置

static NSString *DXRemoteServerLabel(void) {
    NSString *text = DXRemoteBuildServer();
    if (!text.length) return @"未配置";
    if ([text rangeOfString:@"://"].location == NSNotFound) text = [@"https://" stringByAppendingString:text];
    NSString *host = [NSURLComponents componentsWithString:text].host;
    return host.length ? host : text;
}

@interface DXSettingsController : UITableViewController
@end

@implementation DXSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.backgroundColor = DXCanvas();
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 18, 0, 18);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DXApplyWindowTheme(self);
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 3 : section == 1 ? 2 : section == 2 ? 3 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"外观", @"构建", @"工具与存储", @"关于"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"远程构建需手动触发：工程卡片「⋯ → 远程构建」。本机编译失败不会自动切换。";
    return section == 3 ? @"© 2026 AiFlex2" : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = DXCard();
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.section == 0) {
        NSArray *names = @[@"跟随系统", @"浅色", @"深色"];
        NSInteger theme = [NSUserDefaults.standardUserDefaults integerForKey:@"StudioTheme"];
        NSInteger current = theme == 1 ? 2 : theme == 2 ? 1 : 0;
        cell.textLabel.text = names[indexPath.row];
        cell.accessoryType = indexPath.row == current ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.tintColor = DXAccent();
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if (indexPath.section == 1) {
        cell.textLabel.text = indexPath.row == 0 ? @"远程构建" : @"构建默认设置";
        if (indexPath.row == 0) cell.detailTextLabel.text = DXRemoteServerLabel();
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @[@"存储空间", @"安装工具", @"插件与 MCP"][indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text = indexPath.row == 0 ? @"关于 AiFlex2" : @"版本";
        if (indexPath.row == 0) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        else cell.detailTextLabel.text = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.1.0";
        cell.selectionStyle = indexPath.row == 0 ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        NSArray<NSNumber *> *values = @[@0, @2, @1];
        [NSUserDefaults.standardUserDefaults setInteger:values[indexPath.row].integerValue forKey:@"StudioTheme"];
        DXApplyWindowTheme(self);
        if (self.tabBarController) self.tabBarController.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle;
        [tableView reloadData];
        return;
    }
    if (indexPath.section == 1) {
        if (indexPath.row == 0) [self.navigationController pushViewController:DXRemoteBuildSettingsController() animated:YES];
        else [self.navigationController pushViewController:TMCStudioBuildPreferencesController() animated:YES];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) [self.navigationController pushViewController:TMCStorageController() animated:YES];
        else if (indexPath.row == 1) [self.navigationController pushViewController:TFAIISHToolsController(nil) animated:YES];
        else [self.navigationController pushViewController:DXFlexPluginInfoController() animated:YES];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        [self.navigationController pushViewController:TMCStudioAboutController() animated:YES];
    }
}

@end

#pragma mark - 外壳

@interface DXShellTabs : UITabBarController
@end

@implementation DXShellTabs

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tabBar.tintColor = DXAccent();
    UITabBarAppearance *appearance = [UITabBarAppearance new];
    [appearance configureWithDefaultBackground];
    appearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    self.tabBar.standardAppearance = appearance;
    self.tabBar.scrollEdgeAppearance = appearance;
    self.view.backgroundColor = DXCanvas();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    DXApplyWindowTheme(self);
}

@end

static UINavigationController *DXNavigation(UIViewController *root, NSString *title, NSString *symbol) {
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    navigation.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:[UIImage systemImageNamed:symbol] tag:0];
    navigation.view.backgroundColor = DXCanvas();
    return navigation;
}

UIViewController *DXShellRoot(void) {
    DXShellTabs *tabs = [DXShellTabs new];
    DXWorkbenchController *workbench = [DXWorkbenchController new];
    DXAIHubController *ai = [DXAIHubController new];
    DXArtifactsController *artifacts = [[DXArtifactsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    DXSettingsController *settings = [[DXSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    tabs.viewControllers = @[
        DXNavigation(workbench, @"工作台", @"square.grid.2x2"),
        DXNavigation(ai, @"AI", @"sparkles"),
        DXNavigation(artifacts, @"产物", @"shippingbox"),
        DXNavigation(settings, @"设置", @"gearshape"),
    ];
    return tabs;
}
