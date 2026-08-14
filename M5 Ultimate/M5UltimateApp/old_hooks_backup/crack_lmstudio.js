const fs = require('fs');
const path = require('path');
const cp = require('child_process');

console.log("=== M5 Ultimate Core Cracker ===");

const FALLBACK_ENTS = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key><true/>
    <key>com.apple.security.cs.allow-jit</key><true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
    <key>com.apple.security.device.audio-input</key><true/>
</dict>
</plist>`;

function removeOldAppHooks() {
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

function extractEntitlements(binPath, outXmlPath) {
    try {
        const out = cp.execSync(`codesign -d --entitlements :- "${binPath}" 2>/dev/null || true`).toString().trim();
        if (out && out.includes('<?xml')) {
            let xml = out.substring(out.indexOf('<?xml'));
            if (!xml.includes('com.apple.security.cs.disable-library-validation')) {
                xml = xml.replace('</dict>', '    <key>com.apple.security.cs.disable-library-validation</key><true/>\n</dict>');
            }
            fs.writeFileSync(outXmlPath, xml);
            return true;
        }
    } catch (e) {}
    
    // Fallback
    let fallback = FALLBACK_ENTS;
    fallback = fallback.replace('</dict>', '    <key>com.apple.security.cs.disable-library-validation</key><true/>\n</dict>');
    fs.writeFileSync(outXmlPath, fallback);
    return false;
}

function processBinary(targetBin, isLlama) {
    const dir = path.dirname(targetBin);
    const base = path.basename(targetBin);
    const origBin = path.join(dir, base + '.orig');
    const patchedBin = path.join(dir, base + '.patched');
    const entsXml = path.join(dir, base + '_ents.xml');
    
    // 1. Ensure we have the real binary in .orig
    if (fs.existsSync(targetBin)) {
        const content = fs.readFileSync(targetBin, 'utf8');
        if (content.startsWith('#!/bin/bash')) {
            if (!fs.existsSync(origBin)) {
                console.error(`[!] Wrapper found but no .orig for ${targetBin}! User might need to reinstall backend.`);
                return;
            }
        } else {
            // It's the real binary. Move it to .orig
            if (fs.existsSync(origBin)) fs.unlinkSync(origBin);
            fs.renameSync(targetBin, origBin);
        }
    } else if (!fs.existsSync(origBin)) {
        return; // Nothing to do
    }
    
    // 2. Extract entitlements from .orig
    extractEntitlements(origBin, entsXml);
    
    // 3. Copy interceptor and insert_dylib to the directory
    const srcInterceptor = path.join(__dirname, 'libmetal_interceptor.dylib') || path.join(__dirname, '../payloads/libmetal_interceptor.dylib');
    const destInterceptor = path.join(dir, 'libmetal_interceptor.dylib');
    if (fs.existsSync(srcInterceptor)) {
        fs.copyFileSync(srcInterceptor, destInterceptor);
    }
    
    const insertDylib = path.join(__dirname, 'insert_dylib');
    if (!fs.existsSync(insertDylib)) {
        const altPath = path.join(__dirname, 'build/M5 Ultimate.app/Contents/Resources/insert_dylib');
        if (fs.existsSync(altPath)) {
            cp.execSync(`cp "${altPath}" "${insertDylib}"`);
        }
    }
    
    // 4. Inject
    console.log(`[*] Injecting into ${base}...`);
    try {
        if (fs.existsSync(patchedBin)) fs.unlinkSync(patchedBin);
        cp.execSync(`"${insertDylib}" --all-yes "@executable_path/libmetal_interceptor.dylib" "${origBin}" "${patchedBin}"`, { stdio: 'pipe' });
    } catch(e) {
        console.error(`[-] Failed to inject ${base}`);
        return;
    }
    
    // 5. Sign patched binary
    try {
        cp.execSync(`xattr -cr "${patchedBin}" 2>/dev/null || true`);
        cp.execSync(`codesign --force --options runtime --sign - --entitlements "${entsXml}" "${patchedBin}"`, { stdio: 'pipe' });
        console.log(`[+] Signed ${base}.patched with Library Validation disabled`);
    } catch(e) {
        console.error(`[-] Failed to sign ${base}.patched`);
    }
    
    // 6. Write bash wrapper
    let wrapperContent = '';
    if (isLlama) {
        wrapperContent = `#!/bin/bash
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
exec "$(dirname "$0")/${base}.patched" "\${args[@]}"
`;
    } else {
        wrapperContent = `#!/bin/bash
