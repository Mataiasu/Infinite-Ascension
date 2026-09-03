from __future__ import annotations

# Bootstrap launcher skeleton for the PC build.
# Release/update implementation will be added once the first signed build exists.
# Intended flow:
# 1. Fetch GitHub release manifest
# 2. Select Windows/Linux package
# 3. Download to staging directory
# 4. Verify SHA-256
# 5. Swap installed build
# 6. Start game executable

if __name__ == "__main__":
    print("Infinite Ascension Launcher — bootstrap")
