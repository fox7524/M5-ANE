#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLMEngine : NSObject

- (BOOL)loadModelAtPath:(NSString *)path gpuLayers:(int)gpuLayers;
- (void)generateResponseForPrompt:(NSString *)prompt onToken:(void (^)(NSString *token))onToken onComplete:(void (^)(void))onComplete;
- (void)unloadModel;

@end

NS_ASSUME_NONNULL_END
