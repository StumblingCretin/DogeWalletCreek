# Bitdefender exclusions for wallet recovery

BTCRecover, bitcoin2john, and hashcat are legitimate recovery tools. Antivirus products flag them because they decrypt wallets and test password candidates — the same behavior as malware password stealers.

## Recommended: one folder exclusion

Add this folder and enable **Antivirus**, **Online Threat Prevention**, and **Advanced Threat Defense** (if shown):

```
C:\Users\Jig\dogecoin-recovery
```

This covers scripts, tools, wallet copies, hashes, and run output in one step.

## Optional: granular folder exclusions

```
C:\Users\Jig\dogecoin-recovery\tools
C:\Users\Jig\dogecoin-recovery\scripts
C:\Users\Jig\dogecoin-recovery\artifacts
C:\Users\Jig\dogecoin-recovery\hashes
C:\Users\Jig\dogecoin-recovery\generated
C:\Users\Jig\dogecoin-recovery\runs
```

## Process exclusions (Advanced Threat Defense)

ADT only accepts `.exe` files. Add under **Protection → Advanced Threat Defense → Settings → Manage exceptions**:

```
C:\Python313\python.exe
```

Also add after you install hashcat:

```
C:\Users\Jig\dogecoin-recovery\tools\hashcat\hashcat.exe
C:\Users\Jig\dogecoin-recovery\run-gpu-recovery.bat
```

Do **not** globally exclude `powershell.exe` — the project folder exclusion is enough for recovery scripts.

## Step-by-step (Bitdefender on Windows)

### Folder / file exclusions

1. Open **Bitdefender**
2. **Protection** → **Antivirus** → **Open**
3. **Settings** tab → **Manage exceptions**
4. **+ Add exception** → **Folder** → `C:\Users\Jig\dogecoin-recovery`
5. Turn on **Antivirus** (and other modules if listed)
6. **Save**

### Process exclusions

1. **Protection** → **Advanced Threat Defense** → **Open**
2. **Settings** → **Manage exceptions**
3. Add `python.exe` (full path from `where.exe python`)
4. **Save**

If downloads or script writes still fail, check **Ransomware Protection** / **Safe Files** for blocked paths.

Official help: [Bitdefender — Add an Antivirus Exception](https://www.bitdefender.com/consumer/support/answer/125476/)

## After whitelisting — restore missing files

| Missing item | Fix |
|--------------|-----|
| `tools\bitcoin2john.py` | `.\scripts\setup-tools.ps1` |
| `tools\hashcat\hashcat.exe` | Download from https://hashcat.net/hashcat/ and extract to `tools\hashcat\` |
| `artifacts\wallet.dat` | Copy from `%APPDATA%\Dogecoin\wallet.dat` |
| `artifacts\target-address.txt` | Copy from `target-address.txt.example` and edit |

```powershell
cd C:\Users\Jig\dogecoin-recovery
.\scripts\setup-tools.ps1
.\scripts\check-wallet.ps1
```
