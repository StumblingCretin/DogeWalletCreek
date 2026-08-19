# Microsoft Defender & Windows Security Exclusions for Wallet Recovery

BTCRecover, bitcoin2john, and Hashcat are legitimate, open-source recovery tools. Antivirus engines (like Microsoft Defender) often flag them with false positives (e.g., `HackTool:Win32/Hashcat`, `PUA:Win32/Tool.Password`, or `Trojan:Win32/Wacatac`) because they contain cryptographic brute-force and hash extraction routines similar to malware analysis tools.

---

## Method 1: Fast One-Line PowerShell Command (Admin)

Open **PowerShell as Administrator** (Right-click Start → *Terminal (Admin)* or *PowerShell (Admin)*), navigate to your repository folder, and run:

```powershell
Add-MpPreference -ExclusionPath "$((Get-Item .).FullName)"
```

Or specify your exact folder path:

```powershell
Add-MpPreference -ExclusionPath "C:\path\to\dogecoin-recovery"
```

To verify the exclusion was added:
```powershell
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
```

---

## Method 2: Step-by-Step GUI (Windows 10 / 11)

### 1. Folder Exclusion
1. Open the Start menu, search for **Windows Security**, and press <kbd>Enter</kbd>.
2. Click on **Virus & threat protection** in the left sidebar.
3. Under **Virus & threat protection settings**, click **Manage settings**.
4. Scroll down to the **Exclusions** section and click **Add or remove exclusions**.
5. Click the **+ Add an exclusion** button and select **Folder**.
6. Browse and select your project folder (e.g. `C:\path\to\dogecoin-recovery`).
7. Click **Yes** on the User Account Control (UAC) prompt.

### 2. Process Exclusions (Optional)
If Windows Defender blocks `python.exe` or `hashcat.exe` execution:
1. In the same **Add an exclusion** menu, click **+ Add an exclusion** → **Process**.
2. Type `python.exe` and click **Add**.
3. Type `hashcat.exe` and click **Add**.

---

## Handling Microsoft Defender SmartScreen Popups

When launching portable binaries (like `hashcat.exe` or extraction utilities), SmartScreen may display:

> **Windows protected your PC**  
> *Microsoft Defender SmartScreen prevented an unrecognized app from starting...*

### To Run:
1. Click the underlined link: **"More info"**.
2. A new button will appear at the bottom right: click **"Run anyway"**.

---

## Granular Subfolder Exclusions (Alternative)

If you prefer not to whitelist the entire repository, you can add individual subfolders:

```powershell
Add-MpPreference -ExclusionPath "C:\path\to\dogecoin-recovery\tools"
Add-MpPreference -ExclusionPath "C:\path\to\dogecoin-recovery\scripts"
Add-MpPreference -ExclusionPath "C:\path\to\dogecoin-recovery\hashes"
Add-MpPreference -ExclusionPath "C:\path\to\dogecoin-recovery\runs"
```

---

## Removing Exclusions (Post-Recovery Cleanup)

Once you have recovered your wallet and transferred your funds, you can safely remove the exclusion:

```powershell
Remove-MpPreference -ExclusionPath "C:\path\to\dogecoin-recovery"
```
