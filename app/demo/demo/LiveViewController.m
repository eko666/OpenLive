#import "LiveViewController.h"
#import "Masonry.h"
#import "MTBlockAlertView.h"
#import "MBProgressHUD.h"
#import "UIButton+Init.h"
#import "UIViewExt.h"
#import "UINavigationController+Autorotate.h"
#import "UIColor+HEX.h"
#import "LivePrefixHeader.pch"
#import "StatusBarTool+JWZT.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <AudioToolbox/AudioToolbox.h>

#import <OpenLiveKit.h>


#define BTN_TAG_CAMERA      100
#define BTN_TAG_LIVE        101
#define BTN_TAG_MORE        102
#define BTN_TAG_MIC         103

#define SLICE_TAG_BEAUTY    110
#define SLICE_TAG_BRIGHT    111

struct Config
{
    CGSize                  videoSize;
    LIVE_BITRATE            bitRate;
    LIVE_FRAMERATE          fps;
    BOOL                    voice;
    AVCaptureDevicePosition videoPosition;

    NSString               *url;
    NSString               *key;
};

@interface LiveViewController ()<OpenLiveSessionDelegate>
{
    UIView *_previewView;

    // top menu
    UIView   *_topBGView;           // 顶部背景图
    UIButton *_backButton;          // 返回按钮
    UILabel  *_streamTitleLable;    // 码流显示
    UILabel  *_streamValueLable;

    // main menu
    UIButton *_cameraButton;        //摄像头
    UIButton *_liveButton;        //直播
    UIButton *_setButton;           //设置

    // more menu
    UIView   *_moreMenuView;
    UIView   *_moreMenuBGView;      //底部背景
    UIButton *_micSwitcButton;      //声音

    UILabel  *_beautyLabel;         //美颜
    UILabel  *_beautyValue;
    UISlider *_beautySlider;        //美颜

    UILabel  *_brightLabel;         //亮度
    UILabel  *_brightValue;
    UISlider *_brightSlider;        //亮度

    // timer for stream stat
    int _timeNum;                   // 时间值
    NSTimer *_timer;                //
    UILabel *_timelabel;            //时间显示

    BOOL _isBegin;                  // 直播是否开始
    BOOL _isBackCamera;             // 是否后置
    BOOL _isConnected;              // 网络是否已经连接

    struct Config _cfg;
}

// @property (nonatomic, strong)LFLiveDebug *debugInfo;

@property (nonatomic, strong)OpenLiveSession *session;

/**
 当前总流量
 */
@property (nonatomic, assign)CGFloat dataFlow;

/**
 设置是否变化
 */
@property (nonatomic, assign)BOOL settingIsChanged;

/**
 记录上一次美颜值
 */
@property (nonatomic, assign)CGFloat lastBeautyValue;

/**
 记录上一次亮度值
 */
@property (nonatomic, assign)CGFloat lastBrightValue;

/**
 网络监察定时器
 */
@property (nonatomic, strong)NSTimer *checkTimer;

@end

@implementation LiveViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];

    [self layoutUI];
    [self initNotification];

    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self initCamera];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [_timer invalidate];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _settingIsChanged   = NO;                               // 设置改变初始化
    _isBegin            = NO;                               // 默认为未直播状态
    _isBackCamera       = YES;                              // 默认为后摄像头

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *server = [defaults objectForKey:@"server"];
    if (server == NULL || server == nil)
        server = @"192.168.31.250:7504";

    NSString *channel_id = [defaults objectForKey:@"channel_id"];
    if (channel_id == NULL || channel_id == nil)
        channel_id = @"test";

    NSString *key = [defaults objectForKey:@"key"];
    if (key == NULL || key == nil)
        key = @"";

    NSInteger bitrate = [defaults integerForKey:@"bitrate"];
    if (bitrate == 0)
        bitrate = 1000;

    NSString *videoSize = [defaults objectForKey:@"videoSize"];
    if (videoSize == NULL || videoSize == nil)
        videoSize = @"720P";

    _cfg.url = [NSString stringWithFormat:@"http://%@/%@", server, channel_id];
    _cfg.key = key;
    _cfg.bitRate = bitrate * 1024;

    if ([videoSize isEqualToString:@"540P"])
        _cfg.videoSize = LIVE_VIDEO_SIZE_540P;
    else if ([videoSize isEqualToString:@"320P"])
        _cfg.videoSize = LIVE_VIDEO_SIZE_360P;
    else
        _cfg.videoSize = LIVE_VIDEO_SIZE_720P;

    [self requestRight];
    [self initUI];
}

