#import <UIKit/UIKit.h>

@interface UIColor (HEX)

+ (UIColor *) colorWithHexString: (NSString *)color;
+ (UIColor *) colorWithHex:(NSInteger)hexValue alpha:(CGFloat)alphaValue;

@end
