#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
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

- (BOOL)privateNoAlertSelectorAvailable {
    SEL selector = NSSelectorFromString(@"_setAlternateIconName:completionHandler:");
    return [UIApplication.sharedApplication respondsToSelector:selector];
}

- (void)testNoAlertPath {
    SEL selector = NSSelectorFromString(@"_setAlternateIconName:completionHandler:");
    UIApplication *application = UIApplication.sharedApplication;

    if (![application respondsToSelector:selector]) {
        [self setStatus:@"FAILED: _setAlternateIconName:completionHandler: is not present on this iPadOS build."];
        return;
    }

    NSString *iconName = [NSString stringWithFormat:@"ClockFrame%02ld", (long)self.nextFrame];
    self.nextFrame = (self.nextFrame + 1) % 12;

    [self setStatus:[NSString stringWithFormat:
        @"Calling private UIKit path once: %@\nWatch whether a SYSTEM alert appears.",
        iconName]];

    IMP imp = [application methodForSelector:selector];
    typedef void (*SetAlternateIconIMP)(id, SEL, NSString *, void (^)(NSError *));
    SetAlternateIconIMP function = (SetAlternateIconIMP)imp;

    function(application, selector, iconName, ^(NSError *error) {
        if (error) {
            [self setStatus:[NSString stringWithFormat:
                @"Private UIKit call returned error:\n%@",
                error]];
        } else {
            [self setStatus:[NSString stringWithFormat:
                @"SUCCESS: %@ applied through _setAlternateIconName:.\n"
                 "Did a SYSTEM alert appear? If not, this is our no-alert route.",
                iconName]];
        }
    });
}

- (void)resetPrimary {
    SEL selector = NSSelectorFromString(@"_setAlternateIconName:completionHandler:");
    UIApplication *application = UIApplication.sharedApplication;

    if (![application respondsToSelector:selector]) {
        [self setStatus:@"Private UIKit selector unavailable; cannot reset through this test path."];
        return;
    }

    IMP imp = [application methodForSelector:selector];
    typedef void (*SetAlternateIconIMP)(id, SEL, NSString *, void (^)(NSError *));
    SetAlternateIconIMP function = (SetAlternateIconIMP)imp;

    function(application, selector, nil, ^(NSError *error) {
        if (error) {
            [self setStatus:[NSString stringWithFormat:@"Reset error: %@", error]];
        } else {
            [self setStatus:@"Primary icon requested through private UIKit path."];
        }
    });
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

    self.nextFrame = 1;
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"LiveIconLab";
    title.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *detail = [[UILabel alloc] init];
    detail.text = [NSString stringWithFormat:
        @"iPadOS 27 no-alert icon probe\nBundle ID: %@\n\n"
         "This build performs ONE icon change per tap using UIKit's private "
         "_setAlternateIconName:completionHandler: selector. It does not use "
         "LSApplicationProxy directly and does not animate automatically.",
         LiveIconLabBundleID];
    detail.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    detail.numberOfLines = 0;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.textColor = [UIColor secondaryLabelColor];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = [self privateNoAlertSelectorAvailable]
        ? @"Private UIKit selector FOUND. Ready for one controlled test."
        : @"Private UIKit selector NOT FOUND on this build.";

    UIButton *test = [self buttonWithTitle:@"Test one no-alert icon change"
                                    action:@selector(testNoAlertPath)
                                    filled:YES];
    UIButton *reset = [self buttonWithTitle:@"Reset to primary icon"
                                     action:@selector(resetPrimary)
                                     filled:NO];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[test, reset]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 12.0;

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:@[title, detail, self.statusLabel, buttons]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 24.0;
    stack.alignment = UIStackViewAlignmentFill;

    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40.0],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:720.0]
    ]];
}

@end

@implementation LiveIconLabAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[LiveIconLabViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([LiveIconLabAppDelegate class]));
    }
}
