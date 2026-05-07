#import "XXAppDelegate.h"
#import "XXRootViewController.h"

@implementation XXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[XXRootViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end