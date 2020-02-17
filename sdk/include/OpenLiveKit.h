#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

/// 流状态
typedef NS_ENUM (NSUInteger, OpenLiveState)
{
    /// 已开始
    OPEN_LIVE_START         = 1,
    /// 已停止
    OPEN_LIVE_STOP          = 2,
    /// 网络已端口
    OPEN_LIVE_DISCONNECTED  = 3,
    /// 网络连接中
    OPEN_LIVE_CONNECTING    = 4,
    /// 网络已连接
    OPEN_LIVE_CONNECTED     = 5,
    /// 连接出错
    OPEN_LIVE_ERROR         = 6
};

@interface OpenLiveInfo : NSObject

@property (nonatomic, assign) CGSize    videoSize;                      ///< 上传的视频分辨率
@property (nonatomic, assign) NSInteger sampleRate;                     ///< 上传的音频采样率
@property (nonatomic, assign) NSInteger channels;                       ///< 上传的音频声道数

@property (nonatomic, assign) CGFloat   bandwidth;                      ///< 10秒平均带宽
@property (nonatomic, assign) CGFloat   frameRate;                      ///< 10秒平均帧率

@property (nonatomic, assign) NSInteger dropFrame;                      ///< 视频累计丢掉的帧数
@property (nonatomic, assign) NSInteger dropSize;                       ///< 音视频累计丢掉的字节

@property (nonatomic, assign) NSInteger totalFrame;                     ///< 视频累计帧数
@property (nonatomic, assign) NSInteger totalSize;                      ///< 音视频累计字节

@property (nonatomic, assign) NSInteger bufferFrame;                    ///< 未发送视频帧数（代表当前缓冲区等待发送的）
@property (nonatomic, assign) NSInteger bufferSize;                     ///< 未发送总字节数（代表当前缓冲区等待发送的）

@end

@class OpenLiveSession;

@protocol OpenLiveSessionDelegate <NSObject>

/** Event callback for session status changed */
- (void)onSessionEvent:(nullable OpenLiveSession *)session newState:(OpenLiveState)state;

/** Event callback for reporting session infomation */
- (void)onSessionEvent:(nullable OpenLiveSession *)session info:(OpenLiveInfo *)info;

@end

@interface OpenLiveSession : NSObject

/** The delegate of the capture. captureData callback */
@property (nullable, nonatomic, weak) id<OpenLiveSessionDelegate> delegate;

/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;

/** The beautyFace control capture shader filter empty or beautiy */
@property (nonatomic, assign) BOOL beautyFace;

/** The beautyLevel control beautyFace Level. Default is 0.5, between 0.0 ~ 1.0 */
@property (nonatomic, assign) CGFloat beautyLevel;

/** The brightLevel control brightness Level, Default is 0.5, between 0.0 ~ 1.0 */
@property (nonatomic, assign) CGFloat brightLevel;

/** The muted control callbackAudioData,muted will memset 0.*/
@property (nonatomic, assign) BOOL muted;

@property (nonatomic, assign) AVCaptureDevicePosition camera;

- (nullable instancetype)initWithView: (UIView *_Nullable)view videoSize:(CGSize)size frameRate:(int)fps bitrate:(int)kbps;

- (void)start: (NSString *_Nonnull)url cryptoKey: (NSString *_Nullable)key;

- (void)stop;

@end
