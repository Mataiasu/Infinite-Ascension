from __future__ import annotations

import hashlib
import json
import platform
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.request
import zipfile
from pathlib import Path
import tkinter as tk
from tkinter import messagebox, ttk

OWNER = "Mataiasu"
REPO = "Infinite-Ascension"
MANIFEST_URL = f"https://github.com/{OWNER}/{REPO}/releases/download/latest/manifest.json"
STATE_FILE = "launcher_state.json"
GAME = {"windows": "InfiniteAscension.exe", "linux": "InfiniteAscension.x86_64"}


def base_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def platform_key() -> str:
    system = platform.system().lower()
    if system in GAME:
        return system
    raise RuntimeError(f"Plateforme non supportée : {platform.system()}")


def get_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "Infinite-Ascension-Launcher/1.1",
        "Cache-Control": "no-cache",
    })
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def local_build() -> int:
    try:
        return int(json.loads((base_dir() / STATE_FILE).read_text(encoding="utf-8")).get("build", 0))
    except (OSError, ValueError, json.JSONDecodeError):
        return 0


def save_build(build: int, commit: str) -> None:
    (base_dir() / STATE_FILE).write_text(
        json.dumps({"build": build, "commit": commit}, indent=2), encoding="utf-8"
    )


def download(url: str, destination: Path, progress) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Infinite-Ascension-Launcher/1.1"})
    with urllib.request.urlopen(request, timeout=300) as response, destination.open("wb") as output:
        total = int(response.headers.get("Content-Length", "0"))
        done = 0
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            output.write(block)
            done += len(block)
            if total:
                progress(done / total)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def game_path() -> Path:
    return base_dir() / GAME[platform_key()]


def install_game(manifest: dict, status_cb, progress_cb) -> None:
    asset = manifest["assets"][platform_key()]
    with tempfile.TemporaryDirectory(prefix="infinite_ascension_update_") as temp:
        temp_path = Path(temp)
        archive = temp_path / asset["name"]
        extracted = temp_path / "game"
        extracted.mkdir()
        status_cb("Téléchargement de la mise à jour…")
        download(asset["url"], archive, progress_cb)
        status_cb("Vérification de l'intégrité…")
        if sha256(archive).lower() != str(asset["sha256"]).lower():
            raise RuntimeError("La vérification SHA-256 a échoué.")
        status_cb("Installation de la mise à jour…")
        with zipfile.ZipFile(archive, "r") as zf:
            zf.extractall(extracted)
        if not (extracted / GAME[platform_key()]).exists():
            raise RuntimeError("L'exécutable du jeu est absent du package.")
        for item in extracted.iterdir():
            destination = base_dir() / item.name
            if item.is_dir():
                if destination.exists():
                    shutil.rmtree(destination)
                shutil.copytree(item, destination)
            else:
                shutil.copy2(item, destination)
    save_build(int(manifest["build"]), str(manifest.get("commit", "")))
    progress_cb(1.0)


def launch_game() -> None:
    executable = game_path()
    if not executable.exists():
        raise RuntimeError("Le jeu n'est pas installé.")
    if platform_key() == "linux":
        executable.chmod(executable.stat().st_mode | 0o111)
    subprocess.Popen([str(executable)], cwd=str(executable.parent))


class LauncherApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("Infinite Ascension Launcher")
        self.root.geometry("660x440")
        self.root.minsize(560, 390)
        self.root.resizable(False, False)
        self.root.configure(bg="#090c15")
        self.busy = False

        tk.Label(self.root, text="INFINITE ASCENSION", font=("Segoe UI", 25, "bold"), fg="#f1efff", bg="#090c15").pack(pady=(28, 2))
        tk.Label(self.root, text="LAUNCHER", font=("Segoe UI", 11, "bold"), fg="#a66cff", bg="#090c15").pack()

        self.version_label = tk.Label(self.root, text=f"Build locale : #{local_build()}", font=("Segoe UI", 10), fg="#a8b1ca", bg="#090c15")
        self.version_label.pack(pady=(20, 4))
        self.status_label = tk.Label(self.root, text="Vérification des mises à jour…", font=("Segoe UI", 10), fg="#d9def1", bg="#090c15", wraplength=580)
        self.status_label.pack(pady=4)

        self.progress = ttk.Progressbar(self.root, orient="horizontal", mode="determinate", length=520)
        self.progress.pack(pady=18)

        controls = tk.Frame(self.root, bg="#090c15")
        controls.pack(pady=8)
        self.launch_button = tk.Button(controls, text="▶  JOUER", command=self.launch, width=20, height=2, bg="#6e43bf", fg="white", activebackground="#8859df", relief="flat", font=("Segoe UI", 11, "bold"))
        self.launch_button.grid(row=0, column=0, padx=6)
        self.update_button = tk.Button(controls, text="↻  METTRE À JOUR", command=self.check_updates, width=20, height=2, bg="#202940", fg="white", activebackground="#303b5c", relief="flat", font=("Segoe UI", 10, "bold"))
        self.update_button.grid(row=0, column=1, padx=6)

        tk.Label(self.root, text="Vérification automatique à chaque ouverture.\nChaque push publié construit une nouvelle version du jeu.", font=("Segoe UI", 9), fg="#68738f", bg="#090c15", justify="center").pack(side="bottom", pady=22)
        self.root.after(250, self.check_updates)

    def status(self, text: str) -> None:
        self.root.after(0, lambda: self.status_label.config(text=text))

    def progress_value(self, value: float) -> None:
        self.root.after(0, lambda: self.progress.config(value=max(0, min(100, value * 100))))

    def set_busy(self, busy: bool) -> None:
        self.busy = busy
        state = "disabled" if busy else "normal"
        self.root.after(0, lambda: (self.launch_button.config(state=state), self.update_button.config(state=state)))

    def check_updates(self) -> None:
        if self.busy:
            return
        self.set_busy(True)
        threading.Thread(target=self._check_updates, daemon=True).start()

    def _check_updates(self) -> None:
        try:
            manifest = get_json(MANIFEST_URL)
            remote = int(manifest.get("build", 0))
            local = local_build()
            self.root.after(0, lambda: self.version_label.config(text=f"Build locale : #{local}  ·  Disponible : #{remote}"))
            if not game_path().exists() or remote > local:
                install_game(manifest, self.status, self.progress_value)
                self.status(f"Jeu à jour — build #{remote}.")
                self.root.after(0, lambda: self.version_label.config(text=f"Build installée : #{remote}  ·  À jour"))
            else:
                self.progress_value(1.0)
                self.status("Jeu déjà à jour.")
        except Exception as exc:
            if game_path().exists():
                self.status(f"Mise à jour indisponible : {exc} · lancement possible avec la version locale.")
            else:
                self.status(f"Impossible d'installer le jeu : {exc}")
        finally:
            self.set_busy(False)

    def launch(self) -> None:
        try:
            if not game_path().exists():
                self.check_updates()
                return
            launch_game()
            self.root.destroy()
        except Exception as exc:
            messagebox.showerror("Infinite Ascension", str(exc))

    def run(self) -> None:
        self.root.mainloop()


if __name__ == "__main__":
    LauncherApp().run()
