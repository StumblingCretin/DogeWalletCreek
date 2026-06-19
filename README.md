# Dogecoin Core Wallet Recovery

Structured offline recovery for Dogecoin Core / MultiDoge `wallet.dat` using [BTCRecover](https://github.com/3rdIteration/btcrecover) token lists and optional NVIDIA hashcat (mode 11300).

## Before you start

See **[USER-NEXT-STEPS.md](USER-NEXT-STEPS.md)** for the full checklist.

1. Copy your wallet file (do not move the original):
   - Dogecoin Core: `%APPDATA%\Dogecoin\wallet.dat`
   - MultiDoge: `%APPDATA%\MultiDoge\` (look for wallet data files)
2. Place a copy at `artifacts/wallet.dat`
3. Put your known Dogecoin address in `artifacts/target-address.txt` (one line, starts with `D`)
4. Fill in token files under `tokens/` from your remembered phrase fragments
5. Document what you recall in `tokens/notes.md`

## Directory layout

```
artifacts/     wallet copy + target address
tokens/        tiered token lists + notes
hashes/        extracted hash for hashcat
generated/     candidate password lists
runs/
  autosave/           BTCRecover checkpoints
  hashcat-sessions/   hashcat restore files
  hashcat.potfile     recovered passwords (GPU)
  logs/
scripts/       helper PowerShell scripts
tools/         BTCRecover clone, bitcoin2john, hashcat
typos/         optional typo-map files
```

## Quick start

### GPU path (recommended — RTX 2070)

```batch
cd C:\Users\Jig\dogecoin-recovery

REM Install hashcat once (requires 7-Zip)
powershell -ExecutionPolicy Bypass -File scripts\install-hashcat.ps1

REM Verify GPU is detected
run-gpu-recovery.bat verify

REM Extract hash, then run tier1 on GPU
run-gpu-recovery.bat extract
run-gpu-recovery.bat tier 1
```

GPU flags: `-D 2 -w 4 -O` — GPU-only, max workload, optimized kernels for wallet.dat (mode 11300).

### CPU path (BTCRecover direct)

```powershell
cd C:\Users\Jig\dogecoin-recovery

# 1. Validate wallet copy exists and looks encrypted
.\scripts\check-wallet.ps1

# 2. Extract hash for GPU attacks (optional)
.\scripts\extract-hash.ps1

# 3. Preview candidate count (example tokens; replace with your tier1 file)
python tools\btcrecover\btcrecover.py --listpass --tokenlist tokens\tier1_dryrun.example.txt
.\scripts\run-tier1.ps1 -ListPassOnly

# 4. Run tier1 recovery
.\scripts\run-tier1.ps1

# 5. If tier1 fails, try tier2
.\scripts\run-tier1.ps1 -Tier 2

# 6. GPU mask attack (only if you know a fixed prefix/suffix)
run-gpu-recovery.bat mask KnownPrefix?d?d?d?d
```

## Progress checklist

- [ ] Copied `wallet.dat` to `artifacts/`
- [ ] Added known address to `artifacts/target-address.txt`
- [ ] Filled `tokens/notes.md` with password memory
- [ ] Customized `tokens/tier1_high_confidence.txt`
- [ ] Ran `check-wallet.ps1` — wallet is encrypted
- [ ] Ran `run-tier1.ps1 -ListPassOnly` — candidate count is reasonable
- [ ] Ran tier1 recovery
- [ ] If no match: customized tier2, then tier3
- [ ] If no match: tried hashcat mask with known prefix/suffix
- [ ] On success: moved funds to a new wallet; secured or deleted sensitive files

## Bitdefender / antivirus

If Bitdefender blocks scripts or downloads, see **[BITDEFENDER-WHITELIST.md](BITDEFENDER-WHITELIST.md)** for exact exclusion paths.

## Security

- Work offline on copies only.
- Do not upload `wallet.dat` to cloud services.
- Hashcat uses the extracted hash locally; that is safer than sharing the full wallet.
- Delete or encrypt `artifacts/`, `hashes/`, and `generated/` when finished.

## Resume interrupted runs

```powershell
python tools\btcrecover\btcrecover.py --restore runs\autosave\tier1.sav
```

## References

- [BTCRecover docs](https://btcrecover.readthedocs.io/en/latest/)
- [BTCRecover token file syntax](https://btcrecover.readthedocs.io/en/latest/TUTORIAL/)
- Hashcat mode **11300** = Bitcoin/Litecoin/Dogecoin Core wallet.dat
