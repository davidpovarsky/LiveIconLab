#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const LiveIconLabBundleID = @"com.goldcreative.liveiconlab";

@interface LiveIconLabAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@interface LiveIconLabViewController : UIViewController
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic) NSInteger nextFrame;
@end

@implementation LiveIconLabViewController

- (void)setStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = status;
    });
}

- (NSDictionary *)ipadIconsDictionary {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSDictionary *icons = info[@"CFBundleIcons~ipad"];
    return [icons isKindOfClass:[NSDictionary class]] ? icons : nil;
}

- (id)iconServiceProxyWithErrorHandler:(void (^)(NSError *error))errorHandler {
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices",
           RTLD_NOW | RTLD_LOCAL);

    Class serviceClass = NSClassFromString(@"_LSDIconService");
    SEL proxySelector = NSSelectorFromString(@"XPCProxyWithErrorHandler:");

    if (serviceClass == Nil || ![serviceClass respondsToSelector:proxySelector]) {
        return nil;
    }

    return ((id (*)(id, SEL, id))objc_msgSend)(
        serviceClass,
        proxySelector,
        errorHandler
    );
}

- (void)testDirectLSDPath {
    NSDictionary *iconsDictionary = [self ipadIconsDictionary];
    if (!iconsDictionary) {
        [self setStatus:@"FAILED: CFBundleIcons~ipad dictionary missing."];
        return;
    }

    NSString *iconName = [NSString stringWithFormat:@"ClockFrame%02ld",
                          (long)self.nextFrame];
    self.nextFrame = (self.nextFrame + 1) % 12;

    __weak typeof(self) weakSelf = self;
    id proxy = [self iconServiceProxyWithErrorHandler:^(NSError *error) {
        [weakSelf setStatus:[NSString stringWithFormat:
            @"XPC proxy error:\n%@",
            error ?: @"unknown error"]];
    }];

    if (!proxy) {
        [self setStatus:@"FAILED: _LSDIconService XPC proxy unavailable."];
        return;
    }

    SEL selector =
        NSSelectorFromString(@"setAlternateIconName:forIdentifier:iconsDictionary:reply:");

    if (![proxy respondsToSelector:selector]) {
        [self setStatus:@"FAILED: direct LSD icon selector unavailable on this build."];
        return;
    }

    [self setStatus:[NSString stringWithFormat:
        @"Calling direct _LSDIconService once: %@\n"
         "This bypasses UIApplication/LSApplicationProxy. Watch for a SYSTEM alert.",
        iconName]];

    void (^reply)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        if (!success || error) {
            [weakSelf setStatus:[NSString stringWithFormat:
                @"Direct LSD call failed.\nSuccess: %@\nError: %@",
                success ? @"YES" : @"NO",
                error ?: @"(none)"]];
        } else {
            [weakSelf setStatus:[NSString stringWithFormat:
                @"SUCCESS: %@ changed via direct LSD service.\n"
                 "If no SYSTEM alert appeared, we found the real no-alert path.",
                iconName]];
        }
    };

    ((void (*)(id, SEL, NSString *, NSString *, NSDictionary *, id))objc_msgSend)(
        proxy,
        selector,
        iconName,
        LiveIconLabBundleID,
        iconsDictionary,
        reply
    );
}

- (void)resetDirectLSDPath {
    NSDictionary *iconsDictionary = [self ipadIconsDictionary];
    if (!iconsDictionary) {
        [self setStatus:@"FAILED: CFBundleIcons~ipad dictionary missing."];
        return;
    }

    __weak typeof(self) weakSelf = self;
    id proxy = [self iconServiceProxyWithErrorHandler:^(NSError *error) {
        [weakSelf setStatus:[NSString stringWithFormat:@"XPC proxy error: %@", error]];
    }];

    SEL selector =
        NSSelectorFromString(@"setAlternateIconName:forIdentifier:iconsDictionary:reply:");

    if (!proxy || ![proxy respondsToSelector:selector]) {
        [self setStatus:@"Direct LSD path unavailable."];
        return;
    }

    void (^reply)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        [weakSelf setStatus:[NSString stringWithFormat:
            @"Reset result: %@%@",
            success ? @"SUCCESS" : @"FAILED",
            error ? [NSString stringWithFormat:@"\n%@", error] : @""]];
    };

    ((void (*)(id, SEL, NSString *, NSString *, NSDictionary *, id))objc_msgSend)(
        proxy,
        selector,
        nil,
        LiveIconLabBundleID,
        iconsDictionary,
        reply
    );
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action filled:(BOOL)filled {
    UIButtonConfiguration *configuration =
        filled ? [UIButtonConfiguration filledButtonConfiguration]
               : [UIButtonConfiguration borderedButtonConfiguration];
    configuration.title = title;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;

    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.nextFrame = 2;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"LiveIconLab";
    title.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *detail = [[UILabel alloc] init];
    detail.text = [NSString stringWithFormat:
        @"iPadOS 27 direct LaunchServices XPC probe\nBundle ID: %@\n\n"
         "This build does NOT call UIApplication.setAlternateIconName and does NOT "
         "call LSApplicationProxy. It talks directly to _LSDIconService using the "
         "generic setAlternateIconName:forIdentifier:iconsDictionary:reply: route.",
         LiveIconLabBundleID];
    detail.font = [UIFont systemFontOfSize:17.0];
    detail.numberOfLines = 0;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.textColor = UIColor.secondaryLabelColor;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices",
           RTLD_NOW | RTLD_LOCAL);
    Class serviceClass = NSClassFromString(@"_LSDIconService");
    SEL proxySelector = NSSelectorFromString(@"XPCProxyWithErrorHandler:");
    self.statusLabel.text =
        (serviceClass && [serviceClass respondsToSelector:proxySelector])
        ? @"_LSDIconService FOUND. Ready for one direct XPC test."
        : @"_LSDIconService direct proxy route NOT FOUND.";

    UIButton *test = [self buttonWithTitle:@"Test direct no-alert LSD change"
                                    action:@selector(testDirectLSDPath)
                                    filled:YES];

    UIButton *reset = [self buttonWithTitle:@"Reset through direct LSD"
                                     action:@selector(resetDirectLSDPath)
                                     filled:NO];

    UIStackView *buttons =
        [[UIStackView alloc] initWithArrangedSubviews:@[test, reset]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 12.0;

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:
            @[title, detail, self.statusLabel, buttons]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 24.0;

    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:760]
    ]];
}

@end

@implementation LiveIconLabAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[LiveIconLabViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([LiveIconLabAppDelegate class]));
    }
}