#pragma mark -- openCamera
-(void) initCamera
{
    if (self->_cfg.videoSize.width <= 0)
        self->_cfg.videoSize = LIVE_VIDEO_SIZE_720P;

    if (self->_cfg.bitRate <= 0)
        self->_cfg.bitRate = LIVE_BITRATE_1Mbps;

    if (self->_cfg.fps <= 0)
        self->_cfg.fps = 25;

    dispatch_async(dispatch_get_main_queue(), ^
    {

        OpenLiveSession *session = [[OpenLiveSession alloc] initWithView:self->_previewView
                                                               videoSize:self->_cfg.videoSize
                                                               frameRate:(int)self->_cfg.fps
                                                                 bitrate:(int)self->_cfg.bitRate];

        session.delegate = self;

        self->_session = session;
        self->_settingIsChanged = NO;

        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });
}

#pragma mark -- 请求权限
- (void)requestRight
{
    [self requestRightForVideo];
    [self requestRightForAudio];
}

- (void)requestRightForVideo
{
    __weak typeof(self) _self = self;

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status)
    {
    case AVAuthorizationStatusNotDetermined:
        {
            // 许可对话没有出现，发起授权许可
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler: ^ (BOOL granted)
            {
                if (granted)
                {
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                       [_self.session setRunning:YES];
                    });
                }
            }];
            break;
        }

    case AVAuthorizationStatusAuthorized:
        {
            // 已经开启授权，可继续
            dispatch_async(dispatch_get_main_queue(), ^
            {
               [_self.session setRunning:YES];
            });
            break;
        }

    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        // 用户明确地拒绝授权，或者相机设备无法访问
        break;

    default:
        break;
    }
}

- (void)requestRightForAudio
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status)
    {
    case AVAuthorizationStatusNotDetermined:
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler: ^ (BOOL granted){}];
        break;

    case AVAuthorizationStatusAuthorized:
        break;

    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        break;

    default:
        break;
    }
}

#pragma mark  -- 初始化UI

- (void)initUI
{
    self.view.backgroundColor   = [UIColor blackColor];
    _previewView                = [[UIView alloc] init];

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTouch:)];
    [tapGesture setNumberOfTapsRequired:1];
    [_previewView addGestureRecognizer:tapGesture];

    [self.view addSubview: _previewView];

    [self initMenuTop];
    [self initMenuMain];
    [self initMenuMore];
}

- (void)initMenuTop
{
    // 顶部背景图
    _topBGView                      = [[UIView alloc] init];
    _topBGView.backgroundColor      = [UIColor whiteColor];
    _topBGView.alpha                = 0.3;
    [self.view addSubview:_topBGView];

    // 返回按钮
    _backButton = [UIButton buttonWithnormalImg:[UIImage imageNamed:LiveImageName(@"return")]
                                                     highlightedImg:[UIImage
                                                         imageNamed:LiveImageName(@"return")]
                                       selector:@selector(onExitConfirm:)
                                         target:self];
    [self.view addSubview:_backButton];

    // 定时器
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.20 target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
    [_timer setFireDate:[NSDate distantFuture]];

    // 时间显示
    _timelabel                      = [[UILabel alloc] init];
    _timelabel.text                 = @"00:00:00";
    _timelabel.textAlignment        = NSTextAlignmentCenter;
    _timelabel.textColor            = [UIColor whiteColor];
    _timelabel.font                 = [UIFont systemFontOfSize:14];
    [self.view addSubview:_timelabel];

    // 网络显示
    _streamTitleLable               = [[UILabel alloc] init];
    _streamTitleLable.text          = @"网络:";
    _streamTitleLable.textAlignment = NSTextAlignmentRight;
    _streamTitleLable.textColor     = [UIColor whiteColor];
    _streamTitleLable.font          = [UIFont systemFontOfSize:14];
    [self.view addSubview:_streamTitleLable];

    _streamValueLable               = [[UILabel alloc] init];
    _streamValueLable.text          = @"已停止";
    _streamValueLable.textAlignment = NSTextAlignmentLeft;
    _streamValueLable.textColor     = [UIColor whiteColor];
    _streamValueLable.font          = [UIFont systemFontOfSize:14];
    [self.view addSubview:_streamValueLable];
}

