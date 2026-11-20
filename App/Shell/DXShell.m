#import "DXShell.h"
#import "../Studio.h"
#import "../StorageSpace.h"
#import "../AI/AIV2Contracts.h"
#import "../AI/AIContracts.h"
#import "../AI/UI/TFAIPersonaUI.h"
#import "../AI/Agent/TFAIBuildQueue.h"
#import "../Remote/DXFlexPluginInfo.h"

@class DXEnvironmentController;
static UIViewController *DXEnvironmentPage(void);

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
@property(nonatomic,strong) UILabel *countLabel;
@end

@implementation DXWorkbenchController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DXCanvas();
    self.title = @"工作台";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

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
    [self reload];
}

- (void)reload {
    NSArray<NSDictionary *> *projects = TFAIInternalProjects();
    self.countLabel.text = [NSString stringWithFormat:@"%lu 个", (unsigned long)projects.count];
    self.storageLabel.text = DXFreeSpace();
    NSUInteger tasks = TFAIBuildQueue.shared.tasks.count;
    self.queueLabel.text = tasks ? [NSString stringWithFormat:@"%lu 个", (unsigned long)tasks] : @"空闲";

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
    return card;
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
    [rows addArrangedSubview:DXMenuRow(@"新会话", @"创建一场空白对话", @"bubble.left.and.text.bubble.right", ^{
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
    [rows addArrangedSubview:DXMenuRow(@"MCP 连接", @"导入 AiFlex2 服务地址与令牌", @"network", ^{
        [weak.navigationController pushViewController:DXFlexPluginInfoController() animated:YES];
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

#pragma mark - 构建

@interface DXBuildCenterController : UIViewController
@property(nonatomic,strong) UILabel *stateLabel;
@property(nonatomic,strong) UILabel *detailLabel;
@property(nonatomic,strong) UIStackView *projectStack;
@end

@implementation DXBuildCenterController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DXCanvas();
    self.title = @"构建";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    UIStackView *stack = DXScrollStack(self, NULL);
    UIView *hero = DXSurface();
    UIStackView *heroStack = [UIStackView new];
    heroStack.translatesAutoresizingMaskIntoConstraints = NO;
    heroStack.axis = UILayoutConstraintAxisVertical;
    heroStack.spacing = 6;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"hammer"]];
    icon.tintColor = DXAccent();
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon.heightAnchor constraintEqualToConstant:24].active = YES;
    [heroStack addArrangedSubview:icon];
    self.stateLabel = DXText(@"队列空闲", [UIFont systemFontOfSize:20 weight:UIFontWeightBold], UIColor.labelColor);
    [heroStack addArrangedSubview:self.stateLabel];
    self.detailLabel = DXText(@"选择工程开始本机编译，产物输出到工程目录。", [UIFont systemFontOfSize:12], UIColor.secondaryLabelColor);
    [heroStack addArrangedSubview:self.detailLabel];
    UIButton *queueButton = DXGhostButton(@"打开构建队列", @"list.bullet.rectangle", ^{
        [self.navigationController pushViewController:TFAIBuildQueueController() animated:YES];
    });
    [heroStack addArrangedSubview:queueButton];
    [heroStack setCustomSpacing:12 afterView:self.detailLabel];
    [hero addSubview:heroStack];
    [NSLayoutConstraint activateConstraints:@[
        [heroStack.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:18],
        [heroStack.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-18],
        [heroStack.topAnchor constraintEqualToAnchor:hero.topAnchor constant:20],
        [heroStack.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-20],
    ]];
    [stack addArrangedSubview:hero];

    UILabel *section = DXText(@"选择工程", [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold], UIColor.labelColor);
    [stack addArrangedSubview:section];
    [stack setCustomSpacing:12 afterView:section];
    self.projectStack = [UIStackView new];
    self.projectStack.axis = UILayoutConstraintAxisVertical;
    self.projectStack.spacing = 10;
    [stack addArrangedSubview:self.projectStack];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DXApplyWindowTheme(self);
    NSUInteger tasks = TFAIBuildQueue.shared.tasks.count;
    self.stateLabel.text = tasks ? [NSString stringWithFormat:@"%lu 个任务进行中", (unsigned long)tasks] : @"队列空闲";
    self.detailLabel.text = tasks ? @"可打开构建队列查看进度或取消任务。" : @"选择工程开始本机编译，产物输出到工程目录。";

    for (UIView *view in self.projectStack.arrangedSubviews.copy) {
        [self.projectStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    for (NSDictionary *project in TFAIInternalProjects()) {
        [self.projectStack addArrangedSubview:[self rowForProject:project]];
    }
    if (!self.projectStack.arrangedSubviews.count) {
        UIView *card = DXSurface();
        UILabel *label = DXText(@"还没有可编译的工程", [UIFont systemFontOfSize:13], UIColor.secondaryLabelColor);
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
            [label.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
            [label.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
            [label.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
        ]];
        [self.projectStack addArrangedSubview:card];
    }
}

- (UIView *)rowForProject:(NSDictionary *)project {
    NSString *root = project[@"root"];
    UIView *card = DXSurface();
    UILabel *name = DXText(project[@"name"] ?: root.lastPathComponent, [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold], UIColor.labelColor);
    name.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *detail = DXText(DXControlValue(root, @"Package") ?: @"未设置包标识", [UIFont systemFontOfSize:11], UIColor.secondaryLabelColor);
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *build = DXPrimaryButton(@"编译", @"hammer", ^{
        TMCStudioResumeBuild(root, self.navigationController);
    });
    build.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:name];
    [card addSubview:detail];
    [card addSubview:build];
    [NSLayoutConstraint activateConstraints:@[
        [name.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [name.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [name.trailingAnchor constraintLessThanOrEqualToAnchor:build.leadingAnchor constant:-12],
        [detail.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [detail.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2],
        [detail.trailingAnchor constraintLessThanOrEqualToAnchor:build.leadingAnchor constant:-12],
        [detail.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [build.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [build.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];
    return card;
}

@end

#pragma mark - 设置

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
    return section == 0 ? 3 : section == 1 ? 1 : section == 2 ? 3 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"外观", @"构建", @"工具与存储", @"关于"][section];
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
        cell.textLabel.text = @"构建默认设置";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @[@"存储空间", @"编译环境", @"插件与 MCP"][indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text = indexPath.row == 0 ? @"关于 AiFlex2" : @"版本";
        if (indexPath.row == 0) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        else cell.detailTextLabel.text = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0.0";
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
        [self.navigationController pushViewController:TMCStudioBuildPreferencesController() animated:YES];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) [self.navigationController pushViewController:TMCStorageController() animated:YES];
        else if (indexPath.row == 1) [self.navigationController pushViewController:DXEnvironmentPage() animated:YES];
        else [self.navigationController pushViewController:DXFlexPluginInfoController() animated:YES];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        [self.navigationController pushViewController:TMCStudioAboutController() animated:YES];
    }
}

@end

#pragma mark - 编译环境

static unsigned long long DXPathSize(NSString *path) {
    BOOL directory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&directory]) return 0;
    if (!directory) {
        return [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
    }
    unsigned long long total = 0;
    for (NSString *entry in [NSFileManager.defaultManager enumeratorAtPath:path]) {
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:[path stringByAppendingPathComponent:entry] error:nil];
        total += [attributes[NSFileSize] unsignedLongLongValue];
    }
    return total;
}

static NSString *DXBytes(unsigned long long bytes) {
    return [NSByteCountFormatter stringFromByteCount:(long long)bytes countStyle:NSByteCountFormatterCountStyleFile];
}

static NSDictionary *DXEnvRow(NSString *title, NSString *detail, BOOL ok, NSString *symbol) {
    return @{@"title": title, @"detail": detail, @"ok": @(ok), @"symbol": symbol};
}

@interface DXEnvironmentController : UITableViewController
@property(nonatomic,strong) NSArray<NSArray<NSDictionary *> *> *groups;
@end

@implementation DXEnvironmentController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"编译环境";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.backgroundColor = DXCanvas();
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 18, 0, 18);

    NSString *bundle = NSBundle.mainBundle.bundlePath;
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath ?: [bundle stringByAppendingPathComponent:@"Frameworks"];

    NSMutableArray *tools = [NSMutableArray array];
    NSDictionary *symbols = @{@"clang": @"chevron.left.forwardslash.chevron.right", @"lld": @"link", @"libLLVM": @"cube", @"ios_system": @"terminal", @"perl": @"curlybraces"};
    for (NSString *name in @[@"clang", @"lld", @"libLLVM", @"ios_system", @"perl"]) {
        NSString *dir = [frameworks stringByAppendingPathComponent:[name stringByAppendingString:@".framework"]];
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:dir];
        NSDictionary *info = exists ? [NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:@"Info.plist"]] : nil;
        NSString *version = info[@"CFBundleShortVersionString"];
        NSString *detail = exists
            ? [NSString stringWithFormat:@"%@ · %@", version.length ? version : @"已安装", DXBytes(DXPathSize(dir))]
            : @"缺失，需重新安装完整 IPA";
        [tools addObject:DXEnvRow(name, detail, exists, symbols[name])];
    }
    NSString *perlPath = [bundle stringByAppendingPathComponent:@"Perl"];
    BOOL perlModules = [NSFileManager.defaultManager fileExistsAtPath:perlPath];
    NSString *perlDetail = perlModules ? [NSString stringWithFormat:@"已安装 · %@", DXBytes(DXPathSize(perlPath))] : @"缺失";
    [tools addObject:DXEnvRow(@"Perl 模块", perlDetail, perlModules, @"shippingbox")];

    NSDictionary *sdkInfo = [NSDictionary dictionaryWithContentsOfFile:[bundle stringByAppendingPathComponent:@"SDKResource.plist"]];
    NSString *sdkVersion = [sdkInfo[@"version"] isKindOfClass:NSString.class] ? sdkInfo[@"version"] : @"16.4";
    NSString *sdkZip = [bundle stringByAppendingPathComponent:@"SDK.zip"];
    BOOL sdk = [NSFileManager.defaultManager fileExistsAtPath:sdkZip];
    NSString *includes = [bundle stringByAppendingPathComponent:@"ClangInclude"];
    BOOL headers = [NSFileManager.defaultManager fileExistsAtPath:includes];
    BOOL sdk26 = [NSFileManager.defaultManager fileExistsAtPath:[bundle stringByAppendingPathComponent:@"SDK26.zip"]];
    NSArray *sdkRows = @[
        DXEnvRow([NSString stringWithFormat:@"iOS %@ SDK", sdkVersion], sdk ? [NSString stringWithFormat:@"SDK.zip · %@", DXBytes(DXPathSize(sdkZip))] : @"缺失，编译将无法进行", sdk, @"shippingbox"),
        DXEnvRow(@"Clang 头文件", headers ? [NSString stringWithFormat:@"ClangInclude · %@", DXBytes(DXPathSize(includes))] : @"缺失", headers, @"folder"),
        DXEnvRow(@"iOS 26.0 SDK", sdk26 ? [NSString stringWithFormat:@"已内置 · %@", DXBytes(DXPathSize([bundle stringByAppendingPathComponent:@"SDK26.zip"]))] : @"可选，未内置；默认使用 16.4", YES, @"shippingbox"),
    ];

    BOOL logos = [NSFileManager.defaultManager fileExistsAtPath:[bundle stringByAppendingPathComponent:@"logos"]];
    BOOL devKit = [NSFileManager.defaultManager fileExistsAtPath:[bundle stringByAppendingPathComponent:@"iSH/developer-tools.json"]];
    BOOL reverseKit = [NSFileManager.defaultManager fileExistsAtPath:[bundle stringByAppendingPathComponent:@"iSH/reverse-tools.json"]];
    BOOL plugin = [NSFileManager.defaultManager fileExistsAtPath:[bundle stringByAppendingPathComponent:@"FLEXPlugin/manifest.json"]];
    NSArray *devRows = @[
        DXEnvRow(@"Logos 预处理器", logos ? @"已安装" : @"缺失，.xm 无法编译", logos, @"text.badge.checkmark"),
        DXEnvRow(@"离线开发工具包", devKit ? @"已内置（iSH developer-tools）" : @"未内置", devKit, @"wrench.and.screwdriver"),
        DXEnvRow(@"逆向分析工具包", reverseKit ? @"已内置（iShare reverse-tools）" : @"未内置", reverseKit, @"binoculars"),
        DXEnvRow(@"AiFlex2 安装包", plugin ? @"已内置" : @"未内置，由独立仓库维护", YES, @"puzzlepiece.extension"),
    ];
    self.groups = @[tools, sdkRows, devRows];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.groups.count; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.groups[section].count; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"编译器与运行时", @"iOS SDK", @"开发工具与插件"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != self.groups.count - 1) return nil;
    return @"编译失败时先确认以上项目均为已安装，并检查工程 MobileCompiler.json 与源码路径。缺少工具请重新安装完整 IPA。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.groups[indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = DXCard();
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = row[@"detail"];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.numberOfLines = 0;
    BOOL ok = [row[@"ok"] boolValue];
    cell.detailTextLabel.textColor = ok ? UIColor.secondaryLabelColor : UIColor.systemRedColor;
    cell.imageView.image = [UIImage systemImageNamed:row[@"symbol"]];
    cell.imageView.tintColor = ok ? DXAccent() : UIColor.systemRedColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end

static UIViewController *DXEnvironmentPage(void) { return [DXEnvironmentController new]; }

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
    DXBuildCenterController *builds = [DXBuildCenterController new];
    DXSettingsController *settings = [[DXSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    tabs.viewControllers = @[
        DXNavigation(workbench, @"工作台", @"square.grid.2x2"),
        DXNavigation(ai, @"AI", @"sparkles"),
        DXNavigation(builds, @"构建", @"hammer"),
        DXNavigation(settings, @"设置", @"gearshape"),
    ];
    return tabs;
}
