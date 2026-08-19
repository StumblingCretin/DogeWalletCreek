# Your next steps (required before recovery runs)

The project scaffolding is ready. **You** must add your wallet artifacts and password fragments before any real recovery can run.

## Step 1 — Copy your wallet (do not move the original)

| Client | Source path |
|--------|-------------|
| Dogecoin Core | `%APPDATA%\Dogecoin\wallet.dat` |
| MultiDoge | `%APPDATA%\MultiDoge\` (find the wallet data file) |

Copy the file to:

```
artifacts\wallet.dat
```

Keep the original untouched. Work offline if possible.

## Step 2 — Add your known address

```powershell
Copy-Item artifacts\target-address.txt.example artifacts\target-address.txt
notepad artifacts\target-address.txt
```

Replace the placeholder with your real Dogecoin address (one line, starts with `D`). BTCRecover uses this to stop as soon as a password decrypts to the right keys.

## Step 3 — Document what you remember

Edit `tokens\notes.md` with length, word order, separators, case, years, and leet habits.

## Step 4 — Build your token list

Edit `tokens\tier1_high_confidence.txt`:

- Delete the example comment lines at the top.
- Add one password fragment per line (see comments in the file for `^`, `$`, `+`, and groups).
- Start narrow — only fragments you are most confident about.

Optional later: `tier2_variations.txt`, `tier3_typos.txt`.

## Step 5 — Validate and dry-run

```powershell
cd C:\path\to\dogecoin-recovery

.\scripts\check-wallet.ps1
.\scripts\run-tier1.ps1 -ListPassOnly
```

Review the candidate count. If it is over ~100,000, tighten tier1 before running a full recovery.

## Step 6 — Run recovery

```powershell
.\scripts\run-tier1.ps1
```

If tier1 fails, try tier2 then tier3:

```powershell
.\scripts\run-tier1.ps1 -Tier 2
.\scripts\run-tier1.ps1 -Tier 3
```

## Optional — GPU (hashcat + RTX 2070)

After `artifacts\wallet.dat` exists:

```batch
run-gpu-recovery.bat verify
run-gpu-recovery.bat extract
run-gpu-recovery.bat tier 1
```

Install hashcat if missing:

```powershell
.\scripts\install-hashcat.ps1
```

Mask attack when you know a fixed prefix:

```batch
run-gpu-recovery.bat mask YourKnownPrefix?d?d?d?d
```

Resume interrupted GPU run:

```batch
run-gpu-recovery.bat restore
```

## Resume after interrupt

```powershell
.\scripts\run-tier1.ps1 -Restore runs\autosave\tier1.sav
```

## When you succeed

1. Record the password securely.
2. Move funds to a new wallet with a fresh seed.
3. Delete or encrypt `artifacts\`, `hashes\`, and `generated\`.
