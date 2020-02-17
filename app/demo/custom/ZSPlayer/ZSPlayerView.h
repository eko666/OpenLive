#import <UIKit/UIKit.h>
#import <IJKMediaFramework/IJKMediaFramework.h>

#define SCREEN_W [UIScreen mainScreen].bounds.size.width
#define SCREEN_H [UIScreen mainScreen].bounds.size.height

@protocol ZSPlayerDelegate <NSObject>

- (void)onBackClick:(UIButton *)button;

@end

@interface ZSPlayerView : UIView

@property (nonatomic, strong) IJKFFMoviePlayerController *player;

@property (nonatomic, strong) id<ZSPlayerDelegate> delegate;

@property (nonatomic, copy) NSString *url;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL    isVod;

-(instancetype)initWithFrame:(CGRect)frame;

-(void)setup;

@end
