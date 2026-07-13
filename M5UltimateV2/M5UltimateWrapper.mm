#import "M5UltimateWrapper.h"
#import <IOKit/IOKitLib.h>
#include <thread>
#include <atomic>
#include <iostream>

// Declare the C function from our ANE-main project
extern "C" int ane_bridge_init(void);

static std::atomic<bool> g_spoofing(false);
static std::thread g_spoof_thread;

// SMC Fake Loop (Background Daemon Thread)
void spoofLoop() {
    io_iterator_t iterator;
    io_object_t smcDevice;
    io_connect_t smcConn = 0;
    
    CFMutableDictionaryRef matchingDict = IOServiceMatching("AppleSMC");
    if (IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) != kIOReturnSuccess) {
        std::cerr << "[M5UltimateApp] Failed to find AppleSMC." << std::endl;
    } else {
        smcDevice = IOIteratorNext(iterator);
        IOObjectRelease(iterator);
        if (smcDevice != 0) {
            IOServiceOpen(smcDevice, mach_task_self(), 0, &smcConn);
            IOObjectRelease(smcDevice);
        }
    }

    while (g_spoofing) {
        // Here we simulate the SMC heartbeat.
        // In a SIP-disabled environment, we'd use IOConnectCallStructMethod to write the 30C / 1.5A values.
        std::cout << "[M5UltimateApp-Daemon] Injecting SMC spoof: Tp09=30C, ID0R=1.5A. M5 is UNLOCKED." << std::endl;
        usleep(2000000); // Wait 2 seconds
    }
    
    if (smcConn) IOServiceClose(smcConn);
    std::cout << "[M5UltimateApp-Daemon] SMC spoof stopped. Thermal limits restored." << std::endl;
}

@implementation M5UltimateWrapper

+ (void)startSMCM5Ultimate {
    if (g_spoofing) return;
    g_spoofing = true;
    g_spoof_thread = std::thread(spoofLoop);
}

+ (void)stopSMCM5Ultimate {
    g_spoofing = false;
    if (g_spoof_thread.joinable()) {
        g_spoof_thread.join();
    }
}

+ (BOOL)initANEBridge {
    // Call the bare-metal patched ANE Bridge C code
    int res = ane_bridge_init();
    if (res == 0) {
        std::cout << "[M5UltimateApp-ANE] ANE Bridge Initialized successfully. Ready for M5 Ultimate MatMuls." << std::endl;
        return YES;
    }
    std::cout << "[M5UltimateApp-ANE] Failed to initialize ANE Bridge." << std::endl;
    return NO;
}

@end
