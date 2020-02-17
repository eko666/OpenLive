#import "ZSPlayerView.h"
#import "ZSButton.h"
#import "ZSLoading.h"
#import "Masonry.h"

#define BTN_TAG_LOCK    101
#define BTN_TAG_PLAY    102
#define BTN_TAG_SCREEN  103
#define BTN_TAG_BACK    104

@interface ZSPlayerView()<UIGestureRecognizerDelegate>
{
    UIImageView     *_placeHolderImgView;
    UIImageView     *_voiceImgView;
    UIImageView     *_brightnessImgView;

    BOOL            _hideTool;
    NSTimer         *_timer;

    CGPoint         _startP;
    CAShapeLayer    *_layer;
    CAShapeLayer    *_layerContainer;
}

//工具蒙版
@property (nonatomic, strong) ZSButton          *btnLock;
@property (nonatomic, strong) ZSLoading         *loading;

//标题栏
@property (nonatomic, strong) ZSButton          *btnBack;
@property (nonatomic, strong) UILabel           *lblTitle;

//工具蒙版
@property (nonatomic, strong) ZSButton          *btnPlay;
@property (nonatomic, strong) ZSButton          *btnFullScreen;
@property (nonatomic, strong) UILabel           *lblCurrentTime;
@property (nonatomic, strong) UILabel           *lblTotalTime;
@property (nonatomic, strong) UISlider          *slider;
@property (nonatomic, strong) UIProgressView    *progressView;

//播放视图
@property (nonatomic, strong) UIView            *playerView;
@property (nonatomic, strong) UIView            *cover;

@end

@implementation ZSPlayerView

#pragma mark-初始化方法

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    return self;
}

