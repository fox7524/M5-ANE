const fs = require('fs');
const path = require('path');
const cp = require('child_process');

console.log("=== M5 Ultimate Core Cracker ===");

function removeOldAppHooks() {
    // Remove old index.js and llmworker.js hooks if they exist, since we don't need them anymore!
    console.log("[*] Cleaning up old application hooks (if any)...");
    const APP_PATH = '/Applications/LM Studio.app';
    const MAIN_JS = path.join(APP_PATH, 'Contents/Resources/app/.webpack/main/index.js');
    const WORKER_JS = path.join(APP_PATH, 'Contents/Resources/app/.webpack/lib/llmworker.js');
    
    [MAIN_JS, WORKER_JS].forEach(filePath => {
        if (!fs.existsSync(filePath)) return;
        try {
            let content = fs.readFileSync(filePath, 'utf8');
            if (content.includes('M5_HOOK_ACTIVE')) {
                const regex = /\/\/ --- M5 ULTIMATE HOOK START ---[\s\S]*?\/\/ --- M5 ULTIMATE HOOK END ---\s*/;
                content = content.replace(regex, '');
                
                // write back
                const tmpPath = '/tmp/m5_tmp_' + path.basename(filePath);
                fs.writeFileSync(tmpPath, content, 'utf8');
                cp.execSync(`rm -f "${filePath}"`);
                cp.execSync(`cp "${tmpPath}" "${filePath}"`);
                cp.execSync(`rm -f "${tmpPath}"`);
                console.log(`[+] Removed old hook from ${path.basename(filePath)}`);
            }
        } catch(e) {
            console.error(`[-] Failed to remove hook from ${filePath}: ${e.message}`);
        }
    });
}

function deployPayloads() {
    console.log("[*] Deploying M5 Ultimate Payloads...");
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    
    // GGUF Payload - Dynamic Injection for lms
    const llamaDir = path.join(userHome, '.cache/lm-studio/bin');
    if (!fs.existsSync(llamaDir)) fs.mkdirSync(llamaDir, { recursive: true });
    
    // Copy interceptor
    const srcInterceptor = path.join(__dirname, 'libmetal_interceptor.dylib');
    if (fs.existsSync(srcInterceptor)) {
        fs.copyFileSync(srcInterceptor, path.join(llamaDir, 'libmetal_interceptor.dylib'));
    } else {
        // Fallback for when running from source
        const altInterceptor = path.join(__dirname, '../payloads/libmetal_interceptor.dylib');
        if (fs.existsSync(altInterceptor)) {
            fs.copyFileSync(altInterceptor, path.join(llamaDir, 'libmetal_interceptor.dylib'));
        }
    }
    
    // Copy insert_dylib
    const srcInsertDylib = path.join(__dirname, 'insert_dylib');
    const destInsertDylib = path.join(llamaDir, 'insert_dylib');
    if (fs.existsSync(srcInsertDylib)) {
        fs.copyFileSync(srcInsertDylib, destInsertDylib);
        cp.execSync(`chmod +x "${destInsertDylib}"`);
    }

    // Dynamic Injection of lms
    const lmsBinary = path.join(llamaDir, 'lms');
    const lmsOrig = path.join(llamaDir, 'lms.orig');
    const lmsAne = path.join(llamaDir, 'lms.ane');
    
    if (fs.existsSync(lmsBinary)) {
        const content = fs.readFileSync(lmsBinary, 'utf8');
        if (!content.startsWith('#!/bin/bash')) {
            // It's the real binary, rename it
            fs.renameSync(lmsBinary, lmsOrig);
            console.log("[+] Renamed original lms to lms.orig");
        }
    }
    
    if (fs.existsSync(lmsOrig) && fs.existsSync(destInsertDylib)) {
        console.log("[*] Injecting libmetal_interceptor.dylib into lms.orig...");
        try {
            cp.execSync(`"${destInsertDylib}" --all-yes "@executable_path/libmetal_interceptor.dylib" "${lmsOrig}" "${lmsAne}"`, { stdio: 'pipe' });
            cp.execSync(`xattr -cr "${lmsAne}" 2>/dev/null || true`);
            cp.execSync(`codesign --force --sign - "${lmsAne}" 2>/dev/null || true`);
            console.log("[+] Successfully created injected lms.ane");
        } catch (e) {
            console.error("[-] Failed to inject lms:", e.message);
        }
    }
    
    // MLX Payload
    const mlxDir = path.join(userHome, '.lmstudio/extensions/m5_mlx');
    if (!fs.existsSync(mlxDir)) fs.mkdirSync(mlxDir, { recursive: true });
    
    const mlxPayloads = path.join(__dirname, 'payloads/mlx');
    if (fs.existsSync(mlxPayloads)) {
        fs.readdirSync(mlxPayloads).forEach(file => {
            if (file.endsWith('.dylib') || file.endsWith('.metallib')) {
                const targetPath = path.join(mlxDir, file);
                fs.copyFileSync(path.join(mlxPayloads, file), targetPath);
                if (file.endsWith('.dylib')) {
                    try {
                        cp.execSync(`xattr -cr "${targetPath}" 2>/dev/null || true`);
                        cp.execSync(`codesign --force --sign - "${targetPath}" 2>/dev/null || true`);
                    } catch(e) {}
                }
            }
        });
        console.log("[+] Deployed MLX payloads (libmlx.dylib & metallib)");
    }
}

