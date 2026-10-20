# In-game updates (v1.1+)

Players can update Night Harvest from **Settings › Updates** without reinstalling and
without losing their farms. This page explains how it works and how the team publishes
an update.

## How it works for players

1. Settings › Updates shows the installed version and checks for a newer one
   (automatically on every launch, unless "Check automatically" is turned off).
2. When an update exists, **DOWNLOAD & INSTALL** downloads it and verifies it.
3. **RESTART NOW** saves the game and restarts it on the new version.

Save files (`user://saves/`) and settings (`user://settings.cfg`) are never touched.
On Windows these live in `%APPDATA%\Godot\app_userdata\Night Harvest Game\`.

If an update ever fails to start, the next launch skips it automatically and plays the
base version. Players can also press **REMOVE** under "Installed update" to go back.

## How it works technically

* `scripts/update_manager.gd` is the **first** autoload. Before any other script or
  scene loads, it loads the newest downloaded `.pck` from `user://updates/` on top of
  the game files (`ProjectSettings.load_resource_pack`).
* A small JSON **manifest** online tells the game what the newest version is.
* Updates are skipped while running from the Godot editor, so they never hide your
  project files during development.

## Publishing an update (step by step)

1. **Bump the version** of what you are releasing, e.g. `1.1.1`, in your notes
   (do *not* change `BASE_VERSION` in `update_manager.gd`; that is only for full
   reinstall builds — see below).
2. **Export a patch pack** in Godot: *Project › Export… › Windows Desktop ›
   Export PCK/ZIP…*, save as `night_harvest_1.1.1.pck`.
   (Or from a terminal: `godot --headless --export-pack "Windows Desktop" night_harvest_1.1.1.pck`.)
   Use the same Godot version as the released game (4.7.x).
3. **Get its size and SHA-256** (Windows PowerShell):
   `Get-FileHash night_harvest_1.1.1.pck -Algorithm SHA256` and
   `(Get-Item night_harvest_1.1.1.pck).Length`.
4. **Upload the .pck** somewhere public, e.g. a GitHub Release
   (`https://github.com/<user>/<repo>/releases/download/v1.1.1/night_harvest_1.1.1.pck`).
5. **Update `updates/manifest.json`** in the repository and push it:

```json
{
  "version": "1.1.1",
  "pck_url": "https://github.com/<user>/<repo>/releases/download/v1.1.1/night_harvest_1.1.1.pck",
  "sha256": "<hash from step 3, lowercase>",
  "size": 7833064,
  "min_base": "1.1.0",
  "notes": ["Fixed the barn door", "New crop: pumpkins"]
}
```

Every player who opens the game afterwards gets the update offer.

### Where the game looks for the manifest

Project Settings › `night_harvest/updates/manifest_url` (in `project.godot`). It points
at `https://raw.githubusercontent.com/lilzamdev/Night-Harvest/main/updates/manifest.json`.
**Change it to your real repository/branch before you ship the first build**, because
the URL baked into that build is the one players will use.

### What a patch can and cannot change

* ✅ Scenes, scripts, art, sounds, maps, balance — anything inside `res://`.
* ❌ New **autoloads**, project settings or a different Godot engine version need a
  full reinstall. For those, release a new full build, raise `BASE_VERSION` in
  `scripts/update_manager.gd`, and set `"min_base"` in the manifest to that version so
  older installs are told to reinstall instead of downloading a patch.

## Testing an update locally

1. Export a pack from a copy of the project with a visible change.
2. Serve a folder with the pack and a manifest: `python -m http.server 8765`.
3. Temporarily set `night_harvest/updates/manifest_url` to `http://127.0.0.1:8765/manifest.json`
   in an **exported** build (or set the environment variable `NH_TEST_PATCH=1` to allow
   loading packs when running from the editor binary).
