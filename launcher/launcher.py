from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

OWNER = "Mataiasu"
REPO = "Infinite-Ascension"
RELEASE_URL = f"https://api.github.com/repos/{OWNER}/{REPO}/releases/tags/latest"
GAME_WINDOWS = "InfiniteAscension.exe"
GAME_LINUX = "InfiniteAscension.x86_64"
LOCAL_VERSION = "version.json"


def http_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "Infinite-Ascension-Launcher"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def app_dir() -> Path:
    return Path(__file__).resolve().parent


def local_build() -> int:
    try:
        data = json.loads((app_dir() / LOCAL_VERSION).read_text(encoding="utf-8"))
        return int(data.get("build", 0))
    except (OSError, ValueError, json.JSONDecodeError):
        return 0


def target_asset() -> tuple[str, str]:
    system = platform.system().lower()
    if system == "windows":
        return "Infinite-Ascension-Windows.zip", GAME_WINDOWS
    if system == "linux":
        return "Infinite-Ascension-Linux.zip", GAME_LINUX
    raise RuntimeError(f"Plateforme non supportée par le launcher PC : {platform.system()}")


def get_latest() -> tuple[int, str, str]:
    release = http_json(RELEASE_URL)
    manifest_asset = next((a for a in release.get("assets", []) if a["name"] == "manifest.json"), None)
    if not manifest_asset:
        raise RuntimeError("La release latest ne contient pas manifest.json.")
    manifest = http_json(manifest_asset["browser_download_url"])
    asset_name, _ = target_asset()
    asset = next((a for a in release.get("assets", []) if a["name"] == asset_name), None)
    if not asset:
        raise RuntimeError(f"Build absente : {asset_name}")
    return int(manifest.get("build", 0)), asset["browser_download_url"], manifest.get("commit", "")


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Infinite-Ascension-Launcher"})
    with urllib.request.urlopen(request, timeout=120) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output)


def install(url: str) -> None:
    root = app_dir()
    with tempfile.TemporaryDirectory(prefix="infinite_ascension_") as temp:
        archive = Path(temp) / "game.zip"
        unpacked = Path(temp) / "unpacked"
        unpacked.mkdir()
        download(url, archive)
        with zipfile.ZipFile(archive, "r") as zf:
            zf.extractall(unpacked)
        for item in unpacked.iterdir():
            destination = root / item.name
            if destination.name.lower().endswith("launcher.exe"):
                continue
            if item.is_dir():
                if destination.exists():
                    shutil.rmtree(destination)
                shutil.copytree(item, destination)
            else:
                shutil.copy2(item, destination)


def launch() -> None:
    root = app_dir()
    system = platform.system().lower()
    executable = root / (GAME_WINDOWS if system == "windows" else GAME_LINUX)
    if not executable.exists():
        raise RuntimeError(f"Jeu introuvable : {executable}")
    if system == "linux":
        executable.chmod(executable.stat().st_mode | 0o111)
    subprocess.Popen([str(executable)], cwd=str(root))


def main() -> None:
    print("Infinite Ascension Launcher")
    try:
        latest_build, url, commit = get_latest()
        current = local_build()
        print(f"Version locale : {current} | dernière build : {latest_build}")
        if latest_build > current:
            print("Mise à jour disponible. Téléchargement...")
            install(url)
            print(f"Mise à jour terminée. Commit : {commit[:8]}")
        launch()
    except (urllib.error.URLError, OSError, RuntimeError, zipfile.BadZipFile) as exc:
        print(f"Erreur launcher : {exc}")
        print("Démarrage local du jeu si disponible...")
        try:
            launch()
        except Exception as fallback:
            print(f"Impossible de lancer le jeu : {fallback}")
            raise SystemExit(1)


if __name__ == "__main__":
    main()
