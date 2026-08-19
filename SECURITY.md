# Security Policy

## ⚠️ Critical User Safety Notice

This toolkit is designed exclusively for recovering access to **your own** lost or forgotten Dogecoin wallets.

### Absolute Safety Rules:
1. **NEVER share or upload `wallet.dat`**: Never post your wallet file, raw byte dumps, or extracted hash files (`wallet.hash`) to GitHub issues, public forums, Discord, or cloud drives.
2. **NEVER post private keys or recovered passwords**: Redact all private keys, potfiles (`hashcat.potfile`), and password hints before asking for technical help.
3. **Work Offline on Copies**: Always make a backup copy of your original `wallet.dat` and keep the original untouched. When running recovery attacks, perform the work on an offline machine whenever possible.
4. **Post-Recovery Fund Safety**: As soon as you recover your wallet password, **immediately transfer all funds to a newly generated wallet** with a brand new recovery phrase/seed.

---

## Reporting a Vulnerability

If you discover a security vulnerability or bug in the scripts that could lead to unintended data leakage:

1. **Do NOT open a public GitHub issue.**
2. Please create a private advisory via GitHub's **Security Advisory** tab or contact the repository maintainers privately.
3. Include detailed steps to reproduce the issue along with the affected platform/OS version.
