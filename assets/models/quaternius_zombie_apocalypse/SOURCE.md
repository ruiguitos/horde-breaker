# Quaternius Zombie Apocalypse Kit

- Source: https://quaternius.com/packs/zombieapocalypsekit.html
- Author: Quaternius
- Original pack date: March 2024
- Imported on: 2026-07-17
- License: CC0 1.0 Universal
- License URL: https://creativecommons.org/publicdomain/zero/1.0/

Only the models required for the visual prototype were imported:

- `characters/Characters_Matt.gltf` — Recruit test model
- `characters/Characters_Lis.gltf` — Renegade test model
- `characters/Characters_Sam.gltf` — Medic test model
- `enemies/Zombie_Basic.gltf` — Normal Zombie test model
- `enemies/Zombie_Chubby.gltf` — Runner Zombie test model
- `weapons/Rifle.gltf` — Assault Rifle test model
- `weapons/Pistol.gltf` — Pistol test model
- `weapons/Shotgun.gltf` — Shotgun test model

The character files also contain matching weapon meshes already attached to the
hand rig. Gameplay displays those embedded meshes so the active firearm follows
the character animation correctly. The isolated weapon files are retained as
clean references for later weapon previews and attachment work.

Godot extracted each embedded atlas as a neighbouring
`*_Zombie_Atlas.png` file during import. Those small textures and their
`.import` metadata are kept so the same import is reproducible on another
computer.

The original `License.txt` included with the download is preserved in this
folder. Its header refers to another Quaternius pack, but the license text is
CC0 and the official Zombie Apocalypse Kit page also identifies this pack as
CC0.
