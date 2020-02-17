#import <UIKit/UIKit.h>
#import "NYPopover.h"

@interface NYSliderPopover : UISlider

@property (nonatomic, strong) NYPopover *popover;
@property (nonatomic ,assign)CGFloat originX;
- (void)showPopover;
- (void)showPopoverAnimated:(BOOL)animated;
- (void)hidePopover;
- (void)hidePopoverAnimated:(BOOL)animated;
@end
