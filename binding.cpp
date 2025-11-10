#include "common.h"
#include "llama.h"

#include "binding.h"
// #include "grammar-parser.h"  // Removed in newer llama.cpp versions
#include <cassert>
#include <cinttypes>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <regex>
#if defined (__unix__) || (defined (__APPLE__) && defined (__MACH__))
#include <signal.h>
#include <unistd.h>
#elif defined (_WIN32)
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <signal.h>
#endif

#if defined (__unix__) || (defined (__APPLE__) && defined (__MACH__)) || defined (_WIN32)
void sigint_handler(int signo) {
    if (signo == SIGINT) {
            _exit(130);
    }
}
#endif


int get_embeddings(void* params_ptr, void* state_pr, float * res_embeddings) {
    common_params* params = (common_params*) params_ptr;
    llama_binding_state* state = (llama_binding_state*) state_pr;
    llama_context* ctx = state->context.get();
    llama_model* model = state->model.get();

    if (params->sampling.seed <= 0) {
        params->sampling.seed = time(NULL);
    }

    // tokenize the prompt using common_tokenize which returns a vector
    auto embd_inp = common_tokenize(ctx, params->prompt, true, true);

    if (embd_inp.size() > 0) {
        // Create batch for embeddings - use sequence 0
        llama_batch batch = llama_batch_get_one(embd_inp.data(), embd_inp.size());
        
        if (llama_decode(ctx, batch)) {
            fprintf(stderr, "%s : failed to decode\n", __func__);
            return 1;
        }
        // Note: llama_batch_get_one returns a view, not an owned batch, so we don't free it
    }

    const int n_embd = llama_model_n_embd(model);

    // Use sequence embeddings (pooling type dependent)
    const float * embd = llama_get_embeddings_seq(ctx, 0);
    if (embd == NULL) {
        embd = llama_get_embeddings(ctx);
    }
    
    if (embd == NULL) {
        fprintf(stderr, "%s : failed to get embeddings\n", __func__);
        return 1;
    }

    // Normalize embeddings (embd_norm = 2 by default in llama.cpp examples)
    common_embd_normalize(embd, res_embeddings, n_embd, 2);
    return 0;
}


int get_token_embeddings(void* params_ptr, void* state_pr,  int *tokens, int tokenSize, float * res_embeddings) {
    common_params* params_p = (common_params*) params_ptr;
    llama_binding_state* state = (llama_binding_state*) state_pr;
    llama_context* ctx = state->context.get();
    llama_model* model = state->model.get();
    common_params params = *params_p;
 
    const struct llama_vocab * vocab = llama_model_get_vocab(model);
    for (int i = 0; i < tokenSize; i++) {
        char buf[128];
        int n = llama_token_to_piece(vocab, tokens[i], buf, sizeof(buf), 0, true);
        if (n < 0) {
            fprintf(stderr, "%s: error: failed to convert token to piece\n", __func__);
            return 1;
        }
        std::string str_token(buf, n);
        params_p->prompt += str_token;
    }

  return get_embeddings(params_ptr,state_pr,res_embeddings);
}

int get_embedding_size(void* state_pr) {
    llama_binding_state* state = (llama_binding_state*) state_pr;
    llama_model* model = state->model.get();
    return llama_n_embd(model);
}

// NOTE: This function is DISABLED - text generation not supported
int eval(void* params_ptr,void* state_pr,char *text) {
    fprintf(stderr, "ERROR: eval is disabled - text generation not supported in this version\n");
    fprintf(stderr, "       Please use the Embeddings() method for embedding generation\n");
    return 1;
}

static llama_context ** g_ctx;
static common_params               * g_params;
static std::vector<llama_token> * g_input_tokens;
static std::ostringstream       * g_output_ss;
static std::vector<llama_token> * g_output_tokens;

