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
    }
    return self;
}

- (void)startListening {
    if (_isListening) return;
    _isListening = YES;
    
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
    NSString *category = notification.userInfo[@"AVSystemController_AudioCategoryNotificationParameter"];
    
    // Check if it's a volume down press
    if ([category isEqualToString:@"Audio/Video"]) {
        NSString *reason = notification.userInfo[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"];
        
        if ([reason isEqualToString:@"ExplicitVolumeChange"]) {
            _volumePressCount++;
            
            // Reset timer
            [_volumeTimer invalidate];
            _volumeTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                           target:self
                                                         selector:@selector(checkVolumePresses)
                                                         userInfo:nil
                                                          repeats:NO];
        }
    }
}

- (void)checkVolumePresses {
    if (_volumePressCount >= 2) {
        // Double press detected - show RTMP dialog
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showRTMPDialog];
        });
    }
    _volumePressCount = 0;
}

- (void)showRTMPDialog {
    // Get the current key window
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    
    if (!keyWindow) return;
    
    UIViewController *rootViewController = keyWindow.rootViewController;
    UIViewController *topViewController = rootViewController;
    
    // Find the topmost view controller
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    // Create RTMP URL input dialog
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"RTMP Camera Replacer"
                                                                   message:@"Enter RTMP Stream URL:"
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
    
    UIAlertAction *connectAction = [UIAlertAction actionWithTitle:@"Connect"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *rtmpURL = textField.text;
        
        if (rtmpURL && rtmpURL.length > 0) {
            // Save the RTMP URL
            [[NSUserDefaults standardUserDefaults] setObject:rtmpURL forKey:@"RTMPStreamURL"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Show connection status
            [self showConnectionStatus:rtmpURL];
        }
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:connectAction];
    [alert addAction:cancelAction];
    
    [topViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showConnectionStatus:(NSString *)rtmpURL {
    UIAlertController *statusAlert = [UIAlertController alertControllerWithTitle:@"RTMP Connection"
                                                                          message:[NSString stringWithFormat:@"Connecting to:\n%@", rtmpURL]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [statusAlert addAction:okAction];
    
    // Get the current key window and top view controller
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    
    if (keyWindow) {
        UIViewController *rootViewController = keyWindow.rootViewController;
        UIViewController *topViewController = rootViewController;
        
        while (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        }
        
        [topViewController presentViewController:statusAlert animated:YES completion:nil];
