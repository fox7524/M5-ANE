#import <Foundation/Foundation.h>

@interface GodModeWrapper : NSObject

// SMC Spoofing (Thermal limit bypass)
+ (void)startSMCGodMode;
+ (void)stopSMCGodMode;

// ANE Bridge (Bare-metal memory mapping)
+ (BOOL)initANEBridge;

@end
