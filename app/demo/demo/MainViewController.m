#import "MainViewController.h"
#import "LiveViewController.h"
#import "UIViewExt.h"
#import "UIButton+Init.h"
#import "OrientationControl.h"
#import "LivePrefixHeader.pch"
#import "Masonry.h"
#import "MJRefresh.h"
#import "PlayViewController.h"

#import <Proxier.h>

#define BTN_TAG_LIVE    100
#define BTN_TAG_BACK    101

@interface MainViewController () <UITableViewDataSource, UITableViewDelegate>
{
    UIView   *_topBGView;           // 顶部背景图
    UIButton *_setButton;           // 返回按钮
    UIButton *_liveButton;          // 直播按钮
    UILabel  *_titleLable;
    UIImage  *_listImage;
    BOOL      _refrash;

    void     *_proxier;
    int       _port;
}

@property (strong,nonatomic) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation MainViewController

- (UIEdgeInsets)safeAreaInset
{
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone)
        return UIEdgeInsetsZero;

    if (@available(iOS 11.0, *))
        return [[[UIApplication sharedApplication] delegate] window].safeAreaInsets;

    return UIEdgeInsetsZero;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [OrientationControl setOrientationMaskPortrait];

    [self loadChannels];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _refrash = NO;
    _listImage = [UIImage imageNamed:LiveImageName(@"header")];

    float  offset = 0.0f;
    UIEdgeInsets safeAreaInsets = [self safeAreaInset];
    // if (safeAreaInsets.bottom > 0.0f)
    offset = safeAreaInsets.top;

    [self initUI:offset];
    [self initMenuTop];
    [self layoutMenuTop:offset];

    self->_proxier = proxier_open(self->_port);
    if (self->_proxier == NULL)
    {
        NSLog(@"proxier open failed.");
    }
    else
        self->_port = proxier_get_listen_port(self->_proxier);
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    if (self->_proxier != NULL)
        proxier_close(self->_proxier);
    self->_proxier = NULL;
}

#pragma mark - handle UI

- (void)initUI:(int)offset
{
    self.view.backgroundColor = [UIColor whiteColor];

    CGRect r = CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y + offset + 39, self.view.bounds.size.width, self.view.bounds.size.height - offset - 39);

    self.tableView = [[UITableView alloc] initWithFrame:r style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.delegate        = self;
    self.tableView.dataSource      = self;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 0, 0)];

    MJRefreshNormalHeader *header = [[MJRefreshNormalHeader alloc] init];
    [header setRefreshingTarget:self refreshingAction:@selector(reloadChannels)];
    self.tableView.mj_header = header;

    [self.view addSubview:self.tableView];
}

- (void)initMenuTop
{
    _topBGView                 = [[UIView alloc] init];
    _topBGView.backgroundColor = [UIColor colorWithRed:64/255.0 green:180/255.0 blue:255/255.0 alpha:1.0];;
    _topBGView.alpha           = 0.8;
    [self.view addSubview:_topBGView];

    // setting button
    _setButton = [UIButton buttonWithnormalImg:[UIImage imageNamed:LiveImageName(@"set")]
                                                    highlightedImg:[UIImage imageNamed:LiveImageName(@"set")]
                                      selector:@selector(onMenuClick:)
                                        target:self];
    _setButton.tag = BTN_TAG_BACK;
     [self.view addSubview:_setButton];

    // live buttong
    _liveButton = [UIButton buttonWithnormalImg:[UIImage imageNamed:LiveImageName(@"photo")]
                                                     highlightedImg:[UIImage imageNamed:LiveImageName(@"photo")]
                                       selector:@selector(onMenuClick:)
                                         target:self];
    _liveButton.tag = BTN_TAG_LIVE;
    [self.view addSubview:_liveButton];

    // Title
    _titleLable                      = [[UILabel alloc] init];
    _titleLable.text                 = @"直播列表";
    _titleLable.textAlignment        = NSTextAlignmentCenter;
    _titleLable.textColor            = [UIColor whiteColor];
    _titleLable.font                 = [UIFont systemFontOfSize:20];

    [self.view addSubview:_titleLable];
}

- (void)layoutMenuTop:(int)offset
{
    [_topBGView mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(IphoneWidth, 40 + offset));
            make.left.equalTo(self.view.mas_left).with.offset(0);
            make.top.equalTo(self.view.mas_top).with.offset(0);
        }
    ];

    [_liveButton mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(60, 40));
            make.bottom.equalTo(self->_topBGView.mas_bottom);//.with.offset(-2);
            make.left.equalTo(self->_topBGView.mas_left);
        }
    ];

    [_setButton mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(60, 40));
            make.centerY.equalTo(self->_liveButton.mas_centerY);
            make.right.equalTo(self->_topBGView.mas_right);
        }
    ];

    [_titleLable mas_makeConstraints: ^ (MASConstraintMaker * make)
        {
            make.size.mas_equalTo(CGSizeMake(100, 30));
            make.centerY.equalTo(self->_liveButton.mas_centerY);
            make.centerX.equalTo(self.view.mas_centerX);
        }
    ];
}