- (void)initMenuMain
{
    // 摄像头
    _cameraButton = [UIButton buttonWithnormalImg:[UIImage imageNamed:LiveImageName(@"photo")]  selectedImg:[UIImage imageNamed:LiveImageName(@"photo")] selector:@selector(onMenuClick:) target:self];
    [_cameraButton setBackgroundImage:[UIImage imageNamed:LiveImageName(@"photo-round")] forState:UIControlStateNormal];
    _cameraButton.tag = BTN_TAG_CAMERA;
    [self.view addSubview:_cameraButton];

    // 直播开始
    _liveButton = [UIButton buttonWithnormalImg:[UIImage imageNamed:LiveImageName(@"camera")] selectedImg:[UIImage imageNamed:LiveImageName(@"camera-living")] selector:@selector(onMenuClick:) target:self];
    [_liveButton setBackgroundImage:[UIImage imageNamed:LiveImageName(@"cemera-round")] forState:UIControlStateNormal];
    _liveButton.selected = NO;

    // 开始直播有延迟。  避开这个之间的延迟时间
    _liveButton.enabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        self->_liveButton.enabled = YES;
    });
    _liveButton.tag = BTN_TAG_LIVE;
    [self.view addSubview:_liveButton];

    //设置
    _setButton = [UIButton buttonWithnormalImg:[UIImage imageNamed:LiveImageName(@"set")] selectedImg:[UIImage imageNamed:LiveImageName(@"set")] selector:@selector(onMenuClick:) target:self];
    [_setButton setBackgroundImage:[UIImage imageNamed:LiveImageName(@"set-round")] forState:UIControlStateNormal];
    _setButton.tag = BTN_TAG_MORE;
    [self.view addSubview:_setButton];
}

