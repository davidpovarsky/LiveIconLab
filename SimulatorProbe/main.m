#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        const char *path =
            "/System/Library/PrivateFrameworks/SpringBoardHome.framework/SpringBoardHome";
        dlerror();
        void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        const char *err = dlerror();

        printf("SIM_PROBE dlopen=%s\n", handle ? "SUCCESS" : "FAILED");
        if (!handle) {
            printf("SIM_PROBE dlerror=%s\n", err ? err : "(none)");
            return 2;
        }

        const char *names[] = {
            "SBLiveIconImageView",
            "SBHClockApplicationIconImageView",
            "SBHClockApplicationIcon",
            "SBIcon",
            "SBHIconModel"
        };

        for (int i = 0; i < 5; i++) {
            Class cls = objc_getClass(names[i]);
            printf("SIM_PROBE %s=%s\n", names[i], cls ? "FOUND" : "NOT_FOUND");
        }

        Class clock = objc_getClass("SBHClockApplicationIconImageView");
        Class icon = objc_getClass("SBIcon");
        if (!clock || !icon) {
            return 3;
        }

        id view = [[clock alloc] initWithFrame:CGRectMake(0, 0, 180, 180)];
        id iconObject = [[icon alloc] init];
        printf("SIM_PROBE clock_instance=%s\n", view ? "SUCCESS" : "FAILED");
        printf("SIM_PROBE icon_instance=%s\n", iconObject ? "SUCCESS" : "FAILED");
        return (view && iconObject) ? 0 : 4;
    }
}