- (void)setup
{
    float  offset = 0.0f;
    UIEdgeInsets safeAreaInsets = [self safeAreaInset];
    // if (safeAreaInsets.bottom > 0.0f)
    offset = safeAreaInsets.top;

    IJKFFOptions *options = [IJKFFOptions optionsByDefault];
    [options setOptionIntValue:IJK_AVDISCARD_DEFAULT forKey:@"skip_frame" ofCategory:kIJKFFOptionCategoryCodec];
    [options setOptionIntValue:IJK_AVDISCARD_DEFAULT forKey:@"skip_loop_filter" ofCategory:kIJKFFOptionCategoryCodec];
    [options setOptionIntValue:0 forKey:@"videotoolbox" ofCategory:kIJKFFOptionCategoryPlayer];
    [options setOptionIntValue:60 forKey:@"max-fps" ofCategory:kIJKFFOptionCategoryPlayer];
    [options setPlayerOptionIntValue:256 forKey:@"vol"];

    NSURL *url = [NSURL URLWithString:self->_url];
    self.player = [[IJKFFMoviePlayerController alloc] initWithContentURL:url withOptions:options];

    if (self->_isVod)
        [self.player setScalingMode:IJKMPMovieScalingModeAspectFit];
    else
        [self.player setScalingMode:IJKMPMovieScalingModeAspectFill];
    [self.player prepareToPlay];
    [self installMovieNotificationObservers];

    //获取播放视图, 把播放视图插到最上面去
    self.playerView = [self.player view];
    self.playerView.frame = self.bounds;
    [self insertSubview:self.playerView atIndex:0];

    _placeHolderImgView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"blackBG"]];
    [self.playerView addSubview:_placeHolderImgView];
    [_placeHolderImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(self.playerView);
    }];

    UITapGestureRecognizer *tap  = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(playerViewTap:)];
    tap.delegate = self;
    [self.playerView addGestureRecognizer:tap];
    self.cover = [[UIView alloc]init];
    self.cover.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.1];
    [self.playerView addSubview:self.cover];
    [self.cover mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(self.playerView);
    }];

    // 返回按钮
    _btnBack = [[ZSButton alloc]init];
    _btnBack.tag = BTN_TAG_BACK;
    [_btnBack setImage:[UIImage imageNamed:@"back"] forState:(UIControlStateNormal)];
    [_cover addSubview:_btnBack];
    [_btnBack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self->_cover);
        make.top.equalTo(self->_cover).offset(offset + 5);
        make.width.height.mas_equalTo(60);
    }];
    [_btnBack addTarget:self action:@selector(onBtnClick:) forControlEvents:(UIControlEventTouchUpInside)];

    // 视频信息
    _lblTitle           = [[UILabel alloc]init];
    _lblTitle.font      = [UIFont systemFontOfSize:14];
    _lblTitle.textColor = [UIColor whiteColor];
    _lblTitle.text      = self->_title;
    [_cover addSubview:_lblTitle];
    [_lblTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self->_btnBack.mas_right).offset(0);
        make.centerY.equalTo(self->_btnBack);
    }];

    // 音量控件--屏蔽系统音量改变提醒
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    volumeView.frame = CGRectMake(1000, 300, 100, 20);
    [self addSubview:volumeView];

    // 全屏按钮
    _btnFullScreen = [[ZSButton alloc]init];
    _btnFullScreen.tag = BTN_TAG_SCREEN;
    [_btnFullScreen setImage:[UIImage imageNamed:@"fullScreen"] forState:(UIControlStateNormal)];
    [_btnFullScreen setImage:[UIImage imageNamed:@"quiteScreen"] forState:(UIControlStateSelected)];
    [_cover addSubview:_btnFullScreen];
    [_btnFullScreen mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self->_cover);
        make.bottom.equalTo(self->_cover).offset(-15);
        make.width.height.mas_equalTo(50);
    }];
    [_btnFullScreen addTarget:self action:@selector(onBtnClick:) forControlEvents:(UIControlEventTouchUpInside)];

    // 视频当前时间
    _lblCurrentTime                 = [[UILabel alloc]init];
    _lblCurrentTime.font            = [UIFont systemFontOfSize:15];
    _lblCurrentTime.text            = @"00:00:00";
    _lblCurrentTime.textAlignment   = NSTextAlignmentLeft;
    _lblCurrentTime.textColor       = [UIColor whiteColor];
    [_cover addSubview:_lblCurrentTime];
    [_lblCurrentTime mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self->_cover).offset(10);
        make.centerY.equalTo(self->_btnFullScreen);
        make.width.mas_equalTo(65);
    }];

    // 视频总时长
    _lblTotalTime               = [[UILabel alloc]init];
    _lblTotalTime.font          = [UIFont systemFontOfSize:15];
    _lblTotalTime.text          = @"00:00:00";
    _lblTotalTime.textAlignment = NSTextAlignmentRight;
    _lblTotalTime.textColor     = [UIColor whiteColor];
    [_cover addSubview:_lblTotalTime];
    [_lblTotalTime mas_makeConstraints:^(MASConstraintMaker *make) {
        if (self->_btnFullScreen.hidden)
            make.right.equalTo(self->_cover).offset(-10);
        else
            make.right.equalTo(self->_btnFullScreen.mas_left);
        make.centerY.equalTo(self->_btnFullScreen);
        make.width.mas_equalTo(65);
    }];

    //缓冲进度条
    _progressView = [[UIProgressView alloc]init];
    [_cover addSubview:_progressView];
    _progressView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    [_progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self->_lblCurrentTime.mas_right).offset(5);
        make.right.equalTo(self->_lblTotalTime.mas_left).offset(-5);
        make.centerY.equalTo(self->_btnFullScreen);
    }];
    _progressView.tintColor = [UIColor whiteColor];
    [_progressView setProgress:0];

    //滑块
    _slider = [[UISlider alloc]init];
    _slider.userInteractionEnabled = YES;
    _slider.continuous = YES;//设置为NO,只有在手指离开的时候调用valueChange
    [_slider addTarget:self action:@selector(sliderValuechange:) forControlEvents:UIControlEventValueChanged];
    UITapGestureRecognizer *sliderTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(sliderTap:)];
    [_slider addGestureRecognizer:sliderTap];
    [_cover addSubview:_slider];
    [_slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self->_progressView);
        make.centerY.equalTo(self->_progressView).offset(-1);
    }];
    _slider.minimumTrackTintColor = [UIColor whiteColor];
    _slider.maximumTrackTintColor = [UIColor clearColor];
    UIImage *image = [self createImageWithColor:[UIColor whiteColor]];
    UIImage *circleImage = [self circleImageWithImage:image borderWidth:0 borderColor:[UIColor clearColor]];
    [_slider setThumbImage:circleImage forState:(UIControlStateNormal)];
    [self layoutIfNeeded];

    //播放按钮
    _btnPlay = [[ZSButton alloc]init];
    _btnPlay.tag = BTN_TAG_PLAY;
    [_cover addSubview:_btnPlay];
    [_btnPlay setImage:[UIImage imageNamed:@"pause"] forState:(UIControlStateNormal)];
    [_btnPlay setImage:[UIImage imageNamed:@"play"] forState:(UIControlStateSelected)];
    [_btnPlay addTarget:self action:@selector(onBtnClick:) forControlEvents:(UIControlEventTouchUpInside)];
    [_btnPlay mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.centerY.equalTo(self->_cover);
        make.width.height.mas_equalTo(100);
    }];

    // lock button
    _btnLock = [[ZSButton alloc]init];
    _btnLock.tag = BTN_TAG_LOCK;
    [_btnLock setImage:[UIImage imageNamed:@"lock"] forState:(UIControlStateNormal)];
    [_btnLock setImage:[UIImage imageNamed:@"lockSel"] forState:(UIControlStateSelected)];
    [_btnLock addTarget:self action:@selector(onBtnClick:) forControlEvents:(UIControlEventTouchUpInside)];
    [_cover addSubview:_btnLock];
    [_btnLock mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self->_btnPlay);
        make.left.equalTo(self->_btnBack).offset(4);
        make.width.height.mas_equalTo(40);
    }];

    //loading的位置用计算的...
    _loading = [[ZSLoading alloc]init];
    [_cover addSubview:_loading];
    [_loading mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.centerY.equalTo(self->_cover);
        make.width.height.mas_equalTo(100);

    }];
    [_cover layoutIfNeeded];
    _loading.frame = _loading.frame;

    _btnPlay.hidden         = YES;
    _lblTotalTime.hidden    = YES;
    _lblCurrentTime.hidden  = YES;
    _slider.hidden          = YES;
    _progressView.hidden    = YES;
}