- (void)initMenuMore
{
    _moreMenuView                           = [[UIView alloc] init];
    _moreMenuView.backgroundColor           = [UIColor clearColor];
    _moreMenuView.layer.cornerRadius        = 5;
    _moreMenuView.clipsToBounds             = YES;

    _moreMenuBGView                         = [[UIView alloc] init];
    _moreMenuBGView.backgroundColor         = [UIColor whiteColor];
    _moreMenuBGView.alpha                   = .5;
    _moreMenuBGView.layer.cornerRadius      = 5;
    _moreMenuBGView.clipsToBounds           = YES;

    [self.view addSubview:_moreMenuView];
    [_moreMenuView addSubview:_moreMenuBGView];

    // 声音
    _micSwitcButton                         = [UIButton buttonWithnormalImg:[UIImage imageNamed:LiveImageName(@"voice-open")] selectedImg:[UIImage imageNamed:LiveImageName(@"voice-closed")] selector:@selector(onMenuClick:) target:self];
    _micSwitcButton.tag                     = BTN_TAG_MIC;
    [_moreMenuView addSubview:_micSwitcButton];

    // 美颜 - label
    _beautyLabel                            = [[UILabel alloc] init];
    _beautyLabel.text                       = @"美颜调节";
    _beautyLabel.textColor                  = [UIColor blackColor];
    _beautyLabel.font                       = [UIFont systemFontOfSize:14];
    [_moreMenuView addSubview:_beautyLabel];

    // 美颜 - slider
    _beautySlider                           = [[UISlider alloc] init];
    _beautySlider.tag                       = SLICE_TAG_BEAUTY;
    _beautySlider.minimumValue              = 0.0;
    _beautySlider.maximumValue              = 100.0;
    _beautySlider.value                     = 50;
    _beautySlider.minimumTrackTintColor     = RGB(17, 195, 236);
    _lastBeautyValue                        = 50;
    [_beautySlider setThumbImage:[UIImage imageNamed:LiveImageName(@"Handle")] forState:UIControlStateNormal];
    [_beautySlider addTarget:self action:@selector(onSliderValueChage:) forControlEvents:UIControlEventValueChanged];
    [_moreMenuView addSubview:_beautySlider];

    // 美颜 - value
    _beautyValue                            = [[UILabel alloc] init];
    _beautyValue.text                       = @"50";
    _beautyValue.textColor                  = [UIColor blackColor];
    _beautyValue.font                       = [UIFont systemFontOfSize:10];
    _beautyValue.textAlignment              = NSTextAlignmentCenter;
    [_moreMenuView addSubview:_beautyValue];

    // 亮度 - label
    _brightLabel                            = [[UILabel alloc] init];
    _brightLabel.text                       = @"亮度调节";
    _brightLabel.textColor                  = [UIColor blackColor];
    _brightLabel.font                       = [UIFont systemFontOfSize:14];
    [_moreMenuView addSubview:_brightLabel];

    // 亮度 - slider
    _brightSlider                           = [[UISlider alloc] init];
    _brightSlider.minimumValue              = 0.0;
    _brightSlider.maximumValue              = 100.0;
    _brightSlider.value                     = 50;
    _brightSlider.tag                       = SLICE_TAG_BRIGHT;
    _brightSlider.minimumTrackTintColor     = RGB(17, 195, 236);
    _lastBrightValue                        = 50;
    [_brightSlider setThumbImage:[UIImage imageNamed:LiveImageName(@"Handle")] forState:UIControlStateNormal];
    [_brightSlider addTarget:self action:@selector(onSliderValueChage:) forControlEvents:UIControlEventValueChanged];
    [_moreMenuView addSubview:_brightSlider];

    // 亮度 - value
    _brightValue                            = [[UILabel alloc] init];
    _brightValue.text                       = @"50";
    _brightValue.textColor                  = [UIColor blackColor];
    _brightValue.font                       = [UIFont systemFontOfSize:10];
    _brightValue.textAlignment              = NSTextAlignmentCenter;
    [_moreMenuView addSubview:_brightValue];

    _moreMenuView.hidden                    = YES;
}

#pragma mark - layoutUI

- (void)layoutUI
{
    [_previewView mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.top.left.equalTo(self.view);
            make.width.height.equalTo(self.view);
        }
    ];

    [self layoutMenuTop];
    [self layoutMenuMain];
    [self layoutMenuMore];
}

- (UIEdgeInsets)safeAreaInset
{
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone)
        return UIEdgeInsetsZero;

    if (@available(iOS 11.0, *))
        return [[[UIApplication sharedApplication] delegate] window].safeAreaInsets;

    return UIEdgeInsetsZero;
}

