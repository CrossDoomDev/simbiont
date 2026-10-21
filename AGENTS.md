# Symbiont

This repository is the native Godot project. Open `project.godot`; its main scene is `scenes/main.tscn`. Use Godot **4.7.1**, GL Compatibility, native TileMapLayer/TileSet and AnimatedSprite2D/SpriteFrames/AnimationPlayer.

## Product and visual constraints

- Keep the gameplay field strictly top-down. The host and symbiote are a single character; the organic weapon belongs on the character's anatomical right arm in every direction and frame.
- The ship is a living organism. Use membranes, ribs, vessels and organs; game UI is an overlay. Do not add physical computers, portals, flight, a separate symbiote companion or experience levels.
- Resources are shared between permanent host upgrades and ship restoration. Extraction is available through the menu only after the mission objective; do not silently overwrite saved progress.
- The ship reference, current iteration scope and verification limits are in `docs/NEXT_ITERATION.md`. See `docs/VERIFICATION.md` for dated execution results.
- Preserve editable scenes, atlas sources, prompts and reproducible generation scripts. Capture actual running viewports when verifying graphics; generated concept art is not a runtime screenshot.

## Cloud checks

```bash
bash tools/setup_cloud.sh
export PATH="$HOME/.local/bin:$PATH"
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r tools/requirements.txt
bash tools/check_cloud.sh
```

The test suites use isolated save files. Rendering screenshots requires a graphics context; the headless suites do not verify final appearance. `tools/bake_scenes.gd` regenerates the three editable world scenes and six SpriteFrames resources after world/atlas changes.

Do not commit `.godot/`, build outputs, credentials, personal saves or test logs. Keep deliberate screenshots under `artifacts/screenshots/`. Do not introduce machine-specific absolute paths.
