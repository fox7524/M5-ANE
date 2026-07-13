#import <Foundation/Foundation.h>

@interface M5UltimateWrapper : NSObject

// SMC Spoofing (Thermal limit bypass)
+ (void)startSMCM5Ultimate;
+ (void)stopSMCM5Ultimate;

// ANE Bridge (Bare-metal memory mapping)
+ (BOOL)initANEBridge;

@end