- (void)layoutMenuTop
{
    float  offset = 0.0f;

    UIEdgeInsets safeAreaInsets = [self safeAreaInset];
    // if (safeAreaInsets.bottom > 0.0f)
    offset = safeAreaInsets.top;

    [_topBGView mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(IphoneWidth, 39 + offset));
            make.left.equalTo(self.view.mas_left).with.offset(0);
            make.top.equalTo(self.view.mas_top).with.offset(0);
        }
    ];

    UIImage *backImage = [UIImage imageNamed:LiveImageName(@"return")];
    [_backButton mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(49, backImage.size.height));
            make.top.equalTo(self.view.mas_top).with.offset(11 + offset);
            make.left.equalTo(self->_topBGView.mas_left).with.offset(0);
        }
    ];

    [_timelabel mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(70, 30));
            make.centerY.equalTo(self->_backButton.mas_centerY).with.offset(0);
            make.left.equalTo(self->_backButton.mas_right).with.offset(0);
        }
    ];

    [_streamValueLable mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(60, 20));
            make.centerY.equalTo(self->_backButton.mas_centerY).with.offset(0);
            make.right.equalTo(self->_topBGView.mas_right).with.offset(-10);
        }
    ];

    [_streamTitleLable mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(50, 20));
            make.centerY.equalTo(self->_backButton.mas_centerY).with.offset(0);
            make.right.equalTo(self->_streamValueLable.mas_left).with.offset(-3);
        }
    ];
}

- (void)layoutMenuMain
{
    UIImage *cameraImage = [UIImage imageNamed:LiveImageName(@"photo-round")];
    [_cameraButton mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(cameraImage.size.width, cameraImage.size.height));
            make.bottom.equalTo(self.view.mas_bottom).with.offset(-20);
            make.left.equalTo(self.view.mas_left).with.offset(25);
        }
    ];

    UIImage *reportimage = [UIImage imageNamed:LiveImageName(@"cemera-round")];
    [_liveButton mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(reportimage.size.width, reportimage.size.height));
            make.bottom.equalTo(self.view.mas_bottom).with.offset(-13);
            make.centerX.equalTo(self.view.mas_centerX).with.offset(0);
        }
    ];

    UIImage *setimage = [UIImage imageNamed:LiveImageName(@"set-round")];
    [_setButton mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(setimage.size.width, setimage.size.height));
            make.bottom.equalTo(self.view.mas_bottom).with.offset(-20);
            make.right.equalTo(self.view.mas_right).with.offset(-25);
        }
    ];
}

- (void)layoutMenuMore
{
    int width = IphoneWidth - 20;

    [_moreMenuView mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(width, 150));
            make.right.equalTo(self.view.mas_right).with.offset(-10);
            make.bottom.equalTo(self->_setButton.mas_top).with.offset(-10);
        }
    ];

    [_moreMenuBGView mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(width, 150));
            make.right.equalTo(self.view.mas_right).with.offset(-10);
            make.bottom.equalTo(self->_setButton.mas_top).with.offset(-10);
        }
    ];

    // mic switch
    UIImage *micSwitcImage = [UIImage imageNamed:LiveImageName(@"voice-open")];
    [_micSwitcButton mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(49, micSwitcImage.size.height));
            make.right.equalTo(self->_moreMenuView.mas_right).with.offset(-10);
            make.top.equalTo(self->_moreMenuView.mas_top).with.offset(10);
        }
    ];

    // beauty
    [_beautyLabel mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(70, 20));
            make.left.equalTo(self->_moreMenuView.mas_left).with.offset(10);
            make.top.equalTo(self->_moreMenuView.mas_top).with.offset(65);
        }
    ];

    [_beautySlider mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(width - 120, 20));
            make.left.equalTo(self->_beautyLabel.mas_right).with.offset(10);
            make.top.equalTo(self->_moreMenuView.mas_top).with.offset(65);
        }
    ];

    [_beautyValue mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(20, 10));
            make.centerX.equalTo(self->_beautySlider.mas_centerX).with.offset(0);
            make.top.equalTo(self->_beautySlider.mas_bottom).with.offset(0);
        }
    ];

    // bright
    [_brightLabel mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(70, 20));
            make.left.equalTo(self->_moreMenuView.mas_left).with.offset(10);
            make.bottom.equalTo(self->_moreMenuView.mas_bottom).with.offset(-20);
        }
    ];

    [_brightSlider mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(width - 120, 20));
            make.left.equalTo(self->_brightLabel.mas_right).with.offset(10);
            make.bottom.equalTo(self->_moreMenuView.mas_bottom).with.offset(-20);
        }
    ];

    [_brightValue mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(20, 10));
            make.centerX.equalTo(self->_brightSlider.mas_centerX).with.offset(0);
            make.top.equalTo(self->_brightSlider.mas_bottom).with.offset(0);
        }
    ];
}

