# Infinite Ascension — automatic session logs

The Windows launcher already captures Godot stdout/stderr locally. This Worker is the secure bridge that can commit each session log to `logs/sessions/` without putting a GitHub token inside the launcher or APK.

## Cloudflare Worker setup

1. Create a Cloudflare Worker from `log-ingest/worker.js`.
2. Add Worker secrets:
   - `GITHUB_TOKEN`: a fine-grained GitHub token restricted to `Mataiasu/Infinite-Ascension`, with **Contents: Read and write**.
   - `GITHUB_REPO`: `Mataiasu/Infinite-Ascension`.
3. Deploy the Worker.
4. Put the Worker HTTPS URL in the launcher as `LAUNCHER_LOG_ENDPOINT`.

The GitHub token stays server-side. Never put it in `Program.cs`, the Godot project, an APK, or a release asset.

## Payload

The launcher will POST JSON in this shape:

```json
{
  "build": 8,
  "session": "...",
  "log": "..."
}
```

The Worker creates one file per session under `logs/sessions/`.

## Important

The Worker is intentionally not deployed automatically by the game CI. A Cloudflare account/deployment is required once. After that, the launcher can upload logs automatically whenever the game closes, and the repository connector can inspect those committed logs.