#pragma mark -设置url

- (UIEdgeInsets)safeAreaInset
{
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone)
        return UIEdgeInsetsZero;

    if (@available(iOS 11.0, *))
        return [[[UIApplication sharedApplication] delegate] window].safeAreaInsets;

    return UIEdgeInsetsZero;
}

- (void)onStateChange {
    //移除加载条
    [_loading removeFromSuperview];
    _loading.animationStop = YES;

    //改变隐藏的状态
    if (self->_isVod)
    {
        _lblCurrentTime.hidden  = !_lblCurrentTime.hidden;
        _lblTotalTime.hidden    = !_lblTotalTime.hidden;
        _slider.hidden          = !_slider.hidden;
        _progressView.hidden    = !_progressView.hidden;
        _btnPlay.hidden         = !_progressView;
    }
}

- (void)onBtnClick:(UIButton *)button
{
    switch (button.tag)
    {
    case BTN_TAG_LOCK:
        {
            button.selected = !button.selected;
            for (UIView *view in _cover.subviews)
                view.alpha = (button.selected ? 0 : 1);
            button.alpha = 1;
            break;
        }

    case BTN_TAG_PLAY:
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCover) object:nil];

            button.selected = !button.selected;
            if (button.selected)
                [self.player pause];
            else
                [self.player play];

            [self performSelector:@selector(hideCover) withObject:nil afterDelay:4];
            break;
        }

    case BTN_TAG_SCREEN:
        {
            button.selected = !button.selected;
            if (button.selected)
                [self.player setScalingMode:IJKMPMovieScalingModeAspectFill];
            else
                [self.player setScalingMode:IJKMPMovieScalingModeAspectFit];
            break;
        }

    case BTN_TAG_BACK:
        {
            [_loading removeFromSuperview];
            _loading.animationStop = YES;

            if (self.delegate && [self.delegate respondsToSelector:@selector(onBackClick:)]) {
                [self.delegate onBackClick:button];
            }
            break;
        }

    default:
        break;
    }
}