#pragma mark - init notification

- (void)initNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppEnterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];//删除去激活界面的回调
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil]; //删除激活界面的回调
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onSliderValueChage:(id)slider
{
    UISlider *searchSlider = slider;

    switch (searchSlider.tag)
    {
    case SLICE_TAG_BEAUTY:
        {
            self.session.beautyLevel = searchSlider.value / 100;

            NSString *voiceValue = [NSString stringWithFormat:@"%.0f", searchSlider.value];
            _beautyValue.text = voiceValue;

            CGFloat change = (_lastBeautyValue - searchSlider.value) * 2;

            if (searchSlider.value < 20)
                _beautyValue.textAlignment = NSTextAlignmentRight;
            else if (searchSlider.value > 80)
                _beautyValue.textAlignment = NSTextAlignmentLeft;
            else
                _beautyValue.textAlignment = NSTextAlignmentCenter;

            [UIView animateWithDuration:0.1 animations:^{self->_beautyValue.x -= change;}];
            _lastBeautyValue = searchSlider.value;
        }
        break;

    case SLICE_TAG_BRIGHT:
        {
            self.session.brightLevel = searchSlider.value / 100;

            NSString *voiceValue = [NSString stringWithFormat:@"%.0f", searchSlider.value];
            _brightValue.text = voiceValue;

            CGFloat change = (_lastBrightValue - searchSlider.value) * 2;

            if (searchSlider.value < 20)
                _brightValue.textAlignment = NSTextAlignmentRight;
            else if (searchSlider.value > 80)
                _brightValue.textAlignment = NSTextAlignmentLeft;
            else
                _brightValue.textAlignment = NSTextAlignmentCenter;

            [UIView animateWithDuration:0.1 animations:^{self->_brightValue.x -= change;}];
            _lastBrightValue = searchSlider.value;
        }
        break;

    default:
        break;
    }
}

- (void)onTimer
{
    _timeNum ++;

    int times = _timeNum % 20;
    switch (times)
    {
    case 8:
    case 9:
    case 10:
    case 11:
        _liveButton.imageView.alpha = 0.1;
        break;
    case 7:
    case 12:
        _liveButton.imageView.alpha = 0.2;
        break;
    case 6:
    case 13:
        _liveButton.imageView.alpha = 0.4;
        break;
    case 5:
    case 14:
        _liveButton.imageView.alpha = 0.6;
        break;
    case 4:
    case 15:
        _liveButton.imageView.alpha = 0.8;
        break;
    default:
        _liveButton.imageView.alpha = 1.0;
        break;
    }

    if (_timeNum % 4 == 0)
    {
        int timeNum = _timeNum / 5;
        // hour
        NSInteger hour = timeNum / 3600;
        NSString *hourText = hour < 10 ? [NSString stringWithFormat:@"0%ld", (long)hour] : [NSString stringWithFormat:@"%ld", (long)hour];
        // minute
        NSInteger minute = ( timeNum - hour * 3600) / 60;
        NSString *minuteText = minute < 10 ? [NSString stringWithFormat:@"0%ld", (long)minute] : [NSString stringWithFormat:@"%ld", (long)minute];
        // second
        NSInteger second = (timeNum - hour * 3600 - minute * 60);
        NSString *secondText = second < 10 ? [NSString stringWithFormat:@"0%ld", (long)second] : [NSString stringWithFormat:@"%ld", (long)second];
        _timelabel.text = [NSString stringWithFormat:@"%@:%@:%@", hourText, minuteText, secondText];
    }
}