#pragma mark - handle data.

- (void)loadChannels
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *server = [defaults objectForKey:@"msm"];
    if (server == NULL || server == nil)
        server = @"192.168.31.250:7507";

    NSString *url = [NSString stringWithFormat:@"http://%@/api/v1/channels", server];

    NSURLSession *session = [NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];

    __weak typeof (self)_self = self;

    void (^onFinish)(NSData *data, NSURLResponse *response, NSError *error) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSMutableArray *arr = [NSMutableArray array];

        if (error)
            NSLog(@"Error :%@", error.localizedDescription);
        else
        {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];

            [json enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop){
                if ([key isEqualToString:@"data"])
                {
                    *stop = YES;
                    [obj enumerateKeysAndObjectsUsingBlock:^(NSString *key1, id obj1, BOOL *stop1){
                        if ([key1 isEqualToString:@"servers"])
                        {
                            *stop1 = YES;
                            for (int i = 0; i < [obj1 count]; i++)
                            {
                                NSArray *channels = obj1[i][@"channels"];
                                for (int j = 0; j < [channels count]; j++)
                                    [arr addObject:channels[j]];
                            }
                        }
                    }];
                }
            }];
        }
        [_self performSelectorOnMainThread:@selector(onDataSourceLoad:) withObject:arr waitUntilDone:YES];
    };

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:onFinish];

    [task resume];
}

- (void)reloadChannels
{
    NSLog(@"reload channenls");

    _refrash = YES;
    [self loadChannels];
}

- (void)showPlayer:(NSString *)url title:(NSString *)title isVod:(BOOL)isVod
{
    PlayViewController *view    = [[PlayViewController alloc] init];
    view.url                    = url;
    view.title                  = title;
    view.isVod                  = isVod;
    view.modalPresentationStyle = UIModalPresentationOverCurrentContext & UIModalPresentationOverFullScreen;
    [self presentViewController:view animated:NO completion:nil];
}

- (void)playChannel:(id)channel
{
    __block NSString *url = channel[@"url"];
    NSString *tmp = channel[@"type"];

    BOOL vod = [tmp isEqualToString:@"vod"];

    int flags = (int)[channel[@"flags"] integerValue];
    if (flags & 0x01)
    {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:@"请输入密码" preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UITextField *txtPwd = alertController.textFields.firstObject;

            const char *ptr  = [url cStringUsingEncoding:NSASCIIStringEncoding];
            int   len  = (int)[url length];
            int   size = len * 2 + 2;
            char *buf  = (char *)malloc(size);

            int ret = proxier_hexstr(ptr, len, buf, size);
            if (ret < 0)
            {
                NSLog(@"proxier_hexstr failed.");
                free(buf);
            }
            else
            {
                if (vod)
                    url = [NSString stringWithFormat:@"http://127.0.0.1:%d/?u=0x%s&k=%@&t=vod", self->_port, buf, txtPwd.text];
                else
                    url = [NSString stringWithFormat:@"http://127.0.0.1:%d/?u=0x%s&k=%@", self->_port, buf, txtPwd.text];
                free(buf);

                [self showPlayer:url title:channel[@"id"] isVod:vod];
            }
        }]];

        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil]];

        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"请输入密码";
            textField.text = @"12345678";
        }];

        [self presentViewController:alertController animated:true completion:nil];
    }
    else
    {
        if (vod)
            [self showPlayer:url title:channel[@"id"] isVod:vod];
        else
        {
            const char *ptr  = [url cStringUsingEncoding:NSASCIIStringEncoding];
            int   len  = (int)[url length];
            int   size = len * 2 + 2;
            char *buf  = (char *)malloc(size);

            int ret = proxier_hexstr(ptr, len, buf, size);
            if (ret < 0)
            {
                NSLog(@"proxier_hexstr failed.");
                free(buf);
            }
            else
            {
                url = [NSString stringWithFormat:@"http://127.0.0.1:%d/?u=0x%s", self->_port, buf];
                free(buf);

                [self showPlayer:url title:channel[@"id"] isVod:vod];
            }
        }
    }
}

- (void)onDataSourceLoad:(NSArray *)data {

    [self.dataSource removeAllObjects];
    [self.dataSource addObjectsFromArray:data];

    [self.tableView reloadData];

    if (_refrash)
    {
        _refrash = NO;
        [self.tableView.mj_header endRefreshing];
    }
}

#pragma mark - UI Action.

