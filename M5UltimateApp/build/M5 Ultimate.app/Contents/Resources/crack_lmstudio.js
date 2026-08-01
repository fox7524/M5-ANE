const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const APP_PATH = '/Applications/LM Studio.app';
const MAIN_JS = path.join(APP_PATH, 'Contents/Resources/app/.webpack/main/index.js');
const WORKER_JS = path.join(APP_PATH, 'Contents/Resources/app/.webpack/lib/llmworker.js');

const HOOK_PAYLOAD = `// --- M5 ULTIMATE HOOK START ---
(function() {
    if (global.M5_HOOK_ACTIVE) return;
    global.M5_HOOK_ACTIVE = true;
    try {
        const cp = require('child_process');
        const path = require('path');
        const origSpawn = cp.spawn;
        cp.spawn = function(command, args, options) {
            const userHome = process.env.HOME || process.env.USERPROFILE;
            
            // 1. GGUF Interception
            if (command && typeof command === 'string' && command.includes('llama-server')) {
                // Redirect to our ANE bridged server
                const customServer = path.join(userHome, '.cache/lm-studio/bin/llama-server.ane');
                if (require('fs').existsSync(customServer)) {
                    command = customServer;
                    if (Array.isArray(args)) {
                        let hasTensorSplit = false;
                        for (let i = 0; i < args.length; i++) {
                            if (args[i] === '--tensor-split' || args[i] === '-ts') {
                                hasTensorSplit = true; break;
                            }
                        }
                        if (!hasTensorSplit) {
                            args.push('--tensor-split', '18,20');
                        }
                    }
                    console.log("[M5 Ultimate] Intercepted llama-server -> Redirected to ANE version + tensor-split");
                }
            }
            
            // 2. MLX Interception
            if (command && typeof command === 'string' && command.includes('python')) {
                options = options || {};
                options.env = options.env || process.env;
                const mlxLibPath = path.join(userHome, '.lmstudio/extensions/m5_mlx');
                if (require('fs').existsSync(mlxLibPath)) {
                    options.env.DYLD_LIBRARY_PATH = mlxLibPath + (options.env.DYLD_LIBRARY_PATH ? ':' + options.env.DYLD_LIBRARY_PATH : '');
                    console.log("[M5 Ultimate] Intercepted python -> Injected DYLD_LIBRARY_PATH for MLX ANE backend");
                }
            }
            
            // Update arguments before applying
            const callArgs = [command, args, options];
            return origSpawn.apply(this, callArgs);
        };
        console.log("[M5 Ultimate] Core Hook Installed Successfully.");
    } catch (e) {
        console.error("[M5 Ultimate] Hook error:", e);
    }
})();
// --- M5 ULTIMATE HOOK END ---
`;

function safeWrite(filePath, content) {
    const tmpPath = '/tmp/m5_tmp_' + path.basename(filePath);
    fs.writeFileSync(tmpPath, content, 'utf8');
    try {
        cp.execSync(`rm -f "${filePath}"`);
    } catch(e) {}
    cp.execSync(`cp "${tmpPath}" "${filePath}"`);
    cp.execSync(`rm -f "${tmpPath}"`);
}

function removeHook(filePath) {
    if (!fs.existsSync(filePath)) return;
    let content = fs.readFileSync(filePath, 'utf8');
    if (content.includes('M5_HOOK_ACTIVE')) {
        console.log(`[*] Removing hook from ${path.basename(filePath)}...`);
        const regex = /\/\/ --- M5 ULTIMATE HOOK START ---[\s\S]*?\/\/ --- M5 ULTIMATE HOOK END ---\s*/;
        content = content.replace(regex, '');
        safeWrite(filePath, content);
        console.log(`[+] Successfully removed hook from ${path.basename(filePath)}`);
    }
}

function injectHook(filePath) {
    if (!fs.existsSync(filePath)) {
        console.warn(`[!] File not found: ${filePath}`);
        return;
    }
    let content = fs.readFileSync(filePath, 'utf8');
    if (content.includes('M5_HOOK_ACTIVE')) {
        console.log(`[*] Hook already present in ${path.basename(filePath)}, removing old hook...`);
        const regex = /\/\/ --- M5 ULTIMATE HOOK START ---[\s\S]*?\/\/ --- M5 ULTIMATE HOOK END ---\s*/;
        content = content.replace(regex, '');
    }
    content = HOOK_PAYLOAD + content;
    safeWrite(filePath, content);
    console.log(`[+] Successfully injected hook into ${path.basename(filePath)}`);
}