#pragma mark -点击了playerView
- (void)playerViewTap:(UITapGestureRecognizer *)recognizer{

    //每次点击取消还在进程中的隐藏方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCover) object:nil];

    self->_hideTool = !self->_hideTool;

    [UIView animateWithDuration:0.25 animations:^{
        if (self->_hideTool)
            self.cover.alpha = 0;
        else
            self.cover.alpha = 1;
    } completion:^(BOOL finished) {
        if (self->_hideTool)
            self.cover.hidden = YES;
        else
        {
            self.cover.hidden = NO;
            [self performSelector:@selector(hideCover) withObject:nil afterDelay:4];
        }
    }];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[ZSButton class]])
        return NO;
    return YES;
}

#pragma mark - 隐藏 cover

- (void)hideCover {
    [UIView animateWithDuration:0.25 animations:^{
        self.cover.alpha =0 ;
    } completion:^(BOOL finished) {
        self.cover.hidden = YES;
        self->_hideTool = YES;
    }];
}

#pragma mark - touchBegan
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{

    self->_startP = [[touches anyObject] locationInView:self.playerView];

    if (!self->_hideTool)
        [self hideCover];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch * touch = [touches anyObject];
    CGPoint point   = [touch locationInView:self.playerView];
    CGFloat deltaY  = point.y - self->_startP.y;
    CGFloat volume  = [MPMusicPlayerController applicationMusicPlayer].volume;

    if (self->_startP.x > [UIScreen mainScreen].bounds.size.width / 2)
    {
        [[MPMusicPlayerController applicationMusicPlayer] setVolume:volume-deltaY/500];
        [self setupLayerLeft:NO];
    }
    else
    {
        CGFloat brightness = [UIScreen mainScreen].brightness;
        [[UIScreen mainScreen] setBrightness:brightness-deltaY/5000];
        [self setupLayerLeft:YES];
    }
}

//点击结束
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self->_layerContainer removeFromSuperlayer];
}

//点击取消
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self->_layerContainer removeFromSuperlayer];
}

#pragma mark-设置音量条,亮度条
- (void)setupLayerLeft:(BOOL)left{

    [self->_layerContainer removeFromSuperlayer];
    [self->_layer removeFromSuperlayer];
    self->_layerContainer = nil;
    self->_layer = nil;

    CGFloat volume = [MPMusicPlayerController applicationMusicPlayer].volume;
    CGFloat brightness = [UIScreen mainScreen].brightness;


    // 创建layer并设置属性
    self->_layerContainer              = [CAShapeLayer layer];
    self->_layerContainer.lineWidth    =  3;
    self->_layerContainer.strokeColor  = [[UIColor grayColor] colorWithAlphaComponent:0.2].CGColor;
    [self.playerView.layer addSublayer:self->_layerContainer];
    self->_layerContainer.strokeEnd    = 1;

    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint point = CGPointMake(left ? 29 : SCREEN_W - 29, self.playerView.center.y + 20);
    [path moveToPoint:point];
    [path addLineToPoint:CGPointMake(point.x, point.y-100)];
    self->_layerContainer.path = path.CGPath;

    // 创建layer并设置属性
    self->_layer               = [CAShapeLayer layer];
    self->_layer.fillColor     = [UIColor whiteColor].CGColor;
    self->_layer.lineWidth     = 3;
    self->_layer.lineCap       = kCALineCapRound;
    self->_layer.lineJoin      = kCALineJoinRound;
    self->_layer.strokeColor   = [UIColor whiteColor].CGColor;
    [self->_layerContainer addSublayer:self->_layer];
    self->_layer.strokeEnd     = left ? brightness : volume;
    self->_layer.path          = path.CGPath;
}

