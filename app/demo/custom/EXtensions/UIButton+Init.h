#import <UIKit/UIKit.h>

@interface UIButton (Init)
+ (UIButton *)buttonWithnormalImg:(UIImage *)normalImg selectedImg:(UIImage *)selectedImg selector:(SEL)selector target:(id)target;

+ (UIButton *)buttonWithnormalImg:(UIImage *)normalImg highlightedImg:(UIImage *)highlightedImg selector:(SEL)selector target:(id)target;

+ (UIButton *)buttonWithNormalImg:(UIImage *)normalImg withSelector:(SEL)selector withTarget:(id)target;
@end
