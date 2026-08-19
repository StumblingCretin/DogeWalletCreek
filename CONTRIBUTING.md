# Contributing to Dogecoin Recovery

Thank you for your interest in improving this Dogecoin recovery toolkit! Contributions that enhance performance, expand GPU profile support, or improve documentation are welcome.

---

## Guidelines for Contributions

1. **Safety First**:
   - Never commit sample wallets with real funds or private keys.
   - Ensure all sample test vectors use public test hashes or unit test vectors.

2. **Cross-Platform & Dependency Minimization**:
   - Favor pure-Python solutions (like the built-in Berkeley DB page parser) to avoid compiled C-extension dependencies on modern Python versions.
   - Ensure batch and PowerShell scripts handle paths with spaces and generic drive letters.

3. **Code Style**:
   - Python: Follow PEP 8 style guidelines.
   - PowerShell: Use clear parameter definitions, standard verb-noun cmdlet naming, and proper error action handling.

---

## How to Submit Changes

1. **Fork the repository** on GitHub.
2. **Create a topic branch**:
   ```bash
   git checkout -b feature/your-improvement
   ```
3. **Commit your changes** with a clear message:
   ```bash
   git commit -m "Add RTX 4090 GPU tuning profile"
   ```
4. **Push to your branch**:
   ```bash
   git push origin feature/your-improvement
   ```
5. **Open a Pull Request** describing your changes and testing methodology.