#pragma mark -点击滑块
- (void)sliderTap:(UITapGestureRecognizer *)tap{

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCover) object:nil];

    UISlider *slider = (UISlider *)tap.view;

    CGPoint point = [tap locationInView:_slider];

    [_slider setValue:point.x/_slider.bounds.size.width*1 animated:YES];

    _player.currentPlaybackTime = slider.value * _player.duration;

    [self performSelector:@selector(hideCover) withObject:nil afterDelay:4];
}

#pragma mark -滑块值发生改变
-(void)sliderValuechange:(UISlider *)sender {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCover) object:nil];
    _player.currentPlaybackTime = sender.value*_player.duration;
    [self performSelector:@selector(hideCover) withObject:nil afterDelay:4];
}

#pragma mark -更新方法
- (void)onTimer{

    _lblCurrentTime.text = [self formatTime:self.player.currentPlaybackTime];

    CGFloat current = self.player.currentPlaybackTime;
    CGFloat total   = self.player.duration;
    CGFloat able    = self.player.playableDuration;

    [_slider setValue:current/total animated:YES];
    [_progressView setProgress:able/total animated:YES];
}

#pragma mark-加载状态改变
- (void)loadStateDidChange:(NSNotification*)notification {
    IJKMPMovieLoadState loadState = _player.loadState;

    if ((loadState & IJKMPMovieLoadStatePlaythroughOK) != 0)
    {
        NSLog(@"LoadStateDidChange: IJKMovieLoadStatePlayThroughOK: %d\n",(int)loadState);
        _lblTotalTime.text =[NSString stringWithFormat:@"%@",[self formatTime:self.player.duration]];
    }
    else if ((loadState & IJKMPMovieLoadStateStalled) != 0)
    {
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStateStalled: %d\n", (int)loadState);
    }
    else
    {
        NSLog(@"loadStateDidChange: ???: %d\n", (int)loadState);
    }
}

#pragma mark-播放状态改变
- (void)moviePlayBackFinish:(NSNotification*)notification {
    int reason =[[[notification userInfo] valueForKey:IJKMPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    switch (reason)
    {
    case IJKMPMovieFinishReasonPlaybackEnded:
        NSLog(@"playbackStateDidChange: 播放完毕: %d\n", reason);
        break;

    case IJKMPMovieFinishReasonUserExited:
        NSLog(@"playbackStateDidChange: 用户退出播放: %d\n", reason);
        break;

    case IJKMPMovieFinishReasonPlaybackError:
        NSLog(@"playbackStateDidChange: 播放出现错误: %d\n", reason);
        #pragma mark-播放出现错误,需要添重新加载播放视频的按钮
        break;

    default:
        NSLog(@"playbackPlayBackDidFinish: ???: %d\n", reason);
        break;
    }
}

- (void)mediaIsPreparedToPlayDidChange:(NSNotification*)notification {
    NSLog(@"mediaIsPrepareToPlayDidChange\n");

    [_placeHolderImgView removeFromSuperview];
    [self onStateChange];
}

- (void)moviePlayBackStateDidChange:(NSNotification*)notification {

    if (self.player.playbackState == IJKMPMoviePlaybackStatePlaying)
    {
        //视频开始播放的时候开启计时器
        self->_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
        [self performSelector:@selector(hideCover) withObject:nil afterDelay:4];
    }

    switch (_player.playbackState)
    {
    case IJKMPMoviePlaybackStateStopped:
        NSLog(@"IJKMPMoviePlayBackStateDidChange %d: stoped", (int)_player.playbackState);

        [self.player shutdown];
        self.player = nil;

        self.player = [[IJKFFMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:self->_url] withOptions:nil];
        [self.player prepareToPlay];
        [self.player play];

        break;

    case IJKMPMoviePlaybackStatePlaying:
        NSLog(@"IJKMPMoviePlayBackStateDidChange %d: playing", (int)_player.playbackState);
        break;

    case IJKMPMoviePlaybackStatePaused:
        NSLog(@"IJKMPMoviePlayBackStateDidChange %d: paused", (int)_player.playbackState);
        break;

    case IJKMPMoviePlaybackStateInterrupted:
        NSLog(@"IJKMPMoviePlayBackStateDidChange %d: interrupted", (int)_player.playbackState);
        break;

    case IJKMPMoviePlaybackStateSeekingForward:
    case IJKMPMoviePlaybackStateSeekingBackward:
        {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: seeking", (int)_player.playbackState);
            break;
        }

    default:
        {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: unknown", (int)_player.playbackState);
            break;
        }
    }
}

#pragma mark-观察视频播放状态
- (void)installMovieNotificationObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadStateDidChange:)
                                                 name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                               object:_player];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackFinish:)
                                                 name:IJKMPMoviePlayerPlaybackDidFinishNotification
                                               object:_player];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaIsPreparedToPlayDidChange:)
                                                 name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                               object:_player];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackStateDidChange:)
                                                 name:IJKMPMoviePlayerPlaybackStateDidChangeNotification
                                               object:_player];
}

