#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString * const SpringBoardHomePath =
    @"/System/Library/PrivateFrameworks/SpringBoardHome.framework/SpringBoardHome";

@interface LiveIconLabAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@interface LiveIconLabViewController : UIViewController
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *previewHost;
@end

@implementation LiveIconLabViewController

- (void)setStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = status;
    });
}

- (NSString *)yesNo:(BOOL)value {
    return value ? @"YES" : @"NO";
}

- (void)runRuntimeProbe {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    dlerror();
    void *handle = dlopen(SpringBoardHomePath.UTF8String, RTLD_NOW | RTLD_LOCAL);
    const char *error = dlerror();

    [lines addObject:[NSString stringWithFormat:
        @"dlopen SpringBoardHome: %@",
        handle ? @"SUCCESS" : @"FAILED"]];

    if (!handle) {
        [lines addObject:[NSString stringWithFormat:
            @"dlerror: %s",
            error ?: "(none)"]];
        [self setStatus:[lines componentsJoinedByString:@"\n"]];
        return;
    }

    NSArray<NSString *> *names = @[
        @"SBLiveIconImageView",
        @"SBHClockApplicationIconImageView",
        @"SBHClockApplicationIcon",
        @"SBHApplicationIcon",
        @"SBHIconModel"
    ];

    NSMutableDictionary<NSString *, id> *classes = [NSMutableDictionary dictionary];

    for (NSString *name in names) {
        Class cls = NSClassFromString(name);
        if (cls) {
            classes[name] = cls;
        }
        [lines addObject:[NSString stringWithFormat:
            @"%@: %@",
            name,
            cls ? @"FOUND" : @"NOT FOUND"]];
    }

    Class clockViewClass = classes[@"SBHClockApplicationIconImageView"];
    if (!clockViewClass) {
        [lines addObject:@"Clock live-image class is not visible in this process."];
        [self setStatus:[lines componentsJoinedByString:@"\n"]];
        return;
    }

    BOOL isUIViewSubclass = [clockViewClass isSubclassOfClass:[UIView class]];
    [lines addObject:[NSString stringWithFormat:
        @"Clock image view is UIView subclass: %@",
        [self yesNo:isUIViewSubclass]]];

    if (!isUIViewSubclass) {
        [self setStatus:[lines componentsJoinedByString:@"\n"]];
        return;
    }

    @try {
        CGRect frame = CGRectMake(0, 0, 180, 180);
        id instance = nil;

        SEL initWithFrame = @selector(initWithFrame:);
        if ([clockViewClass instancesRespondToSelector:initWithFrame]) {
            id allocated = ((id (*)(id, SEL))objc_msgSend)(clockViewClass, @selector(alloc));
            instance = ((id (*)(id, SEL, CGRect))objc_msgSend)(
                allocated, initWithFrame, frame);
            [lines addObject:@"initWithFrame: returned an object."];
        } else {
            id allocated = ((id (*)(id, SEL))objc_msgSend)(clockViewClass, @selector(alloc));
            instance = ((id (*)(id, SEL))objc_msgSend)(allocated, @selector(init));
            [lines addObject:@"init returned an object."];
        }

        if (!instance) {
            [lines addObject:@"Instantiation returned nil."];
            [self setStatus:[lines componentsJoinedByString:@"\n"]];
            return;
        }

        UIView *clockView = (UIView *)instance;
        clockView.frame = frame;
        clockView.translatesAutoresizingMaskIntoConstraints = NO;

        [self.previewHost.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self.previewHost addSubview:clockView];

        [NSLayoutConstraint activateConstraints:@[
            [clockView.centerXAnchor constraintEqualToAnchor:self.previewHost.centerXAnchor],
            [clockView.centerYAnchor constraintEqualToAnchor:self.previewHost.centerYAnchor],
            [clockView.widthAnchor constraintEqualToConstant:180.0],
            [clockView.heightAnchor constraintEqualToConstant:180.0]
        ]];

        SEL pausedSelector = NSSelectorFromString(@"setPaused:");
        if ([clockView respondsToSelector:pausedSelector]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(clockView, pausedSelector, NO);
            [lines addObject:@"setPaused:NO sent."];
        } else {
            [lines addObject:@"setPaused: not available."];
        }

        SEL updateSelector = NSSelectorFromString(@"updateOngoingAnimationState");
        if ([clockView respondsToSelector:updateSelector]) {
            ((void (*)(id, SEL))objc_msgSend)(clockView, updateSelector);
            [lines addObject:@"updateOngoingAnimationState sent."];
        }

        SEL allowedSelector = NSSelectorFromString(@"areOngoingAnimationsAllowed");
        if ([clockView respondsToSelector:allowedSelector]) {
            BOOL allowed =
                ((BOOL (*)(id, SEL))objc_msgSend)(clockView, allowedSelector);
            [lines addObject:[NSString stringWithFormat:
                @"areOngoingAnimationsAllowed: %@",
                [self yesNo:allowed]]];
        }

        [lines addObject:@"Live clock image-view instance was attached below."];
    }
    @catch (NSException *exception) {
        [lines addObject:[NSString stringWithFormat:
            @"EXCEPTION creating live view: %@ — %@",
            exception.name,
            exception.reason ?: @"(no reason)"]];
    }

    [self setStatus:[lines componentsJoinedByString:@"\n"]];
}

- (UIButton *)probeButton {
    UIButtonConfiguration *configuration =
        [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = @"Run SpringBoardHome runtime probe";
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;

    UIButton *button =
        [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    [button addTarget:self
               action:@selector(runRuntimeProbe)
     forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"LiveIconLab";
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *detail = [[UILabel alloc] init];
    detail.text =
        @"iPadOS 27 SpringBoardHome runtime probe\n\n"
         "This build does not change the Home Screen icon. It tests whether a normal "
         "third-party process can load SpringBoardHome.framework, resolve Apple's "
         "live-clock classes, instantiate SBHClockApplicationIconImageView, and "
         "run its animation machinery.";
    detail.font = [UIFont systemFontOfSize:16];
    detail.numberOfLines = 0;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.textColor = UIColor.secondaryLabelColor;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font =
        [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentLeft;
    self.statusLabel.text = @"Ready. Tap the probe button.";

    self.previewHost = [[UIView alloc] init];
    self.previewHost.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewHost.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.previewHost.layer.cornerRadius = 24;

    UIButton *button = [self probeButton];

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:
            @[title, detail, button, self.statusLabel, self.previewHost]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;

    [self.view addSubview:stack];

    [self.previewHost.heightAnchor constraintEqualToConstant:220].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:48],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-48],
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
        return UIApplicationMain(
            argc, argv, nil, NSStringFromClass([LiveIconLabAppDelegate class]));
    }
}
