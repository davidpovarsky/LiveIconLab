#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString * const LiveIconLabTargetBundleID = @"com.goldcreative.liveiconlab";
static IMP LiveIconLabOriginalIconClassIMP = NULL;

typedef Class (*LiveIconLabIconClassFunction)(id, SEL, NSString *);

static Class LiveIconLabIconClassForApplication(id self, SEL command, NSString *bundleIdentifier) {
    if ([bundleIdentifier isEqualToString:LiveIconLabTargetBundleID]) {
        NSLog(@"[LiveIconLab] TARGET selector invoked for %@", bundleIdentifier);

        Class clockIconClass = NSClassFromString(@"SBHClockApplicationIcon");
        if (clockIconClass != Nil) {
            NSLog(@"[LiveIconLab] Mapping %@ -> SBHClockApplicationIcon", bundleIdentifier);
            return clockIconClass;
        }

        NSLog(@"[LiveIconLab] SBHClockApplicationIcon is not present; falling back.");
    }

    if (LiveIconLabOriginalIconClassIMP != NULL) {
        return ((LiveIconLabIconClassFunction)LiveIconLabOriginalIconClassIMP)(
            self,
            command,
            bundleIdentifier
        );
    }

    return Nil;
}

static void LiveIconLabInstallHook(void) {
    @autoreleasepool {
        const char *frameworkPath =
            "/System/Library/PrivateFrameworks/SpringBoardHome.framework/SpringBoardHome";

        void *handle = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL);
        if (handle == NULL) {
            NSLog(@"[LiveIconLab] Could not load SpringBoardHome: %s", dlerror());
            return;
        }

        Class iconModelClass = NSClassFromString(@"SBHIconModel");
        if (iconModelClass == Nil) {
            NSLog(@"[LiveIconLab] SBHIconModel is unavailable on this build.");
            return;
        }

        SEL selector = NSSelectorFromString(@"iconClassForApplicationWithBundleIdentifier:");
        Method method = class_getInstanceMethod(iconModelClass, selector);
        if (method == NULL) {
            NSLog(@"[LiveIconLab] iconClassForApplicationWithBundleIdentifier: is unavailable.");
            return;
        }

        Class clockIconClass = NSClassFromString(@"SBHClockApplicationIcon");
        Class liveImageViewClass = NSClassFromString(@"SBHClockApplicationIconImageView");
        Class liveBaseClass = NSClassFromString(@"SBLiveIconImageView");

        NSLog(@"[LiveIconLab] Runtime probe: SBHIconModel=%@ ClockIcon=%@ ClockImageView=%@ LiveBase=%@",
              iconModelClass,
              clockIconClass,
              liveImageViewClass,
              liveBaseClass);

        if (clockIconClass == Nil || liveImageViewClass == Nil || liveBaseClass == Nil) {
            NSLog(@"[LiveIconLab] Required iPadOS live-icon classes are incomplete; not installing hook.");
            return;
        }

        LiveIconLabOriginalIconClassIMP =
            method_setImplementation(method, (IMP)LiveIconLabIconClassForApplication);

        if (LiveIconLabOriginalIconClassIMP == NULL) {
            NSLog(@"[LiveIconLab] Failed to capture original icon-class implementation.");
            return;
        }

        NSLog(@"[LiveIconLab] Hook installed for bundle ID %@", LiveIconLabTargetBundleID);
    }
}

__attribute__((constructor))
static void LiveIconLabEntryPoint(void) {
    LiveIconLabInstallHook();
}