exec "$(dirname "$0")/${base}.patched" "$@"
`;
    }
    
    fs.writeFileSync(targetBin, wrapperContent, { mode: 0o755 });
    console.log(`[+] Installed wrapper for ${base}`);
}

function deployPayloads() {
    console.log("[*] Finding backends and injecting payloads...");
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    
    // Process llama-server
    const llamaBackends = path.join(userHome, '.cache/lm-studio/extensions/backends');
    if (fs.existsSync(llamaBackends)) {
        const dirs = fs.readdirSync(llamaBackends);
        for (const d of dirs) {
            const llamaServer = path.join(llamaBackends, d, 'llama-server');
            if (fs.existsSync(llamaServer) || fs.existsSync(llamaServer + '.orig')) {
                processBinary(llamaServer, true);
            }
        }
    }
    
    // Process Python
    const mlxBackends = path.join(userHome, '.lmstudio/extensions/backends');
    if (fs.existsSync(mlxBackends)) {
        function findPythons(dir, fileList = []) {
            try {
                const files = fs.readdirSync(dir);
                for (const file of files) {
                    if (file.startsWith('.tmp')) continue;
                    const fullPath = path.join(dir, file);
                    try {
                        const stat = fs.statSync(fullPath);
                        if (stat.isDirectory()) {
                            findPythons(fullPath, fileList);
                        } else if (file === 'python3.11' || file === 'python3.11.orig') {
                            fileList.push(fullPath.replace('.orig', ''));
                        }
                    } catch(e) {}
                }
            } catch(e) {}
            return fileList;
        }
        const pythons = [...new Set(findPythons(mlxBackends))]; // Unique paths
        for (const py of pythons) {
            processBinary(py, false);
        }
    }
}

function revertBinary(targetBin) {
    const dir = path.dirname(targetBin);
    const base = path.basename(targetBin);
    const origBin = path.join(dir, base + '.orig');
    const patchedBin = path.join(dir, base + '.patched');
    const entsXml = path.join(dir, base + '_ents.xml');
    const dylib = path.join(dir, 'libmetal_interceptor.dylib');
    
    if (fs.existsSync(origBin)) {
        if (fs.existsSync(targetBin)) fs.unlinkSync(targetBin);
        fs.renameSync(origBin, targetBin);
        console.log(`[+] Reverted ${base}`);
    }
    if (fs.existsSync(patchedBin)) fs.unlinkSync(patchedBin);
    if (fs.existsSync(entsXml)) fs.unlinkSync(entsXml);
    if (fs.existsSync(dylib)) fs.unlinkSync(dylib);
}

if (process.argv.includes('--revert')) {
    console.log("[*] Reverting M5 Ultimate Injection...");
    removeOldAppHooks();
    
    const userHome = process.env.REAL_HOME || process.env.HOME || process.env.USERPROFILE;
    
    const llamaBackends = path.join(userHome, '.cache/lm-studio/extensions/backends');
    if (fs.existsSync(llamaBackends)) {
        fs.readdirSync(llamaBackends).forEach(d => {
            revertBinary(path.join(llamaBackends, d, 'llama-server'));
        });
    }
    
    const mlxBackends = path.join(userHome, '.lmstudio/extensions/backends');
    if (fs.existsSync(mlxBackends)) {
        function findPythons(dir, fileList = []) {
            try {
                const files = fs.readdirSync(dir);
                for (const file of files) {
                    if (file.startsWith('.tmp')) continue;
                    const fullPath = path.join(dir, file);
                    try {
                        const stat = fs.statSync(fullPath);
                        if (stat.isDirectory()) {
                            findPythons(fullPath, fileList);
                        } else if (file === 'python3.11' || file === 'python3.11.orig') {
                            fileList.push(fullPath.replace('.orig', ''));
                        }
                    } catch(e) {}
                }
            } catch(e) {}
            return fileList;
        }
        const pythons = [...new Set(findPythons(mlxBackends))];
        for (const py of pythons) {
            revertBinary(py);
        }
    }
    
    console.log("=== Revert Complete ===");
    process.exit(0);
}

removeOldAppHooks();
deployPayloads();
console.log("=== Crack Complete ===");

