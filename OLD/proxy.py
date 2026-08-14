# m1n1 payload: m5_pmgr_adt_dumper.py
# Purpose: Traverse ADT to find PMGR and SMC endpoints, and dump P-State registers on M5 Pro.
# Execution: python3 proxy.py m5_pmgr_adt_dumper.py

from m1n1.setup import *
from m1n1.hw.pmgr import PMGR

def dump_adt_node(path):
    print(f"\n--- Traversing ADT for: {path} ---")
    node = adt.get_path(path)
    if not node:
        print(f"[!] Path {path} not found in ADT.")
        return None
        
    for prop in node.properties:
        print(f"{prop.name}: {prop.value}")
    return node

def probe_pmgr():
    print("\n--- Probing PMGR (Power Manager) ---")
    # The PMGR base usually lives under /arm-io/pmgr in the ADT
    pmgr_node = dump_adt_node("/arm-io/pmgr")
    if not pmgr_node:
        return

    # Extract reg base
    if hasattr(pmgr_node, 'reg'):
        reg_base = pmgr_node.reg[0]
        print(f"[*] PMGR Base Address (Physical): {hex(reg_base)}")
        
        # Initialize PMGR object via m1n1
        pmgr = PMGR(u, reg_base)
        
        # M5 Pro (0 E-cores) specific: We only care about P-core clusters and ANE.
        # We need to iterate over the power states to find the active frequency/voltage maps.
        print("\n[*] Dumping PMGR Device States...")
        for i in range(0, 256): # Probing first 256 domains
            try:
                state = pmgr.dev_state[i].reg
                # If state is valid and powered on
                if state != 0:
                     print(f"  Domain {i:03d}: State={hex(state)}")
            except Exception as e:
                pass
    else:
        print("[!] No 'reg' property found on PMGR node.")

def probe_smc():
    print("\n--- Probing SMC / PMU Endpoints ---")
    # SMC usually interfaces via SMC endpoints in ADT (e.g., /arm-io/smc)
    dump_adt_node("/arm-io/smc")

if __name__ == "__main__":
    print("Initializing M5 Pro Hardware Probe (0 E-Core variant)...")
    probe_pmgr()
    probe_smc()
    print("\nProbe complete. Analyze offsets to build the P-State override payload.")