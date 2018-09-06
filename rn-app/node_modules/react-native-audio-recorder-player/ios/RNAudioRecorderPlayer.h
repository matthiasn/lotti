#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RNAudioRecorderPlayer : RCTEventEmitter <RCTBridgeModule, AVAudioPlayerDelegate>
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
        successfully:(BOOL)flag;
- (void)updateRecorderProgress:(NSTimer*) timer;
- (void)updateProgress:(NSTimer*) timer;
- (void)startRecorderTimer;
- (void)startPlayerTimer;
@end