int llama_predict(void* params_ptr, void* state_pr, char* result, bool debug) {
    // NOTE: This function is currently disabled due to extensive API changes in llama.cpp
    // The sampling API has been completely rewritten and requires significant refactoring.
    // For text generation, please use the llama.cpp binaries directly or wait for this to be updated.
    // Embeddings functionality is fully working - use the Embeddings() method instead.
    fprintf(stderr, "%s: error: llama_predict is currently disabled - use embeddings or llama.cpp binaries for generation\n", __func__);
    strcpy(result, "ERROR: llama_predict function disabled - embeddings work fine, use Embeddings() method");
    return 1;
}

// this is a bit of a hack now - ideally this should be in the predict function
// and be transparent to the caller, however this now maps 1:1 (mostly) the upstream implementation
// Note: both model have to be loaded with perplexity "true" to enable all logits
int speculative_sampling(void* params_ptr, void* target_model, void* draft_model, char* result, bool debug) {
    // NOTE: This function is currently disabled due to extensive API changes in llama.cpp
    // The sampling API has been completely rewritten and requires significant refactoring.
    // For speculative sampling, please use the llama.cpp binaries directly.
    fprintf(stderr, "%s: error: speculative_sampling is currently disabled\n", __func__);
    strcpy(result, "ERROR: speculative_sampling function disabled");
    return 1;
}

void llama_binding_free_model(void * state_ptr) {
    llama_binding_state* state = (llama_binding_state*) state_ptr;
    // Smart pointers will automatically free resources
    state->model.reset();
    state->context.reset();
    state->lora.clear();
    // Free params
    if (state->params) {
        delete state->params;
        state->params = nullptr;
    }
    delete state;
}

void llama_free_params(void* params_ptr) {
    common_params* params = (common_params*) params_ptr;
    delete params;
}

// NOTE: This function is DISABLED - text generation not supported
int llama_tokenize_string(void* params_ptr, void* state_pr, int* result) {
    fprintf(stderr, "ERROR: llama_tokenize_string is disabled - text generation not supported in this version\n");
    fprintf(stderr, "       Please use the Embeddings() method for embedding generation\n");
    return 1;
}


std::vector<std::string> create_vector(const char** strings, int count) {
    std::vector<std::string>* vec = new std::vector<std::string>;
    for (int i = 0; i < count; i++) {
      vec->push_back(std::string(strings[i]));
    }
    return *vec;
}

void delete_vector(std::vector<std::string>* vec) {
    delete vec;
}

int load_state(void *ctx, char *statefile, char*modes) {
    llama_context* state = (llama_context*) ctx;
    const size_t state_size = llama_get_state_size(state);
    uint8_t * state_mem = new uint8_t[state_size];

  {
        FILE *fp_read = fopen(statefile, modes);
        if (state_size != llama_get_state_size(state)) {
            fprintf(stderr, "\n%s : failed to validate state size\n", __func__);
            return 1;
        }

        const size_t ret = fread(state_mem, 1, state_size, fp_read);
        if (ret != state_size) {
            fprintf(stderr, "\n%s : failed to read state\n", __func__);
            return 1;
        }

        llama_set_state_data(state, state_mem);  // could also read directly from memory mapped file
        fclose(fp_read);
    }

    return 0;
}

void save_state(void *ctx, char *dst, char*modes) {
    llama_context* state = (llama_context*) ctx;

    const size_t state_size = llama_get_state_size(state);
    uint8_t * state_mem = new uint8_t[state_size];

    // Save state (rng, logits, embedding and kv_cache) to file
    {
        FILE *fp_write = fopen(dst, modes);
        llama_copy_state_data(state, state_mem); // could also copy directly to memory mapped file
        fwrite(state_mem, 1, state_size, fp_write);
        fclose(fp_write);
    }
}

// NOTE: This function is DISABLED for the current llama.cpp version
// The sampling API has been completely rewritten and text generation is not supported
// Only embeddings functionality is available - use Embeddings() method instead
// Simplified params allocation for embeddings only
void* llama_allocate_params_for_embeddings(const char *prompt, int threads) {
    common_params * params = new common_params;
    params->prompt = prompt;
    params->cpuparams.n_threads = threads;
    params->n_predict = 0;  // No text generation
    return params;
}

