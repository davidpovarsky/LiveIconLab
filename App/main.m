#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

typedef struct {
    CGSize size;
    double scale;
    double continuousCornerRadius;
} LiveIconLabSBIconImageInfo;

static NSString * const SpringBoardHomePath =
    @"/System/Library/PrivateFrameworks/SpringBoardHome.framework/SpringBoardHome";

@interface LiveIconLabAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@interface LiveIconLabViewController : UIViewController
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *previewHost;
@property (nonatomic, strong) UIView *clockView;
@property (nonatomic, strong) id clockIcon;
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

- (NSString *)resolvedRootLocationForHandle:(void *)handle {
    void *symbol = dlsym(handle, "SBIconLocationRoot");
    if (symbol) {
        NSString * __unsafe_unretained *value = (NSString * __unsafe_unretained *)symbol;
        if (*value) {
            return *value;
        }
    }

    // Fallback used only if the exported constant cannot be resolved.
    return @"SBIconLocationRoot";
}

- (void)runRuntimeProbe {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    dlerror();
    void *handle = dlopen(SpringBoardHomePath.UTF8String, RTLD_NOW | RTLD_LOCAL);
    const char *error = dlerror();

    [lines addObject:[NSString stringWithFormat:
        @"dlopen SpringBoardHome: %@", handle ? @"SUCCESS" : @"FAILED"]];

    if (!handle) {
        [lines addObject:[NSString stringWithFormat:@"dlerror: %s", error ?: "(none)"]];
        [self setStatus:[lines componentsJoinedByString:@"\n"]];
        return;
    }

    Class liveBaseClass = NSClassFromString(@"SBLiveIconImageView");
    Class clockViewClass = NSClassFromString(@"SBHClockApplicationIconImageView");
    Class iconClass = NSClassFromString(@"SBIcon");

    [lines addObject:[NSString stringWithFormat:@"SBLiveIconImageView: %@",
                      liveBaseClass ? @"FOUND" : @"NOT FOUND"]];
    [lines addObject:[NSString stringWithFormat:@"SBHClockApplicationIconImageView: %@",
                      clockViewClass ? @"FOUND" : @"NOT FOUND"]];
    [lines addObject:[NSString stringWithFormat:@"SBIcon: %@",
                      iconClass ? @"FOUND" : @"NOT FOUND"]];

    if (!clockViewClass || !iconClass) {
        [self setStatus:[lines componentsJoinedByString:@"\n"]];
        return;
    }

    @try {
        [self.clockView removeFromSuperview];
        self.clockView = nil;
        self.clockIcon = nil;

        CGRect frame = CGRectMake(0, 0, 180, 180);

        id allocatedView =
            ((id (*)(id, SEL))objc_msgSend)(clockViewClass, @selector(alloc));
        id clockView =
            ((id (*)(id, SEL, CGRect))objc_msgSend)(allocatedView,
                                                    @selector(initWithFrame:),
                                                    frame);

        id allocatedIcon =
            ((id (*)(id, SEL))objc_msgSend)(iconClass, @selector(alloc));
        id icon =
            ((id (*)(id, SEL))objc_msgSend)(allocatedIcon, @selector(init));

        if (!clockView || !icon) {
            [lines addObject:@"FAILED: could not instantiate clock view or SBIcon."];
            [self setStatus:[lines componentsJoinedByString:@"\n"]];
            return;
        }

        [lines addObject:@"SBHClockApplicationIconImageView init: SUCCESS"];
        [lines addObject:@"SBIcon init: SUCCESS"];

        self.clockView = (UIView *)clockView;
        self.clockIcon = icon;

        CGFloat scale = UIScreen.mainScreen.scale;
        LiveIconLabSBIconImageInfo info;
        info.size = CGSizeMake(180.0, 180.0);
        info.scale = scale;
        info.continuousCornerRadius = 0.0;

        SEL setInfo = NSSelectorFromString(@"setIconImageInfo:");
        if ([clockView respondsToSelector:setInfo]) {
            ((void (*)(id, SEL, LiveIconLabSBIconImageInfo))objc_msgSend)(
                clockView, setInfo, info);
            [lines addObject:[NSString stringWithFormat:
                @"setIconImageInfo: 180x180 scale %.1f sent.", scale]];
        } else {
            [lines addObject:@"setIconImageInfo: NOT FOUND"];
        }

        NSString *location = [self resolvedRootLocationForHandle:handle];
        [lines addObject:[NSString stringWithFormat:@"location: %@", location]];

        SEL setIcon = NSSelectorFromString(@"setIcon:location:animated:");
        if ([clockView respondsToSelector:setIcon]) {
            ((void (*)(id, SEL, id, id, BOOL))objc_msgSend)(
                clockView, setIcon, icon, location, NO);
            [lines addObject:@"setIcon:location:animated: sent."];
        } else {
            [lines addObject:@"setIcon:location:animated: NOT FOUND"];
        }

        UIView *view = (UIView *)clockView;
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.previewHost addSubview:view];

        [NSLayoutConstraint activateConstraints:@[
            [view.centerXAnchor constraintEqualToAnchor:self.previewHost.centerXAnchor],
            [view.centerYAnchor constraintEqualToAnchor:self.previewHost.centerYAnchor],
            [view.widthAnchor constraintEqualToConstant:180.0],
            [view.heightAnchor constraintEqualToConstant:180.0]
        ]];

        [view setNeedsLayout];
        [view layoutIfNeeded];

        SEL paused = NSSelectorFromString(@"setPaused:");
        if ([clockView respondsToSelector:paused]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(clockView, paused, NO);
            [lines addObject:@"setPaused:NO sent."];
        }

        SEL updateUnanimated = NSSelectorFromString(@"updateUnanimated");
        if ([clockView respondsToSelector:updateUnanimated]) {
            ((void (*)(id, SEL))objc_msgSend)(clockView, updateUnanimated);
            [lines addObject:@"updateUnanimated sent."];
        }

        SEL updateState = NSSelectorFromString(@"updateOngoingAnimationState");
        if ([clockView respondsToSelector:updateState]) {
            ((void (*)(id, SEL))objc_msgSend)(clockView, updateState);
            [lines addObject:@"updateOngoingAnimationState sent."];
        }

        SEL allowed = NSSelectorFromString(@"areOngoingAnimationsAllowed");
        if ([clockView respondsToSelector:allowed]) {
            BOOL value = ((BOOL (*)(id, SEL))objc_msgSend)(clockView, allowed);
            [lines addObject:[NSString stringWithFormat:
                @"areOngoingAnimationsAllowed: %@", [self yesNo:value]]];
        }

        SEL iconGetter = NSSelectorFromString(@"icon");
        if ([clockView respondsToSelector:iconGetter]) {
            id attached = ((id (*)(id, SEL))objc_msgSend)(clockView, iconGetter);
            [lines addObject:[NSString stringWithFormat:
                @"clock view icon attached: %@", attached ? @"YES" : @"NO"]];
        }

        [lines addObject:@"Apple live-clock view attached below using ClarityBoard-style setup."];
    }
    @catch (NSException *exception) {
        [lines addObject:[NSString stringWithFormat:
            @"EXCEPTION: %@ — %@",
            exception.name,
            exception.reason ?: @"(no reason)"]];
    }

    [self setStatus:[lines componentsJoinedByString:@"\n"]];
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
        @"Build 15 — ClarityBoard-style Apple live-clock probe\n\n"
         "This reproduces Apple's own setup: SBHClockApplicationIconImageView + "
         "SBIcon + iconImageInfo + setIcon:location:animated:.";
    detail.font = [UIFont systemFontOfSize:16];
    detail.numberOfLines = 0;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.textColor = UIColor.secondaryLabelColor;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font =
        [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.text = @"Ready.";

    self.previewHost = [[UIView alloc] init];
    self.previewHost.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewHost.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.previewHost.layer.cornerRadius = 24;

    UIButtonConfiguration *configuration =
        [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = @"Run Apple live-clock probe";
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    UIButton *button =
        [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    [button addTarget:self
               action:@selector(runRuntimeProbe)
     forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:
            @[title, detail, button, self.statusLabel, self.previewHost]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;

    [self.view addSubview:stack];

    [self.previewHost.heightAnchor constraintEqualToConstant:220].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:48],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-48],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:780]
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
