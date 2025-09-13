#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface RTMPButtonManager : NSObject
+ (instancetype)sharedInstance;
- (void)showRTMPSettings;
- (void)addButtonToHomeScreen;
@end

@implementation RTMPButtonManager

+ (instancetype)sharedInstance {
    static RTMPButtonManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTMPButtonManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize
    }
    return self;
}

- (UIViewController *)getTopViewController {
    UIViewController *topController = nil;
    
    // Try to get the key window using connectedScenes (iOS 13+)
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        topController = window.rootViewController;
                        break;
                    }
                }
                if (topController) break;
            }
        }
    }
    
    // If we didn't find a controller, try the first available window
    if (!topController) {
        NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
        for (UIWindow *window in windows) {
            if (window.isKeyWindow) {
                topController = window.rootViewController;
                break;
            }
        }
    }
    
    // Find the topmost presented view controller
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

- (void)showRTMPSettings {
    UIViewController *topViewController = [self getTopViewController];
    if (!topViewController) return;
    
    // Create RTMP settings dialog
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"RTMP Camera Settings"
                                                                   message:@"Configure RTMP Stream:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"rtmp://example.com/live/stream";
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        
        // Load saved RTMP URL if available
        NSString *savedURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"RTMPStreamURL"];
        if (savedURL) {
            textField.text = savedURL;
        }
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Save & Connect"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *rtmpURL = textField.text;
        
        if (rtmpURL && rtmpURL.length > 0) {
            // Save the RTMP URL
            [[NSUserDefaults standardUserDefaults] setObject:rtmpURL forKey:@"RTMPStreamURL"];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"RTMPEnabled"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Show connection status
            [self showConnectionStatus:rtmpURL];
        }
    }];
    
    UIAlertAction *disableAction = [UIAlertAction actionWithTitle:@"Disable RTMP"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
        // Disable RTMP
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"RTMPEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self showDisableStatus];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:saveAction];
    [alert addAction:disableAction];
    [alert addAction:cancelAction];
    
    [topViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showConnectionStatus:(NSString *)rtmpURL {
    UIAlertController *statusAlert = [UIAlertController alertControllerWithTitle:@"RTMP Connected"
                                                                          message:[NSString stringWithFormat:@"Camera feed will be replaced with:\n%@", rtmpURL]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [statusAlert addAction:okAction];
    
    UIViewController *topViewController = [self getTopViewController];
    if (topViewController) {
        [topViewController presentViewController:statusAlert animated:YES completion:nil];
    }
}

- (void)showDisableStatus {
    UIAlertController *statusAlert = [UIAlertController alertControllerWithTitle:@"RTMP Disabled"
                                                                          message:@"Camera feed restored to normal"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [statusAlert addAction:okAction];
    
    UIViewController *topViewController = [self getTopViewController];
    if (topViewController) {
        [topViewController presentViewController:statusAlert animated:YES completion:nil];
    }
}

- (void)addButtonToHomeScreen {
    // This will be called when the home screen loads
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self createFloatingButton];
    });
}

- (void)createFloatingButton {
    // Get the key window
    UIWindow *keyWindow = nil;
    
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    } else {
        NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
        for (UIWindow *window in windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }
    
    if (!keyWindow) return;
    
    // Remove existing button if it exists
    for (UIView *subview in keyWindow.subviews) {
        if (subview.tag == 9999) {
            [subview removeFromSuperview];
        }
    }
    
    // Create floating button
    UIButton *rtmpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rtmpButton.tag = 9999;
    rtmpButton.frame = CGRectMake(20, 100, 60, 60);
    rtmpButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8];
    rtmpButton.layer.cornerRadius = 30;
    rtmpButton.layer.shadowColor = [UIColor blackColor].CGColor;
    rtmpButton.layer.shadowOffset = CGSizeMake(0, 2);
    rtmpButton.layer.shadowOpacity = 0.3;
    rtmpButton.layer.shadowRadius = 4;
    
    // Add RTMP icon/text
    [rtmpButton setTitle:@"RTMP" forState:UIControlStateNormal];
    [rtmpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rtmpButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    
    // Add action
    [rtmpButton addTarget:self action:@selector(showRTMPSettings) forControlEvents:UIControlEventTouchUpInside];
    
    // Add to window
    [keyWindow addSubview:rtmpButton];
    
    // Make it draggable
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [rtmpButton addGestureRecognizer:panGesture];
    
    // Bring to front
    [keyWindow bringSubviewToFront:rtmpButton];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIButton *button = (UIButton *)gesture.view;
    UIView *superview = button.superview;
    
    if (!superview) return;
    
    CGPoint translation = [gesture translationInView:superview];
    CGPoint newCenter = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    
    // Keep button within screen bounds
    CGFloat buttonRadius = button.frame.size.width / 2;
    newCenter.x = MAX(buttonRadius, MIN(superview.frame.size.width - buttonRadius, newCenter.x));
    newCenter.y = MAX(buttonRadius + 50, MIN(superview.frame.size.height - buttonRadius - 50, newCenter.y));
    
    button.center = newCenter;
    [gesture setTranslation:CGPointZero inView:superview];
}

@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    
    // Add RTMP button to home screen - try multiple class names
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"SpringBoard"] || 
        [className containsString:@"Home"] || 
        [className containsString:@"SB"] ||
        [className containsString:@"HomeScreen"]) {
        [[RTMPButtonManager sharedInstance] addButtonToHomeScreen];
    }
}

%end

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    
    // Add button when app becomes active (for home screen)
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[RTMPButtonManager sharedInstance] addButtonToHomeScreen];
        });
    }
}

%end

// Hook SpringBoard directly
%hook NSObject

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[RTMPButtonManager sharedInstance] addButtonToHomeScreen];
        });
    }
}

%end
