#import "RTMPManager.h"
#import "RTMPVideoPlayerView.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface RTMPManager ()

@property (nonatomic, strong) NSString *currentURL;
@property (nonatomic, weak) RTMPVideoPlayerView *currentPlayerView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, strong) NSTimer *reconnectTimer;

@end

@implementation RTMPManager

+ (instancetype)sharedManager {
    static RTMPManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isStreaming = NO;
        [self setupNotifications];
    }
    return self;
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)startStreamWithURL:(NSString *)url playerView:(RTMPVideoPlayerView *)playerView {
    if (self.isStreaming) {
        [self stopStream];
    }
    
    self.currentURL = url;
    self.currentPlayerView = playerView;
    
    if (!url || url.length == 0) {
        NSLog(@"RTMPManager: Invalid URL provided");
        return;
    }
    
    // Create AVPlayer with RTMP URL
    NSURL *streamURL = [NSURL URLWithString:url];
    if (!streamURL) {
        NSLog(@"RTMPManager: Invalid URL format: %@", url);
        return;
    }
    
    // Create player item
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:streamURL];
    
    // Create player
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    
    // Create player layer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = playerView.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    // Add player layer to the player view
    [playerView.layer addSublayer:self.playerLayer];
    
    // Add observers for player status
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    
    // Start playing
    [self.player play];
    self.isStreaming = YES;
    
    NSLog(@"RTMPManager: Started streaming from URL: %@", url);
}

- (void)stopStream {
    if (self.player) {
        [self.player pause];
        [self.playerLayer removeFromSuperlayer];
        self.player = nil;
        self.playerLayer = nil;
    }
    
    if (self.reconnectTimer) {
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
    }
    
    self.isStreaming = NO;
    self.currentURL = nil;
    self.currentPlayerView = nil;
    
    NSLog(@"RTMPManager: Stopped streaming");
}

- (void)reconnectStream {
    if (self.currentURL && self.currentPlayerView) {
        NSLog(@"RTMPManager: Attempting to reconnect...");
        [self startStreamWithURL:self.currentURL playerView:self.currentPlayerView];
    }
}

- (BOOL)isStreaming {
    return _isStreaming;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        switch (playerItem.status) {
            case AVPlayerItemStatusReadyToPlay:
                NSLog(@"RTMPManager: Player ready to play");
                break;
            case AVPlayerItemStatusFailed:
                NSLog(@"RTMPManager: Player failed: %@", playerItem.error);
                [self scheduleReconnect];
                break;
            case AVPlayerItemStatusUnknown:
                NSLog(@"RTMPManager: Player status unknown");
                break;
        }
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        if (playerItem.playbackBufferEmpty) {
            NSLog(@"RTMPManager: Playback buffer empty");
        }
    }
}

- (void)scheduleReconnect {
    if (self.reconnectTimer) {
        [self.reconnectTimer invalidate];
    }
    
    self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                           target:self
                                                         selector:@selector(reconnectStream)
                                                         userInfo:nil
                                                          repeats:NO];
}

#pragma mark - Notifications

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    // Pause stream when app goes to background
    if (self.isStreaming && self.player) {
        [self.player pause];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    // Resume stream when app comes to foreground
    if (self.isStreaming && self.player) {
        [self.player play];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopStream];
}

@end
