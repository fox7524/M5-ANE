#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OLLAMA_PATH="/Applications/Ollama.app/Contents/Resources/ollama"
SAVE_DIR="$HOME/.m5_m5ultimate_saves"

mkdir -p "$SAVE_DIR"

if [ -f "$OLLAMA_PATH" ] && [ ! -f "${OLLAMA_PATH}_original" ]; then
    echo "[*] Yedekleniyor ve Orijinal imza kaldiriliyor..."
    cp "$OLLAMA_PATH" "$SAVE_DIR/ollama.backup"
    codesign --remove-signature "$OLLAMA_PATH"
    mv "$OLLAMA_PATH" "${OLLAMA_PATH}_original"
    
    echo "[*] Truva Ati (Wrapper) yerlestiriliyor..."
    cat << WRAPPER_EOF > "$OLLAMA_PATH"
#!/bin/bash
if [ -f "/tmp/m5_m5ultimate_systemwide" ]; then
    export DYLD_INSERT_LIBRARIES="$SCRIPT_DIR/libmetal_interceptor.dylib"
    export DYLD_FORCE_FLAT_NAMESPACE=1
fi
exec "\$0_original" "\$@"
WRAPPER_EOF
    chmod +x "$OLLAMA_PATH"
    
    echo "[*] Ad-Hoc imza atiliyor..."
    codesign -s - "${OLLAMA_PATH}_original"
    
    echo "[+] Ollama M5 Ultimate Yamasi Basarili!"
else
    echo "[-] Ollama zaten yamali veya bulunamadi."
fi
