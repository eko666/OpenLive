#import "PlayViewController.h"

#import "ZSPlayerView.h"

@interface PlayViewController ()<ZSPlayerDelegate>

@property (nonatomic, strong)ZSPlayerView *playerView;

@end

@implementation PlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.navigationController.navigationBarHidden = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStatusBarOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];

    self.playerView          = [[ZSPlayerView alloc]initWithFrame: CGRectMake(0, 0, SCREEN_W, SCREEN_H)];
    self.playerView.delegate = self;
    self.playerView.url      = self.url;
    self.playerView.title    = self.title;
    self.playerView.isVod    = self.isVod;

    [self.playerView setup];

    [self.view addSubview:self.playerView];
}

#pragma mark -与全屏相关的代理方法等

- (void)onStatusBarOrientationChanged:(NSNotification *)notification
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

    if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft)
    {
        // home in right
        [UIView animateWithDuration:0.25 animations:^{
            self.playerView.frame = CGRectMake(0, 0, SCREEN_W, SCREEN_H);
            self.playerView.player.view.frame = CGRectMake(0, 0, SCREEN_W, SCREEN_H);
        }];
    }
    else if (orientation == UIInterfaceOrientationPortrait)
    {
        [UIView animateWithDuration:0.25 animations:^{
            self.playerView.transform = CGAffineTransformMakeRotation(0);
            self.playerView.frame = CGRectMake(0, 0, SCREEN_W, SCREEN_H);
            self.playerView.player.view.frame = self.playerView.frame;
        }];
    }
}

- (void)onBackClick:(UIButton *)button {
    [self.playerView.player shutdown];
    self.playerView = nil;
    [self dismissViewControllerAnimated:YES completion:^{}];
}

-(void)dealloc {
    [self.playerView.player shutdown];
    self.playerView = nil;
}

@end
