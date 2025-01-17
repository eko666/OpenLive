#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MTBlockAlertView : UIAlertView <UIAlertViewDelegate>

#pragma mark UIAlertViewDelegate methods (optional)

@property (nonatomic, strong) void (^clickedButtonAtIndexBlock)(UIAlertView *alertView, NSInteger buttonIndex);
@property (nonatomic, strong) void (^didDismissWithButtonIndexBlock)(UIAlertView *alertView, NSInteger buttonIndex);
@property (nonatomic, strong) void (^willDismissWithButtonIndexBlock)(UIAlertView *alertView, NSInteger buttonIndex);
@property (nonatomic, strong) void (^cancelBlock)(UIAlertView *alertView);

#pragma mark Convenience Methods

- (id)initWithTitle:(NSString *)title
            message:(NSString *)message
  completionHanlder:(void(^)(UIAlertView *alertView, NSInteger buttonIndex))theHandler
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (void) showWithTitle:(NSString *)title
               message:(NSString *)message
     cancelButtonTitle:(NSString *)cancelButtonTitle
      otherButtonTitle:(NSString *)otherButtonTitle
        alertViewStyle:(UIAlertViewStyle)alertViewStyle
       completionBlock:(void (^)(UIAlertView *alertView, NSInteger buttonIndex))completionBlock;

+ (void) showWithTitle:(NSString *)title message:(NSString *)message completionBlock:(void (^)(UIAlertView *alertView))completionBlock;

+ (void) showWithTitle:(NSString *)title message:(NSString *)message;

@end