- (void)removeMovieNotificationObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMoviePlayerPlaybackDidFinishNotification
                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMoviePlayerPlaybackStateDidChangeNotification
                                                  object:_player];
}

#pragma mark-公共方法
- (NSString *)formatTime:(NSInteger)seconds
{
    // format of hour
    NSString *str_hour = [NSString stringWithFormat:@"%02ld",seconds/3600];
    // format of minute
    NSString *str_minute = [NSString stringWithFormat:@"%02ld",(seconds%3600)/60];
    // format of second
    NSString *str_second = [NSString stringWithFormat:@"%02ld",seconds%60];
    // format of time
    NSString *format_time = [NSString stringWithFormat:@"%@:%@:%@",str_hour,str_minute,str_second];
    return format_time;
}

- (UIImage *)createImageWithColor:(UIColor*) color
{
    CGRect rect = CGRectMake(0,0,15,15);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}

- (UIImage *)circleImageWithImage:(UIImage *)oldImage borderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor
{
    // 1.加载原图
    // 2.开启上下文
    CGFloat imageW = oldImage.size.width + 22 * borderWidth;
    CGFloat imageH = oldImage.size.height + 22 * borderWidth;
    CGSize imageSize = CGSizeMake(imageW, imageH);
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0);

    // 3.取得当前的上下文,这里得到的就是上面刚创建的那个图片上下文
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // 4.画边框(大圆)
    [borderColor set];
    CGFloat bigRadius = imageW * 0.5; // 大圆半径
    CGFloat centerX   = bigRadius; // 圆心
    CGFloat centerY   = bigRadius;
    CGContextAddArc(ctx, centerX, centerY, bigRadius, 0, M_PI * 2, 0);
    CGContextFillPath(ctx); // 画圆。As a side effect when you call this function, Quartz clears the current path.

    // 5.小圆
    CGFloat smallRadius = bigRadius - borderWidth;
    CGContextAddArc(ctx, centerX, centerY, smallRadius, 0, M_PI * 2, 0);
    // 裁剪(后面画的东西才会受裁剪的影响)
    CGContextClip(ctx);

    // 6.画图
    [oldImage drawInRect:CGRectMake(borderWidth, borderWidth, oldImage.size.width, oldImage.size.height)];

    // 7.取图
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();

    // 8.结束上下文
    UIGraphicsEndImageContext();

    return newImage;
}

@end
