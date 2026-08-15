import os
import sys

def unpatch():
    site_packages = os.path.expanduser("~/.lmstudio/extensions/backends/vendor/_amphibian/app-mlx-generate-mac26-arm64@33/lib/python3.11/site-packages")
    generate_path = os.path.join(site_packages, "mlx_engine", "generate.py")
    
    with open(generate_path, "r") as f:
        lines = f.readlines()
        
    new_lines = []
    skip = False
    for line in lines:
        if line.strip() == "# M5_COREML_INJECTED":
            skip = True
            
        if skip and line.strip() == "mlx_lm_load = m5_hybrid_load":
            skip = False
            continue
            
        if not skip:
            new_lines.append(line)
            
    with open(generate_path, "w") as f:
        f.writelines(new_lines)
        
if __name__ == "__main__":
    unpatch()
