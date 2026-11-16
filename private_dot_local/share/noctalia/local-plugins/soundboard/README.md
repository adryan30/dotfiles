# Soundboard (local Noctalia plugin)

Launcher provider: type `/sb` in the Noctalia launcher, filter clips, Enter to play into the PipeWire `soundboard` sink (Voice Chat / Discord).

## Enable

Path source `local` → `~/.local/share/noctalia/local-plugins`, then enable `potato/soundboard`.

```sh
noctalia msg plugins source add local path ~/.local/share/noctalia/local-plugins
noctalia msg plugins enable potato/soundboard
```

Or open Settings → Plugins and enable **Soundboard**.
