# Replace create_common_params calls with simple new common_params
s/lparams = create_common_params_cuda(fname_str);/lparams = new common_params();\n    lparams->model.path = fname_str;/g
s/lparams = create_common_params(fname_str, lora_str, lora_base_str);/lparams = new common_params();\n    lparams->model.path = fname_str;/g

# Fix seed access
s/lparams->seed       = n_seed;/lparams->sampling.seed       = n_seed;/g

# Remove perplexity line (no longer exists)
s/.*lparams->perplexity = perplexity;.*//g

# Replace LLAMA_MAX_DEVICES with 128
s/LLAMA_MAX_DEVICES/128/g
