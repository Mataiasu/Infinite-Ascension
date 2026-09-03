# Architecture

## Client
Godot 4.x. Same gameplay codebase for Windows, Linux and Android.

## Multiplayer
Authoritative server. The client sends player intents/state; the server owns the authoritative world state.

## Dynamic frontier
The server computes the average level of the active group and derives the next frontier range. The frontier can trigger a content-generation job.

## AI
Ollama is treated as a content-generation service. It receives constrained prompts and returns structured content. Validation must happen before content enters the authoritative world state.

## Reborn
Temporary progression resets; persistent progression remains. The world itself does not reset.

## Launcher / releases
PC builds will use GitHub Releases. A separate launcher will check the latest release manifest, download the matching platform build, verify its checksum and launch the game. The game executable itself should not self-replace while running.
