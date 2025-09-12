#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class RTMPVideoPlayerView;

@interface RTMPManager : NSObject

+ (instancetype)sharedManager;

- (void)startStreamWithURL:(NSString *)url playerView:(RTMPVideoPlayerView *)playerView;
- (void)stopStream;
- (BOOL)isStreaming;
- (void)reconnectStream;

@end
