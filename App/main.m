#import <UIKit/UIKit.h>

static NSString * const LiveIconLabBundleID = @"com.goldcreative.liveiconlab";

@interface LiveIconLabViewController : UIViewController
@end

@implementation LiveIconLabViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"LiveIconLab";
    title.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *status = [[UILabel alloc] init];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    status.text = [NSString stringWithFormat:
        @"iPadOS 27 live-icon research harness\n\nBundle ID\n%@\n\n"
         "If the SpringBoard hook is active, this app's Home Screen icon should be "
         "rendered using SBHClockApplicationIcon.",
         LiveIconLabBundleID];
    status.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightRegular];
    status.numberOfLines = 0;
    status.textAlignment = NSTextAlignmentCenter;
    status.textColor = [UIColor secondaryLabelColor];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, status]];
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
        [stack.widthAnchor constraintLessThanOrEqualToConstant:680.0]
    ]];
}

@end

@interface LiveIconLabAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation LiveIconLabAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    LiveIconLabViewController *controller = [[LiveIconLabViewController alloc] init];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([LiveIconLabAppDelegate class]));
    }
}
