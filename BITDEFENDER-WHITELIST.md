# Bitdefender Whitelisting Guide

Bitdefender often flags `tools/hashcat/hashcat.exe` and `tools/btcrecover/` as `Gen:Variant.Lazy`, `HackTool`, or `CoinMiner` false positives.

Follow these steps to prevent Bitdefender from blocking or deleting files during recovery.

---

## 1. Antivirus Folder Exception (Full Project)

1. Open **Bitdefender**.
2. Go to **Protection** (shield icon on the left).
3. Under **Antivirus**, click **Open** (or the settings gear).
4. Click the **Exceptions** (or **Exclusions**) tab.
5. Click **+ Add Exception**.
6. Set path to the project root folder:
   ```
   C:\path\to\dogecoin-recovery
   ```
7. Enable both toggles:
   - **Antivirus**: ON
   - **Advanced Threat Defense (ATD)**: ON
8. Click **Save**.

---

## 2. Advanced Threat Defense (ATD) Application Exceptions

If Bitdefender blocks process execution while running attacks, add process exceptions:

1. In Bitdefender, go to **Protection** → **Advanced Threat Defense** → **Settings**.
2. Under **Manage Exceptions**, click **+ Add an exception**.
3. Add the following binaries:
   ```
   C:\path\to\dogecoin-recovery\tools\hashcat\hashcat.exe
   C:\path\to\dogecoin-recovery\run-gpu-recovery.bat
   ```
4. Set protection level to **Excluded** and save.

---

## 3. If Bitdefender Already Quarantined a File

If `hashcat.exe` or `btcrecover.py` disappeared:

1. In Bitdefender, go to **Protection** → **Antivirus** → **Quarantine**.
2. Find the quarantined file (`hashcat.exe` or python script).
3. Click **Restore** (or **Restore and Add Exception**).
4. Re-verify the file is back:
   ```powershell
   Test-Path tools\hashcat\hashcat.exe
   ```

---

## 4. Post-Recovery Cleanup

Once recovery is complete and funds have been moved:
1. Delete temporary hashes and wordlists.
2. Remove the Bitdefender exceptions if you no longer need them.