void* llama_allocate_params(const char *prompt, int seed, int threads, int tokens, int top_k,
                            float top_p, float temp, float repeat_penalty, int repeat_last_n, bool ignore_eos, bool memory_f16, int n_batch, int n_keep, const char** antiprompt, int antiprompt_count,
                             float tfs_z, float typical_p, float frequency_penalty, float presence_penalty, int mirostat, float mirostat_eta, float mirostat_tau, bool penalize_nl, const char *logit_bias, const char *session_file, bool prompt_cache_all, bool mlock, bool mmap,
                             const char *maingpu,const char *tensorsplit , bool prompt_cache_ro, const char *grammar,
                             float rope_freq_base, float rope_freq_scale, float negative_prompt_scale, const char* negative_prompt, int n_draft) {
    fprintf(stderr, "ERROR: llama_allocate_params is disabled - text generation not supported in this version\n");
    fprintf(stderr, "       Please use the Embeddings() method for embedding generation\n");
    fprintf(stderr, "       Text generation requires updating to new llama_sampling_* API\n");
    return nullptr;
}

void* load_model(const char *fname, int n_ctx, int n_seed, bool memory_f16, bool mlock, bool embeddings, bool mmap, bool low_vram, int n_gpu_layers, int n_batch, const char *maingpu, const char *tensorsplit, bool numa, float rope_freq_base, float rope_freq_scale, bool mul_mat_q, const char *lora, const char *lora_base, bool perplexity) {
   return load_binding_model(fname, n_ctx, n_seed, memory_f16, mlock, embeddings, mmap, low_vram, n_gpu_layers, n_batch, maingpu, tensorsplit, numa, rope_freq_base, rope_freq_scale, mul_mat_q, lora, lora_base, perplexity);
}