- (void)onMenuClick:(UIButton *)button
{
    if (button.tag == BTN_TAG_BACK)
    {
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];

        if ([[UIApplication sharedApplication] canOpenURL:url])
            [[UIApplication sharedApplication] openURL:url];
    }
    else if (button.tag == BTN_TAG_LIVE)
    {
        LiveViewController *live = [[LiveViewController alloc] init];
        live.title = @"直播回传";
        live.modalPresentationStyle = UIModalPresentationOverCurrentContext & UIModalPresentationOverFullScreen;
        [self presentViewController:live animated:NO completion:nil];
    }
}

#pragma mark - for table view.

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_dataSource != nil && [_dataSource count] != 0)
        return _dataSource.count;
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"channelcell";

    if (_dataSource == nil || [_dataSource count] == 0)
    {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"emptycell"];
        if (cell == nil)
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"emptycell"];

        cell.textLabel.text = @"没有直播，你来一个试试 ^_^ ";
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    ChannelCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
        cell = [[ChannelCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];

    id channel = [_dataSource objectAtIndex:indexPath.row];

    cell.title  = channel[@"id"];
    cell.type   = channel[@"type"];
    cell.crypto = [channel[@"flags"] intValue];
    cell.image  = _listImage;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (_dataSource == nil || [_dataSource count] == 0)
        return;

    id channel = [_dataSource objectAtIndex:indexPath.row];
    [self playChannel:channel];
}

- (NSMutableArray *)dataSource {
    if (_dataSource == nil)
        _dataSource = [NSMutableArray array];

    return _dataSource;
}

#pragma mark - Other UI event.

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end

@implementation ChannelCell
{
    UIImageView *iconView;
    UILabel *titleLabel;
    UILabel *cryptoLabel;
    UILabel *typeLabel;
    UIView  *lineLabel;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        iconView = [[UIImageView alloc] init];
        [self.contentView addSubview:iconView];

        titleLabel = [[UILabel alloc] init];
        [self.contentView addSubview:titleLabel];

        cryptoLabel                 = [[UILabel alloc] init];
        cryptoLabel.font            = [UIFont systemFontOfSize:13];
        cryptoLabel.textColor       = [UIColor grayColor];
        [self.contentView addSubview:cryptoLabel];

        typeLabel                   = [[UILabel alloc] init];
        typeLabel.font              = [UIFont systemFontOfSize:13];
        typeLabel.textColor         = [UIColor grayColor];
        [self.contentView addSubview:typeLabel];

        lineLabel                   = [[UIView alloc] init];
        lineLabel.backgroundColor   = [UIColor grayColor];
        lineLabel.alpha             = 0.3;
        [self.contentView addSubview:lineLabel];
    }

    return self;
}

- (void)layoutSubviews {
    iconView.layer.masksToBounds = YES;
    iconView.layer.cornerRadius = 10;

    [iconView mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(54, 54));
            make.centerY.equalTo(self.mas_centerY).with.offset(-2);
            make.left.equalTo(self.mas_left).with.offset(20);
        }
    ];

    [titleLabel mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(270, 25));
            make.top.equalTo(self.mas_top).with.offset(13);
            make.left.equalTo(self->iconView.mas_right).with.offset(16);
        }
    ];

    [typeLabel mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(40, 20));
            make.bottom.equalTo(self.mas_bottom).with.offset(-10);
            make.left.equalTo(self->iconView.mas_right).with.offset(16);
        }
    ];

    [cryptoLabel mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(70, 20));
            make.bottom.equalTo(self.mas_bottom).with.offset(-10);
            make.left.equalTo(self->typeLabel.mas_right).with.offset(5);
        }
    ];

    [lineLabel mas_makeConstraints: ^ (MASConstraintMaker *make)
        {
            make.size.mas_equalTo(CGSizeMake(self.width - 20, 0.5));
            make.bottom.equalTo(self.mas_bottom).with.offset(0);
            make.left.equalTo(self.mas_left).with.offset(20);
        }
    ];

    CGRect frame = CGRectMake(0, 0, self.contentView.frame.size.width , self.contentView.frame.size.height - 1);
    UIColor *color = [[UIColor alloc]initWithRed:135/255.0 green:206/255.0 blue:235/250.0 alpha:0.3];
    self.selectedBackgroundView = [[UIView alloc] initWithFrame:frame];
    self.selectedBackgroundView.backgroundColor = color;
}

- (void)setImage:(UIImage *)image{
    iconView.image = image;
}

- (void)setTitle:(NSString *)text{
    titleLabel.text = text;
}

- (void)setCrypto:(int)value{
    if (value & 0x01)
        cryptoLabel.text = @"已加密";
    else
        cryptoLabel.text = @"未加密";
}

- (void)setType:(NSString *)text{

    if ([text isEqualToString:@"vod"])
        typeLabel.text = @"点播";
    else
        typeLabel.text = @"直播";
}

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

@end
