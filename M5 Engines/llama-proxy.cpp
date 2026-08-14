#include <iostream>
#include <vector>
#include <string>
#include <unistd.h>
#include <limits.h>
#include <mach-o/dyld.h>

int main(int argc, char* argv[]) {
    std::vector<char*> args;
    
    char path[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0) {
        std::cerr << "[M5 Ultimate] Proxy failed to get executable path." << std::endl;
        return 1;
    }
    
    std::string orig_bin = std::string(path) + ".ane";
    
    args.push_back(const_cast<char*>(orig_bin.c_str()));
    
    bool has_tensor_split = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--tensor-split" || arg == "-ts") {
            has_tensor_split = true;
        }
        args.push_back(argv[i]);
    }
    
    // M5 Ultimate: ANE + GPU için tensor split argümanını ekle
    if (!has_tensor_split) {
        std::cout << "[M5 Ultimate] Injecting --tensor-split for ANE+GPU routing." << std::endl;
        args.push_back(const_cast<char*>("--tensor-split"));
        args.push_back(const_cast<char*>("18,20"));
    }
    
    args.push_back(nullptr);
    
    execv(orig_bin.c_str(), args.data());
    
    perror("[M5 Ultimate] execv failed");
    return 1;
}
