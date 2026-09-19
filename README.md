# Sleepus MK3 Updater and Game Packs

Static Chrome/Edge WebUSB updater for the AT32 factory DFU bootloader (`2E3C:DF11`). It has two bounded update paths:

- Core firmware from `firmware/manifest.json`, written from `0x08000000` and constrained below `0x080C0000`.
- Game packs from `gamepacks.json`, written only to the Lua archive partition at `0x080C0000` through `0x080FDFFF`.

Core updates and game-pack installs use sector erase commands and preserve the Lua settings slots at `0x080FE000` and `0x080FF000`.

## Publish a game pack

1. Put the Lua source in `packs/<id>.lua`.
2. Calculate its SHA-256:

```powershell
(Get-FileHash .\packs\<id>.lua -Algorithm SHA256).Hash.ToLowerInvariant()
```

3. Add an `available` pack entry to `gamepacks.json` with `sourceUrl` and `sourceSha256`.
4. The browser verifies the source hash, builds the firmware-compatible `SLUA` archive locally, validates both CRC-32 fields, then flashes only the script partition.

Use `coming-soon` for catalog placeholders; those entries cannot be selected or flashed.

## Publish a core release

Create a raw core-only binary that ends before `0x080C0000`, place it in `firmware/`, then update `firmware/manifest.json` with its size and SHA-256. Do not publish a combined core-and-script binary as a core release.

## Local preview

```powershell
python -m http.server 8766
```

Open `http://localhost:8766/updater.html` in Chrome or Edge. WebUSB requires HTTPS outside localhost.
