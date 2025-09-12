#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface VolumeButtonHook : NSObject
+ (instancetype)sharedInstance;
- (void)startListening;
- (void)stopListening;
@end

@implementation VolumeButtonHook {
    NSTimer *_volumeTimer;
    int _volumePressCount;
    BOOL _isListening;
    float _lastVolume;
}

+ (instancetype)sharedInstance {
    static VolumeButtonHook *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VolumeButtonHook alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _volumePressCount = 0;
        _isListening = NO;
        _lastVolume = 0.0f;
    }
    return self;
}

- (void)startListening {
    if (_isListening) return;
    _isListening = YES;
    
    // Get initial volume
    _lastVolume = [[AVAudioSession sharedInstance] outputVolume];
    
    // Listen for volume button notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChanged:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)stopListening {
    if (!_isListening) return;
    _isListening = NO;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                  object:nil];
}

- (void)volumeChanged:(NSNotification *)notification {
    float currentVolume = [[AVAudioSession sharedInstance] outputVolume];
    
    // Check if volume decreased (volume down button)
    if (currentVolume < _lastVolume) {
        _volumePressCount++;
        _lastVolume = currentVolume;
        
        // Reset timer
        [_volumeTimer invalidate];
        _volumeTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                       target:self
                                                     selector:@selector(checkVolumePresses)
                                                     userInfo:nil
                                                      repeats:NO];
    } else {
        _lastVolume = currentVolume;
    }
}

- (void)checkVolumePresses {
    if (_volumePressCount >= 2) {
        // Double press detected - show RTMP dialog
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showRTMPSettings];
        });
    }
    _volumePressCount = 0;
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

@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    
    // Start listening for volume button presses when any view controller loads
    [[VolumeButtonHook sharedInstance] startListening];
}

%end

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    
    // Ensure volume button listening is active
    [[VolumeButtonHook sharedInstance] startListening];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    %orig;
    
    // Stop listening when app becomes inactive
    [[VolumeButtonHook sharedInstance] stopListening];
}

%end
