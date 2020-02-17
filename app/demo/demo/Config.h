#import <UIKit/UIKit.h>
#import "LiveViewController.h"
#import "NYSliderPopover.h"
//#import <OpenLiveKit/configuration/LFLiveVideoConfiguration.h>

@protocol setDelegate <NSObject>

- (void)setDelegate:(UIView *)set withRecognize:(NSInteger)recognize;
//- (void)setDelegate:(UIView *)set withFps:(NSInteger)fps withFpsENUM:(FpsSegment)segment;
- (void)setDelegate:(UIView *)set withRate:(NSInteger)rate;

@end

@interface Config : UIView

@property (nonatomic, assign)NSInteger rateValue ;

@property (nonatomic, strong)NYSliderPopover *rate;

@property (nonatomic, strong)id<setDelegate> delegate;

@end
