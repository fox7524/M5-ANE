#include <iostream>
#include <vector>
#include <string>
#include <unistd.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdlib.h>

// ==============================================================================
// M5 ULTIMATE PROXY EXECUTABLE
// Launcher for Heterogeneous Asynchronous Pipelining & Zero-Copy God-Mode
// ==============================================================================

int main(int argc, char* argv[]) {
    std::cout << "========================================================" << std::endl;
    std::cout << "🚀 M5 ULTIMATE ENGINE INITIATED" << std::endl;
    std::cout << "Architecture: Heterogeneous Pipelining + Zero-Copy" << std::endl;
    std::cout << "========================================================" << std::endl;

    std::vector<char*> args;
    
    // Get the path of this proxy executable
    char path[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0) {
        std::cerr << "[M5 Ultimate] Proxy failed to get executable path." << std::endl;
        return 1;
    }
    
    std::string current_path = std::string(path);
    std::string base_dir = current_path.substr(0, current_path.find_last_of("/"));
    
    // The original engine binary is renamed to .orig
    std::string orig_bin = current_path + ".orig";
    
    // Path to our God-Mode Interceptor Dylib
    std::string interceptor_dylib = base_dir + "/m5_godmode_interceptor.dylib";
    
    // Set up DYLD_INSERT_LIBRARIES to inject our Metal/IOSurface hooks
    setenv("DYLD_INSERT_LIBRARIES", interceptor_dylib.c_str(), 1);
    
    // Optional: We can also add tensor-split just in case the original binary still relies on it 
    // for initial memory allocation partitioning, though our interceptor overrides dispatching.
    
    args.push_back(const_cast<char*>(orig_bin.c_str()));
    
    bool has_tensor_split = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--tensor-split" || arg == "-ts") {
            has_tensor_split = true;
        }
        args.push_back(argv[i]);
    }
    
    // Still pass 18,20 so llama.cpp allocates buffers on both devices initially,
    // which our Zero-Copy allocator will then convert to IOSurface shared memory.
    if (!has_tensor_split) {
        std::cout << "[M5 Ultimate] Injecting baseline --tensor-split 18,20 for memory partitioning." << std::endl;
        args.push_back(const_cast<char*>("--tensor-split"));
        args.push_back(const_cast<char*>("18,20"));
    }
    
    args.push_back(nullptr);
    
    // Execute the original binary. The OS will automatically load m5_godmode_interceptor.dylib
    std::cout << "[M5 Ultimate] Executing Native Engine with God-Mode Interceptor..." << std::endl;
    execv(orig_bin.c_str(), args.data());
    
    perror("[M5 Ultimate] execv failed");
    return 1;
}