- (void)onMenuClick:(UIButton *)button
{
    if (button.tag != BTN_TAG_MORE && button.tag != BTN_TAG_MIC)
    {
        if (!_moreMenuView.hidden)
            _moreMenuView.hidden = YES;
    }

    switch (button.tag)
    {
    case BTN_TAG_CAMERA:
        {
            button.selected = !button.selected;
            AVCaptureDevicePosition devicePositon = self.session.camera;
            self.session.camera = (devicePositon == AVCaptureDevicePositionBack) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
        }
        break;

    case BTN_TAG_LIVE:
        {
             if (!_isBegin)
                 [MBProgressHUD showHUDAddedTo:self.view animated:YES];

            if (button.selected == YES)
            {
                MTBlockAlertView *alertview = [[MTBlockAlertView alloc] initWithTitle:@"是否结束直播"
                                                                              message:nil
                                                                    completionHanlder: ^ (UIAlertView * alertView, NSInteger buttonIndex)
                                                                                        {
                                                                                            if (buttonIndex == 0)
                                                                                            {
                                                                                                [self.session stop];
                                                                                                self->_isBegin = NO;
                                                                                                self->_liveButton.selected = NO;
                                                                                            }
                                                                                        }
                                                                    cancelButtonTitle: nil
                                                                    otherButtonTitles: @"确定", @"取消", nil];
                [alertview show];
            }
            else
            {
                _liveButton.enabled = NO;
                [self.session start:self->_cfg.url cryptoKey:self->_cfg.key];
            }
        }
        break;

    case BTN_TAG_MIC:
        {
            // 语音开关,默认是trun。 当直播开始录制的时候endle = no 不可以调节。
            // 关闭_>打开
            button.selected = !button.selected;

            UIView *alertView = [[UIView alloc] init];

            alertView.backgroundColor   = [UIColor whiteColor];
            alertView.alpha             = .5;
            [self.view addSubview:alertView];

            UILabel *alertLabel     = [[UILabel alloc] init];
            alertLabel.textColor    = [UIColor whiteColor];
            alertLabel.font         = [UIFont systemFontOfSize:14];
            alertLabel.textAlignment= NSTextAlignmentCenter;

            [self.view addSubview:alertLabel];

            if (_session.muted)
                alertLabel.text = @"语音已开启!";
            else
                alertLabel.text = @"语音已关闭!";

            _session.muted = !_session.muted;
            _cfg.voice = !_cfg.voice;
            [alertView mas_makeConstraints: ^ (MASConstraintMaker * make)
                                            {
                                                make.size.mas_equalTo(CGSizeMake(100, 30));
                                                make.centerX.equalTo(self.view.mas_centerX).with.offset(0);
                                                make.centerY.equalTo(self.view.mas_centerY).with.offset(0);
                                            }];

            [alertLabel mas_makeConstraints: ^ (MASConstraintMaker * make)
                                            {

                                                make.size.mas_equalTo(CGSizeMake(90, 20));
                                                make.centerX.equalTo(self.view.mas_centerX).with.offset(0);
                                                make.centerY.equalTo(self.view.mas_centerY).with.offset(0);
                                            }];

            [UIView animateWithDuration:0.5
                                  delay:0.5
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                           alertLabel.alpha = 0;
                                           alertView.alpha = 0;
                                         }
                             completion: ^ (BOOL finished){
                                                [alertView removeFromSuperview];
                                                [alertLabel removeFromSuperview];
                                         }];
        }
        break;

    case BTN_TAG_MORE:
        {
            _moreMenuView.hidden = !_moreMenuView.hidden;
        }
        break;

    default:
        break;
    }
}

- (void)onTouch:(UITapGestureRecognizer *)gesture
{
    NSLog(@"onTouch");

    if (!_moreMenuView.hidden)
        _moreMenuView.hidden = YES;
}

#pragma mark - exit event
- (void)onExitConfirm:(UIButton *)button
{
    MTBlockAlertView *alertview = [[MTBlockAlertView alloc] initWithTitle:@"是否退出直播？"
                                                                  message:nil
                                                        completionHanlder: ^(UIAlertView *alertView, NSInteger buttonIndex)
                                                                            {
                                                                                if (buttonIndex == 0)
                                                                                {
                                                                                    [self->_session stop];
                                                                                    [self dismissViewControllerAnimated:YES completion:^{}];
                                                                                }
                                                                            }
                                                        cancelButtonTitle: nil
                                                        otherButtonTitles: @"确定", @"取消", nil];
    [alertview show];
}