function stripHardenedRuntime() {
    console.log("[*] Stripping Hardened Runtime from LM Studio.app...");
    try {
        cp.execSync(`xattr -cr "${APP_PATH}"`, { stdio: 'inherit' });
        cp.execSync(`codesign --force --deep --sign - "${APP_PATH}"`, { stdio: 'inherit' });
        console.log("[+] Hardened Runtime stripped successfully!");
    } catch (err) {
        console.error("[-] Failed to sign the app. Make sure you run this script with sudo.");
        process.exit(1);
    }
}

function deployPayloads() {
    console.log("[*] Deploying M5 Ultimate Payloads...");
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    
    // GGUF Payload
    const llamaDir = path.join(userHome, '.cache/lm-studio/bin');
    if (!fs.existsSync(llamaDir)) fs.mkdirSync(llamaDir, { recursive: true });
    
    const srcLlama = path.join(__dirname, 'payloads/llama/llama-server.ane');
    if (fs.existsSync(srcLlama)) {
        fs.copyFileSync(srcLlama, path.join(llamaDir, 'llama-server.ane'));
        cp.execSync(`chmod +x "${path.join(llamaDir, 'llama-server.ane')}"`);
        console.log("[+] Deployed llama-server.ane");
    }
    
    // Copy dylibs to llama cache just in case
    const llamaPayloads = path.join(__dirname, 'payloads/llama');
    if (fs.existsSync(llamaPayloads)) {
        fs.readdirSync(llamaPayloads).forEach(file => {
            if (file.endsWith('.dylib') || file.endsWith('.metal')) {
                fs.copyFileSync(path.join(llamaPayloads, file), path.join(llamaDir, file));
            }
        });
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

function fixPythonSignatures() {
    console.log("[*] Fixing Python signatures for MLX Library Validation...");
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
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
                } else if (file === 'python3.11') {
                    fileList.push(fullPath);
                }
            }
            return fileList;
        }
        const pythons = findPythons(backendsDir);
        for (const py of pythons) {
            console.log(`[*] Re-signing Python with runtime & entitlements: ${py}`);
            try {
                cp.execSync(`xattr -cr "${py}" 2>/dev/null || true`);
                // CRITICAL FIX: --options runtime is required for disable-library-validation to work on ad-hoc signatures!
                cp.execSync(`codesign --force --options runtime --sign - --entitlements "${entsPath}" "${py}"`, { stdio: 'pipe' });
                console.log(`[+] Fixed Library Validation for ${path.basename(py)}`);
            } catch (err) {
                console.error(`[-] Failed to sign ${py}`);
            }
        }
    } else {
        console.log("[!] LM Studio backends not found, skipping Python fix.");
    }
}

function restoreOldProxy() {
    console.log("[*] Cleaning up old C++ proxy files (if any)...");
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    const llamaDir = path.join(userHome, '.cache/lm-studio/bin');
    if (fs.existsSync(llamaDir)) {
        const orig = path.join(llamaDir, 'llama-server.orig');
        const proxy = path.join(llamaDir, 'llama-server');
        if (fs.existsSync(orig)) {
            try {
                fs.copyFileSync(orig, proxy);
                fs.unlinkSync(orig);
                console.log("[+] Restored original llama-server in cache and cleaned .orig backup.");
            } catch(e) {
                console.error("[-] Failed to restore old proxy:", e);
            }
        }
    }
}

console.log("=== M5 Ultimate Core Cracker ===");

if (process.argv.includes('--revert')) {
    console.log("[*] Reverting M5 Ultimate Injection...");
    removeHook(MAIN_JS);
    removeHook(WORKER_JS);
    restoreOldProxy();
    
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    const aneServer = path.join(userHome, '.cache/lm-studio/bin/llama-server.ane');
    if (fs.existsSync(aneServer)) {
        try { fs.unlinkSync(aneServer); console.log("[+] Removed llama-server.ane"); } catch(e){}
    }
    console.log("=== Revert Complete ===");
    process.exit(0);
}

restoreOldProxy();
deployPayloads();
injectHook(MAIN_JS);
injectHook(WORKER_JS);
stripHardenedRuntime();
fixPythonSignatures();
console.log("=== Crack Complete ===");
