#import "LLMEngine.h"
#import "llama.h"
#include <vector>
#include <string>

@interface LLMEngine () {
    struct llama_model * model;
    struct llama_context * ctx;
    struct llama_sampler * smpl;
}
@end

@implementation LLMEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        llama_backend_init();
    }
    return self;
}

- (void)dealloc {
    [self unloadModel];
    llama_backend_free();
}

- (BOOL)loadModelAtPath:(NSString *)path gpuLayers:(int)gpuLayers {
    [self unloadModel];
    
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = gpuLayers;
    
    model = llama_model_load_from_file([path UTF8String], model_params);
    if (!model) {
        NSLog(@"[LLMEngine] Failed to load model at %@", path);
        return NO;
    }
    
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 4096;
    ctx_params.n_threads = 8;
    ctx_params.n_threads_batch = 8;
    
    ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        NSLog(@"[LLMEngine] Failed to create context");
        return NO;
    }
    
    // Create a greedy sampler
    smpl = llama_sampler_init_greedy();
    
    NSLog(@"[LLMEngine] Model loaded successfully");
    return YES;
}

- (void)generateResponseForPrompt:(NSString *)prompt onToken:(void (^)(NSString *))onToken onComplete:(void (^)(void))onComplete {
    if (!model || !ctx) {
        onComplete();
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 1. Tokenize prompt
        std::vector<llama_token> tokens(prompt.length + 4);
        int32_t n_tokens = llama_tokenize(llama_model_get_vocab(self->model), [prompt UTF8String], (int32_t)prompt.length, tokens.data(), (int32_t)tokens.size(), true, true);
        if (n_tokens < 0) {
            tokens.resize(-n_tokens);
            n_tokens = llama_tokenize(llama_model_get_vocab(self->model), [prompt UTF8String], (int32_t)prompt.length, tokens.data(), (int32_t)tokens.size(), true, true);
        }
        tokens.resize(n_tokens);
        
        // 2. Decode prompt
        struct llama_batch batch = llama_batch_get_one(tokens.data(), (int32_t)tokens.size());
        if (llama_decode(self->ctx, batch)) {
            NSLog(@"[LLMEngine] llama_decode() failed");
            dispatch_async(dispatch_get_main_queue(), ^{ onComplete(); });
            return;
        }
        
        // 3. Generate tokens
        int max_tokens = 512;
        int n_generated = 0;
        
        while (n_generated < max_tokens) {
            llama_token new_token_id = llama_sampler_sample(self->smpl, self->ctx, -1);
            
            if (llama_vocab_is_eog(llama_model_get_vocab(self->model), new_token_id)) {
                break;
            }
            
            char buf[128];
            int n = llama_token_to_piece(llama_model_get_vocab(self->model), new_token_id, buf, sizeof(buf), 0, true);
            if (n < 0) {
                break;
            }
            
            NSString *tokenStr = [[NSString alloc] initWithBytes:buf length:n encoding:NSUTF8StringEncoding];
            if (tokenStr) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    onToken(tokenStr);
                });
            }
            
            batch = llama_batch_get_one(&new_token_id, 1);
            if (llama_decode(self->ctx, batch)) {
                break;
            }
            
            n_generated++;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            onComplete();
        });
    });
}

- (void)unloadModel {
    if (smpl) {
        llama_sampler_free(smpl);
        smpl = NULL;
    }
    if (ctx) {
        llama_free(ctx);
        ctx = NULL;
    }
    if (model) {
        llama_model_free(model);
        model = NULL;
    }
}

@end
