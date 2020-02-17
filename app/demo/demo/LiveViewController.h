#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, RecognizeSegment)
{
    RecognizeSegment_Min,
    RecognizeSegment_Mid,
    RecognizeSegment_Max,
};

typedef NS_ENUM(NSUInteger, FpsSegment)
{
    FpsSegment_15th,
    FpsSegment_25th,
    FpsSegment_30th,
    FpsSegment_50th,
    FpsSegment_60th,
};

@interface LiveViewController : UIViewController

@end