function installWrappers() {
    console.log("[*] Installing Bash Wrappers for LM Studio executables...");
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    
    // 1. GGUF lms wrapper
    const llamaDir = path.join(userHome, '.cache/lm-studio/bin');
    if (fs.existsSync(llamaDir)) {
        const lmsServer = path.join(llamaDir, 'lms');
        const lmsAne = path.join(llamaDir, 'lms.ane');
        
        if (fs.existsSync(lmsAne)) {
            // Create wrapper script
            const wrapperContent = `#!/bin/bash
# M5 Ultimate Wrapper for lms
args=("$@")
has_ts=0
for arg in "\${args[@]}"; do
    if [[ "$arg" == "--tensor-split" || "$arg" == "-ts" ]]; then
        has_ts=1
        break
    fi
done

if [[ $has_ts -eq 0 ]]; then
    args+=("--tensor-split" "18,20")
fi

echo "[M5 Ultimate] Launching ANE injected lms with args: \${args[*]}" >> /tmp/m5_proxy.log

# Execute the injected binary
exec "$(dirname "$0")/lms.ane" "\${args[@]}"
`;
            fs.writeFileSync(lmsServer, wrapperContent, { mode: 0o755 });
            console.log("[+] Installed lms wrapper.");
        }
    }
    
    // 2. MLX python wrapper
    const entsPath = '/tmp/m5_ents.xml';
    fs.writeFileSync(entsPath, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
</dict>
</plist>`);

    const backendsDir = path.join(userHome, '.lmstudio/extensions/backends');
    if (fs.existsSync(backendsDir)) {
        function findPythons(dir, fileList = []) {
            const files = fs.readdirSync(dir);
            for (const file of files) {
                const fullPath = path.join(dir, file);
                if (fs.statSync(fullPath).isDirectory()) {
                    findPythons(fullPath, fileList);
                } else if (file === 'python3.11' || file === 'python3.11.orig') {
                    fileList.push(fullPath);
                }
            }
            return fileList;
        }
        
        const pythons = findPythons(backendsDir);
        for (const py of pythons) {
            let origPy = py;
            let wrapperPy = py;
            
            if (!py.endsWith('.orig')) {
                // Read the file to see if it's already a wrapper
                const content = fs.readFileSync(py, 'utf8');
                if (!content.startsWith('#!/bin/bash')) {
                    origPy = py + '.orig';
                    fs.renameSync(py, origPy);
                    console.log(`[+] Renamed python3.11 to python3.11.orig at ${path.dirname(py)}`);
                } else {
                    origPy = py + '.orig';
                }
            } else {
                wrapperPy = py.replace('.orig', '');
            }
            
            // Re-sign the .orig binary
            if (fs.existsSync(origPy)) {
                try {
                    cp.execSync(`xattr -cr "${origPy}" 2>/dev/null || true`);
                    cp.execSync(`codesign --force --options runtime --sign - --entitlements "${entsPath}" "${origPy}"`, { stdio: 'pipe' });
                    console.log(`[+] Re-signed ${path.basename(origPy)} for Library Validation bypass`);
                } catch (e) {
                    console.error(`[-] Failed to sign ${origPy}`);
                }
            }
            
            // Write the bash wrapper
            const pyWrapperContent = `#!/bin/bash
# M5 Ultimate Wrapper for MLX Python
echo "[M5 Ultimate] Launching Python with DYLD_LIBRARY_PATH injected" >> /tmp/m5_proxy_mlx.log

export DYLD_LIBRARY_PATH="$HOME/.lmstudio/extensions/m5_mlx\${DYLD_LIBRARY_PATH:+:\$DYLD_LIBRARY_PATH}"
exec "$(dirname "$0")/python3.11.orig" "$@"
`;
            fs.writeFileSync(wrapperPy, pyWrapperContent, { mode: 0o755 });
            console.log(`[+] Installed Python wrapper at ${wrapperPy}`);
        }
    }
}

function revertWrappers() {
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    
    // 1. Revert lms
    const llamaDir = path.join(userHome, '.cache/lm-studio/bin');
    if (fs.existsSync(llamaDir)) {
        const lmsServer = path.join(llamaDir, 'lms');
        const lmsOrig = path.join(llamaDir, 'lms.orig');
        const lmsAne = path.join(llamaDir, 'lms.ane');
        if (fs.existsSync(lmsOrig)) {
            fs.renameSync(lmsOrig, lmsServer);
            console.log("[+] Reverted lms.orig to lms");
        }
        if (fs.existsSync(lmsAne)) {
            fs.unlinkSync(lmsAne);
            console.log("[+] Removed lms.ane");
        }
    }
    
    // 2. Revert Python
    const backendsDir = path.join(userHome, '.lmstudio/extensions/backends');
    if (fs.existsSync(backendsDir)) {
        function findPythons(dir, fileList = []) {
            const files = fs.readdirSync(dir);
            for (const file of files) {
                const fullPath = path.join(dir, file);
                if (fs.statSync(fullPath).isDirectory()) {
                    findPythons(fullPath, fileList);
                } else if (file === 'python3.11.orig') {
                    fileList.push(fullPath);
                }
            }
            return fileList;
        }
        
        const origPythons = findPythons(backendsDir);
        for (const origPy of origPythons) {
            const wrapperPy = origPy.replace('.orig', '');
            if (fs.existsSync(wrapperPy)) {
                fs.unlinkSync(wrapperPy); // delete wrapper
            }
            fs.renameSync(origPy, wrapperPy);
            console.log(`[+] Reverted ${path.basename(origPy)} to ${path.basename(wrapperPy)}`);
        }
    }
}

if (process.argv.includes('--revert')) {
    console.log("[*] Reverting M5 Ultimate Injection...");
    removeOldAppHooks();
    revertWrappers();
    console.log("=== Revert Complete ===");
    process.exit(0);
}

removeOldAppHooks();
deployPayloads();
installWrappers();

console.log("=== Crack Complete ===");
