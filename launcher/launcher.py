from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

OWNER = "Mataiasu"
REPO = "Infinite-Ascension"
RELEASE_URL = f"https://api.github.com/repos/{OWNER}/{REPO}/releases/tags/latest"
LOCAL_VERSION = "version.json"
GAME = {"windows": "InfiniteAscension.exe", "linux": "InfiniteAscension.x86_64"}


def app_dir() -> Path:
    return Path(__file__).resolve().parent


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "Infinite-Ascension-Launcher"})
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def platform_key() -> str:
    system = platform.system().lower()
    if system == "windows":
        return "windows"
    if system == "linux":
        return "linux"
    raise RuntimeError(f"Plateforme PC non supportée : {platform.system()}")


def local_build() -> int:
    try:
        data = json.loads((app_dir() / LOCAL_VERSION).read_text(encoding="utf-8"))
        return int(data.get("build", 0))
    except (OSError, ValueError, json.JSONDecodeError):
        return 0


def latest_info() -> tuple[int, str, str, str]:
    release = get_json(RELEASE_URL)
    manifest_asset = next((a for a in release.get("assets", []) if a.get("name") == "manifest.json"), None)
    if not manifest_asset:
        raise RuntimeError("manifest.json absent de la release latest.")
    manifest = get_json(manifest_asset["browser_download_url"])
    key = platform_key()
    asset_info = manifest.get("assets", {}).get(key)
    if not asset_info:
        raise RuntimeError(f"Aucun build {key} dans latest.")
    return int(manifest.get("build", 0)), asset_info["url"], asset_info["sha256"], str(manifest.get("commit", ""))


def download(url: str, destination: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "Infinite-Ascension-Launcher"})
    with urllib.request.urlopen(req, timeout=180) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def install(url: str, expected_sha: str) -> None:
    root = app_dir()
    with tempfile.TemporaryDirectory(prefix="infinite_ascension_") as temp:
        archive = Path(temp) / "game.zip"
        unpacked = Path(temp) / "game"
        unpacked.mkdir()
        download(url, archive)
        actual = sha256(archive)
        if actual.lower() != expected_sha.lower():
            raise RuntimeError("Échec de vérification SHA-256 de la mise à jour.")
        with zipfile.ZipFile(archive, "r") as zf:
            zf.extractall(unpacked)
        for item in unpacked.iterdir():
            destination = root / item.name
            if item.is_dir():
                if destination.exists():
                    shutil.rmtree(destination)
                shutil.copytree(item, destination)
            else:
                shutil.copy2(item, destination)


def launch() -> None:
    key = platform_key()
    executable = app_dir() / GAME[key]
    if not executable.exists():
        raise RuntimeError(f"Exécutable introuvable : {executable}")
    if key == "linux":
        executable.chmod(executable.stat().st_mode | 0o111)
    subprocess.Popen([str(executable)], cwd=str(app_dir()))


def main() -> None:
    print("========================================")
    print("       INFINITE ASCENSION LAUNCHER")
    print("========================================")
    try:
        latest_build, url, expected_sha, commit = latest_info()
        current = local_build()
        print(f"Build locale : {current}")
        print(f"Build serveur : {latest_build}")
        if latest_build > current:
            print("Mise à jour disponible...")
            install(url, expected_sha)
            print(f"Mise à jour terminée ({commit[:8]}).")
        else:
            print("Jeu déjà à jour.")
        launch()
    except (urllib.error.URLError, OSError, RuntimeError, zipfile.BadZipFile) as exc:
        print(f"Mise à jour indisponible : {exc}")
        print("Tentative de lancement de la version locale...")
        try:
            launch()
        except Exception as fallback:
            print(f"Impossible de lancer le jeu : {fallback}")
            raise SystemExit(1)


if __name__ == "__main__":
    main()
