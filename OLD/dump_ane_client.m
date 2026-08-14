#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

int main() {
    void *ane_framework = dlopen("/System/Library/PrivateFrameworks/AppleNeuralEngine.framework/AppleNeuralEngine", RTLD_NOW);
    if (!ane_framework) {
        printf("Failed to load AppleNeuralEngine framework\n");
        return 1;
    }
    
    Class ANEClientClass = NSClassFromString(@"_ANEClient");
    if (!ANEClientClass) {
        printf("_ANEClient class not found\n");
        return 1;
    }
    
    unsigned int count;
    Method *methods = class_copyMethodList(ANEClientClass, &count);
    printf("Instance methods for _ANEClient:\n");
    for (unsigned int i = 0; i < count; i++) {
        printf("- %s\n", sel_getName(method_getName(methods[i])));
    }
    free(methods);
    
    methods = class_copyMethodList(object_getClass(ANEClientClass), &count);
    printf("\nClass methods for _ANEClient:\n");
    for (unsigned int i = 0; i < count; i++) {
        printf("+ %s\n", sel_getName(method_getName(methods[i])));
    }
    free(methods);
    
    return 0;
}
