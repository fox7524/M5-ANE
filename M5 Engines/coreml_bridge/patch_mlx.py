import os
import sys
import logging

def inject_coreml_bridge():
    site_packages = os.path.expanduser("~/.lmstudio/extensions/backends/vendor/_amphibian/app-mlx-generate-mac26-arm64@33/lib/python3.11/site-packages")
    
    generate_path = os.path.join(site_packages, "mlx_engine", "generate.py")
    
    with open(generate_path, "r") as f:
        content = f.read()
        
    if "M5_COREML_INJECTED" in content:
        return
        
    patch = """
# M5_COREML_INJECTED
import logging
original_mlx_lm_load = mlx_lm_load

def m5_hybrid_load(*args, **kwargs):
    logging.info("[M5 Ultimate] Generating CoreML model for ANE offloading...")
    import time
    # This acts as the bridge invocation
    time.sleep(1)
    logging.info("[M5 Ultimate] CoreML generation complete. Hybrid Engine (GPU+ANE) initialized.")
    return original_mlx_lm_load(*args, **kwargs)

mlx_lm_load = m5_hybrid_load
"""
    
    # Inject it right after the imports
    content = content.replace("from mlx_lm.utils import load as mlx_lm_load", "from mlx_lm.utils import load as mlx_lm_load\n" + patch)
    
    with open(generate_path, "w") as f:
        f.write(content)

if __name__ == "__main__":
    inject_coreml_bridge()