#pragma mark - event callback
- (void)onSessionEvent:(nullable OpenLiveSession *)session newState:(OpenLiveState)state
{
    NSLog(@"session event %lu", (unsigned long)state);

    switch (state)
    {
    case OPEN_LIVE_START:
        {
            [_timer setFireDate:[NSDate date]];
            _liveButton.selected    = YES;
            _liveButton.enabled     = YES;
            _isBegin                = YES;
            _isConnected            = NO;
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        }
        break;

    case OPEN_LIVE_STOP:
        {
            _streamValueLable.textAlignment = NSTextAlignmentLeft;
            _streamTitleLable.text  = @"网络:";
            _streamValueLable.text  = @"已停止";
            _liveButton.selected    = NO;
            _timelabel.text         = @"00:00:00";
            _timeNum                = 0;
            [_timer setFireDate:[NSDate distantFuture]];
        }
        break;

    case OPEN_LIVE_DISCONNECTED:
        {
            _streamValueLable.textAlignment = NSTextAlignmentLeft;
            _streamTitleLable.text  = @"网络:";
            _streamValueLable.text  = @"已断开";
            _isConnected            = NO;
        }
        break;

    case OPEN_LIVE_CONNECTING:
        {
            _streamValueLable.textAlignment = NSTextAlignmentLeft;
            _streamTitleLable.text  = @"网络:";
            _streamValueLable.text  = @"连接中";
            _isConnected            = NO;
        }
        break;

    case OPEN_LIVE_CONNECTED:
        {
            _streamValueLable.textAlignment = NSTextAlignmentLeft;
            _streamTitleLable.text  = @"网络:";
            _streamValueLable.text  = @"已连接";
            _isConnected            = YES;
        }
        break;

    case OPEN_LIVE_ERROR:
        _liveButton.enabled     = YES;
        _isConnected            = NO;
        break;

    default:
        break;
    }
}

- (void)onSessionEvent:(nullable OpenLiveSession *)session info:(OpenLiveInfo *)info
{
    [info description];

    if (!_isConnected)
        return;

    _streamTitleLable.text = [NSString stringWithFormat:@"%.0ffps", info.frameRate];
    _streamValueLable.text = [NSString stringWithFormat:@"%4.0fk", info.bandwidth];
    _streamValueLable.textAlignment = NSTextAlignmentRight;
}

- (BOOL)hasPermissionOfCamera
{
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if (authStatus != AVAuthorizationStatusAuthorized)
    {
        NSLog(@"相机权限受限");
        return NO;
    }
    return YES;
}

- (void)onAppEnterForeground
{
    NSLog(@"trigger event when will enter foreground.");

    if (![self hasPermissionOfCamera])
        return;
}

- (void)onResignActive
{
    NSLog(@"LiveShowViewController: onResignActive");

    if (![self hasPermissionOfCamera])
        return;

    //得到当前应用程序的UIApplication对象
    UIApplication *app = [UIApplication sharedApplication];

    //一个后台任务标识符
    UIBackgroundTaskIdentifier taskID = 0;
    taskID = [app beginBackgroundTaskWithExpirationHandler:^
        {
            //如果系统觉得我们还是运行了太久，将执行这个程序块，并停止运行应用程序
            [app endBackgroundTask:taskID];
        }];

    //UIBackgroundTaskInvalid表示系统没有为我们提供额外的时候
    if (taskID == UIBackgroundTaskInvalid)
    {
        NSLog(@"Failed to start background task!");
        return;
    }

    [self.session stop];

    // 告诉系统我们完成了
    [app endBackgroundTask:taskID];
}

#pragma mark -- shouldAutorotate (类目)

//不自动旋转
- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

@end