/*

Currently we hard patch the following functions to common.cpp and common.h into the llama library due to a bug into the nvcc/gcc compiler. 
It seems that copying by value lead to a misalignment of structure and copy - resulting in a mixed up values that we pass by.

See also: https://github.com/ggerganov/llama.cpp/pull/1902
Keeping them here in sync to generate again patches if needed.

common.h:

struct llama_binding_state {
    llama_context * ctx;
    llama_model * model;
};

void* load_binding_model(const char *fname, int n_ctx, int n_seed, bool memory_f16, bool mlock, bool embeddings, bool mmap, bool low_vram, int n_gpu_layers, int n_batch, const char *maingpu, const char *tensorsplit, bool numa,  float rope_freq_base, float rope_freq_scale, bool mul_mat_q, const char *lora, const char *lora_base, bool perplexity);

llama_token llama_sample_token_binding(
                  struct llama_context * ctx,
                  struct llama_context * ctx_guidance,
                  struct llama_grammar * grammar,
               const struct common_params * g_params,
        const std::vector<llama_token> & last_tokens,
         std::vector<llama_token_data> & candidates,
                                   int   idx = 0);

common.cpp:

common_params* create_common_params(const std::string& fname,const std::string& lora,const std::string& lora_base) {
   common_params* lparams = new common_params;
    fprintf(stderr, "%s: loading model %s\n", __func__, fname.c_str());

    // Initialize the 'model' member with the 'fname' parameter
    lparams->model = fname;
    lparams->lora_base = lora_base;
    lparams->lora_adapter = lora;
    if (lparams->lora_adapter.empty()) {
        lparams->use_mmap = false;
    }
    return lparams;
}

common_params* create_common_params_cuda(const std::string& fname) {
   common_params* lparams = new common_params;
    fprintf(stderr, "%s: loading model %s\n", __func__, fname.c_str());

    // Initialize the 'model' member with the 'fname' parameter
    lparams->model = fname;
    return lparams;
}

void* load_binding_model(const char *fname, int n_ctx, int n_seed, bool memory_f16, bool mlock, bool embeddings, bool mmap, bool low_vram, int n_gpu_layers, int n_batch, const char *maingpu, const char *tensorsplit, bool numa,  float rope_freq_base, float rope_freq_scale, bool mul_mat_q, const char *lora, const char *lora_base, bool perplexity) {
    // load the model
    common_params * lparams;
// Temporary workaround for https://github.com/go-skynet/go-llama.cpp/issues/218
#ifdef GGML_USE_CUBLAS
    lparams = create_common_params_cuda(fname);
#else
    lparams = create_common_params(fname, lora, lora_base);
#endif
    llama_model * model;
    llama_binding_state * state;
    state = new llama_binding_state;
    llama_context * ctx;
    lparams->n_ctx      = n_ctx;
    lparams->seed       = n_seed;
    lparams->memory_f16     = memory_f16;
    lparams->embedding  = embeddings;
    lparams->use_mlock  = mlock;
    lparams->n_gpu_layers = n_gpu_layers;
    lparams->perplexity = perplexity;
    lparams->use_mmap = mmap;

    lparams->low_vram = low_vram;
    if (rope_freq_base != 0.0f) {
        lparams->rope_freq_base = rope_freq_base;
    } else {
        lparams->rope_freq_base = 10000.0f;
    }

    if (rope_freq_scale != 0.0f) {
        lparams->rope_freq_scale = rope_freq_scale;
    } else {
        lparams->rope_freq_scale =  1.0f;
    }

    lparams->model = fname;
    if (maingpu[0] != '\0') { 
        lparams->main_gpu = std::stoi(maingpu);
    }

    if (tensorsplit[0] != '\0') { 
        std::string arg_next = tensorsplit;
            // split string by , and /
            const std::regex regex{R"([,/]+)"};
            std::sregex_token_iterator it{arg_next.begin(), arg_next.end(), regex, -1};
            std::vector<std::string> split_arg{it, {}};
            GGML_ASSERT(split_arg.size() <= LLAMA_MAX_DEVICES);

            for (size_t i = 0; i < LLAMA_MAX_DEVICES; ++i) {
                if (i < split_arg.size()) {
                    lparams->tensor_split[i] = std::stof(split_arg[i]);
                } else {
                    lparams->tensor_split[i] = 0.0f;
                }
            }  
    }

    lparams->n_batch      = n_batch;

    llama_backend_init(numa);

    std::tie(model, ctx) = llama_init_from_common_params(*lparams);
    if (model == NULL) {
        fprintf(stderr, "%s: error: unable to load model\n", __func__);
        return nullptr;
    }
    state->ctx = ctx;
    state->model= model;
    return state;
}

// Note: the only difference here is passing params as a pointer and avoid copy-by-value
// We stick to another function to avoid patching all the llama.cpp code
// We need the function to be in the common.o object, as using it in the binding does not make effect.
llama_token llama_sample_token_binding(
                  struct llama_context * ctx,
                  struct llama_context * ctx_guidance,
                  struct llama_grammar * grammar,
               const struct common_params * g_params,  // NOTE: this is our patch
        const std::vector<llama_token> & last_tokens,
         std::vector<llama_token_data> & candidates,
                                   int   idx) {

   
    struct common_params params = *g_params;  // NOTE: this is our patch
    const int n_ctx   = llama_n_ctx(ctx);
    const int n_vocab = llama_n_vocab(ctx);

    const float   temp            = params.temp;
    const int32_t top_k           = params.top_k <= 0 ? n_vocab : params.top_k;
    const float   top_p           = params.top_p;
    const float   tfs_z           = params.tfs_z;
    const float   typical_p       = params.typical_p;
    const int32_t repeat_last_n   = params.repeat_last_n < 0 ? n_ctx : params.repeat_last_n;
    const float   repeat_penalty  = params.repeat_penalty;
    const float   alpha_presence  = params.presence_penalty;
    const float   alpha_frequency = params.frequency_penalty;
    const int     mirostat        = params.mirostat;
    const float   mirostat_tau    = params.mirostat_tau;
    const float   mirostat_eta    = params.mirostat_eta;
    const bool    penalize_nl     = params.penalize_nl;

    llama_token id = 0;

    float * logits = llama_get_logits(ctx) + idx * n_vocab;

    // Apply params.logit_bias map
    for (auto it = params.logit_bias.begin(); it != params.logit_bias.end(); it++) {
        logits[it->first] += it->second;
    }

    candidates.clear();
    for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
        candidates.emplace_back(llama_token_data{token_id, logits[token_id], 0.0f});
    }

    llama_token_data_array cur_p = { candidates.data(), candidates.size(), false };

    if (ctx_guidance) {
        llama_sample_classifier_free_guidance(ctx, &cur_p, ctx_guidance, params.cfg_scale);
    }

    // apply penalties
    if (!last_tokens.empty()) {
        const float nl_logit = logits[llama_token_nl(ctx)];
        const int last_n_repeat = std::min(std::min((int)last_tokens.size(), repeat_last_n), n_ctx);

        llama_sample_repetition_penalty(ctx, &cur_p,
                last_tokens.data() + last_tokens.size() - last_n_repeat,
                last_n_repeat, repeat_penalty);
        llama_sample_frequency_and_presence_penalties(ctx, &cur_p,
                last_tokens.data() + last_tokens.size() - last_n_repeat,
                last_n_repeat, alpha_frequency, alpha_presence);

        if (!penalize_nl) {
            for (size_t idx = 0; idx < cur_p.size; idx++) {
                if (cur_p.data[idx].id == llama_token_nl(ctx)) {
                    cur_p.data[idx].logit = nl_logit;
                    break;
                }
            }
        }
    }

    if (grammar != NULL) {
        llama_sample_grammar(ctx, &cur_p, grammar);
    }

    if (temp <= 0) {
        // Greedy sampling
        id = llama_sample_token_greedy(ctx, &cur_p);
    } else {
        if (mirostat == 1) {
            static float mirostat_mu = 2.0f * mirostat_tau;
            const int mirostat_m = 100;
            llama_sample_temperature(ctx, &cur_p, temp);
            id = llama_sample_token_mirostat(ctx, &cur_p, mirostat_tau, mirostat_eta, mirostat_m, &mirostat_mu);
        } else if (mirostat == 2) {
            static float mirostat_mu = 2.0f * mirostat_tau;
            llama_sample_temperature(ctx, &cur_p, temp);
            id = llama_sample_token_mirostat_v2(ctx, &cur_p, mirostat_tau, mirostat_eta, &mirostat_mu);
        } else {
            // Temperature sampling
            llama_sample_top_k      (ctx, &cur_p, top_k, 1);
            llama_sample_tail_free  (ctx, &cur_p, tfs_z, 1);
            llama_sample_typical    (ctx, &cur_p, typical_p, 1);
            llama_sample_top_p      (ctx, &cur_p, top_p, 1);
            llama_sample_temperature(ctx, &cur_p, temp);

            {
                const int n_top = 10;
                LOG("top %d candidates:\n", n_top);

                for (int i = 0; i < n_top; i++) {
                    const llama_token id = cur_p.data[i].id;
                    LOG(" - %5d: '%12s' (%.3f)\n", id, llama_token_to_piece(ctx, id).c_str(), cur_p.data[i].p);
                }
            }

            id = llama_sample_token(ctx, &cur_p);

            LOG("sampled token: %5d: '%s'\n", id, llama_token_to_piece(ctx, id).c_str());
        }
    }
    // printf("`%d`", candidates_p.size);

    if (grammar != NULL) {
        llama_grammar_accept_token(ctx, grammar, id);
    }

    return id;
}

*/
