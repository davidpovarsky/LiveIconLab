#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const LiveIconLabBundleID = @"com.goldcreative.liveiconlab";
static NSString * const LiveIconLabStatusNotification = @"LiveIconLabStatusNotification";

@interface LiveIconAnimator : NSObject
@property (nonatomic, strong) id applicationProxy;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) NSInteger frame;
@property (nonatomic) NSInteger ticksRemaining;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic, weak) UIApplication *application;
- (BOOL)isPrivateAPIAvailable;
- (void)startWithApplication:(UIApplication *)application;
- (void)resetToPrimaryIcon;
@end

@implementation LiveIconAnimator

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundTask = UIBackgroundTaskInvalid;

        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices",
               RTLD_NOW | RTLD_LOCAL);

        Class bundleProxyClass = NSClassFromString(@"LSBundleProxy");
        SEL currentProcessSelector = NSSelectorFromString(@"bundleProxyForCurrentProcess");

        if (bundleProxyClass != Nil &&
            [bundleProxyClass respondsToSelector:currentProcessSelector]) {
            self.applicationProxy =
                ((id (*)(id, SEL))objc_msgSend)(bundleProxyClass, currentProcessSelector);
        }
    }
    return self;
}

- (BOOL)isPrivateAPIAvailable {
    SEL selector = NSSelectorFromString(@"setAlternateIconName:withResult:");
    return self.applicationProxy != nil &&
           [self.applicationProxy respondsToSelector:selector];
}

- (void)postStatus:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:LiveIconLabStatusNotification
                          object:message];
    });
}

- (void)setAlternateIconName:(NSString *)name {
    if (![self isPrivateAPIAvailable]) {
        [self postStatus:@"Private LaunchServices API is not available on this build."];
        return;
    }

    SEL selector = NSSelectorFromString(@"setAlternateIconName:withResult:");

    void (^completion)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        if (!success || error != nil) {
            NSString *message = [NSString stringWithFormat:
                @"Icon update failed: %@",
                error.localizedDescription ?: @"unknown error"];
            [self postStatus:message];
        }
    };

    ((void (*)(id, SEL, NSString *, void (^)(BOOL, NSError *)))objc_msgSend)(
        self.applicationProxy,
        selector,
        name,
        completion
    );
}

- (void)finish {
    [self.timer invalidate];
    self.timer = nil;

    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [self.application endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }

    [self postStatus:@"Animation test finished. Tap Arm and go Home to run it again."];
}

- (void)tick:(NSTimer *)timer {
    (void)timer;

    NSString *iconName = [NSString stringWithFormat:@"ClockFrame%02ld",
                          (long)self.frame];
    [self setAlternateIconName:iconName];

    self.frame = (self.frame + 1) % 12;
    self.ticksRemaining -= 1;

    if (self.ticksRemaining <= 0) {
        [self finish];
    }
}

- (void)startWithApplication:(UIApplication *)application {
    if (![self isPrivateAPIAvailable]) {
        [self postStatus:@"Cannot start: LSApplicationProxy alternate-icon API was not found."];
        return;
    }

    [self.timer invalidate];
    self.timer = nil;

    self.application = application;
    self.frame = 0;
    self.ticksRemaining = 72; // 12 seconds at 6 fps.

    __weak typeof(self) weakSelf = self;
    self.backgroundTask =
        [application beginBackgroundTaskWithName:@"LiveIconAnimationProbe"
                               expirationHandler:^{
        [weakSelf finish];
    }];

    [self postStatus:@"Running 12-frame private icon animation at 6 fps..."];

    self.timer = [NSTimer timerWithTimeInterval:(1.0 / 6.0)
                                         target:self
                                       selector:@selector(tick:)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];

    // Show frame zero immediately instead of waiting for the first timer tick.
    [self tick:self.timer];
}

- (void)resetToPrimaryIcon {
    [self.timer invalidate];
    self.timer = nil;
    [self setAlternateIconName:nil];
    [self postStatus:@"Requested primary icon."];
}

@end

@interface LiveIconLabAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) LiveIconAnimator *animator;
@property (nonatomic) BOOL animationArmed;
- (void)armAnimation;
- (void)resetIcon;
@end

@interface LiveIconLabViewController : UIViewController
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation LiveIconLabViewController

- (LiveIconLabAppDelegate *)appDelegate {
    return (LiveIconLabAppDelegate *)UIApplication.sharedApplication.delegate;
}

- (void)statusChanged:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[NSString class]]) {
        self.statusLabel.text = notification.object;
    }
}

- (void)armPressed {
    [[self appDelegate] armAnimation];
    self.statusLabel.text =
        @"ARMED. Now swipe Home. The animation starts when LiveIconLab enters the background.";
}

- (void)resetPressed {
    [[self appDelegate] resetIcon];
}

- (UIButton *)buttonWithTitle:(NSString *)title
                      action:(SEL)action
                       filled:(BOOL)filled {
    UIButtonConfiguration *configuration =
        filled ? [UIButtonConfiguration filledButtonConfiguration]
               : [UIButtonConfiguration borderedButtonConfiguration];
    configuration.title = title;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;

    UIButton *button = [UIButton buttonWithConfiguration:configuration
                                           primaryAction:nil];
    [button addTarget:self
               action:action
     forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"LiveIconLab";
    title.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *detail = [[UILabel alloc] init];
    detail.text = [NSString stringWithFormat:
        @"iPadOS 27 private icon-animation probe\nBundle ID: %@\n\n"
         "This test does not use the SpringBoard dylib. It asks LaunchServices "
         "to switch among 12 bundled clock frames while the app has short "
         "background execution time.",
         LiveIconLabBundleID];
    detail.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    detail.numberOfLines = 0;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.textColor = [UIColor secondaryLabelColor];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    LiveIconAnimator *animator = [self appDelegate].animator;
    self.statusLabel.text = animator.isPrivateAPIAvailable
        ? @"Private LSApplicationProxy API found. Ready."
        : @"Private LSApplicationProxy API was not found on this build.";

    UIButton *armButton = [self buttonWithTitle:@"Arm animation test"
                                         action:@selector(armPressed)
                                         filled:YES];
    UIButton *resetButton = [self buttonWithTitle:@"Reset to primary icon"
                                           action:@selector(resetPressed)
                                           filled:NO];

    UIStackView *buttons =
        [[UIStackView alloc] initWithArrangedSubviews:@[armButton, resetButton]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 12.0;

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:
            @[title, detail, self.statusLabel, buttons]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 24.0;
    stack.alignment = UIStackViewAlignmentFill;

    [self.view addSubview:stack];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(statusChanged:)
               name:LiveIconLabStatusNotification
             object:nil];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor
                                                         constant:40.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor
                                                        constant:-40.0],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:680.0]
    ]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation LiveIconLabAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.animator = [[LiveIconAnimator alloc] init];
    self.animationArmed = NO;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    LiveIconLabViewController *controller = [[LiveIconLabViewController alloc] init];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)armAnimation {
    self.animationArmed = YES;
}

- (void)resetIcon {
    self.animationArmed = NO;
    [self.animator resetToPrimaryIcon];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (self.animationArmed) {
        self.animationArmed = NO;
        [self.animator startWithApplication:application];
    }
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc,
                                 argv,
                                 nil,
                                 NSStringFromClass([LiveIconLabAppDelegate class]));
    }
}
