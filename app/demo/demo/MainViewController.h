#import <UIKit/UIKit.h>

@interface MainViewController : UIViewController

@end

@interface ChannelCell : UITableViewCell

@property (nonatomic, copy)UIImage  *image;
@property (nonatomic, copy)NSString *title;
@property (nonatomic)      int       crypto;
@property (nonatomic, copy)NSString *type;

@end
