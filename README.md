# SCP Facility-like map generator
## About

SCP-like facility map generator
[How to use?](./docs/how_to_use.md)

[Room pack tutorial](./docs/runtime_loader.md)

### Example room packs

[Different SCP game room packs](https://drive.google.com/drive/folders/1UmT7aUYJr4saZwcFIcxbodW9uFaHlFR8?usp=sharing)

### Games using this map generator

[SCP: Containment Procedures uses this map generator](https://github.com/Yni-Viar/scp-containmentprocedures)

### Other editions

[CLI version (needs update to current version)](https://github.com/Yni-Viar/scp-mapgen-cli)

[Unreal Engine Version (needs update to current version)](https://github.com/Yni-Viar/grid-mapgen-ue)

Unity (Coming soon...)


## License?
[MIT License](/LICENSE.MIT)
- If your project is licensed under CC-BY-SA 3.0, CC-BY-SA 4.0 or GPL 3 (e.g. *SCP - Containment Breach* remake), the Author grants You permission to relicense the code under mentioned licenses.

## What works:
- [x] Random generation (Both layout and not layout (AStar) based, can be switched by setting)
- [x] Single room support *\(supported only in Regular and Renderer map generator\)*
- [x] Large room support *\(supported only in Regular AStar and Renderer map generator\)*
- [x] Door support (currently only in 3D version)
- [x] Modular.
- [x] Randomized door + assign specific door to a room
- [x] Checkpoint support *Note, that these checkpoints work differently from Containment Breach ones*
- [x] Many zone support (both in x and y directions) (currently, there is a limit of 512 rooms in a single generator node, you can increase it in code, but this may affect the performance (especcialy in 3D))
- [x] Variable room spawn, based on room chance / guaranteed spawn.
- [x] Seamless double rooms, *\(supported only in Regular AStar and Infinite map generator\)*
- [x] This sample also includes room pack loader and layout saver (from GLTF to GLTF)

*[See MapGen comparison for more information](./docs/scp-mapgen-comparison.md)*

## Changelog
### v.12.0 (2026.04.14)
- Revamped double room system, and they are probably ready to be used, not experimental feature anymore! (Open issue, if you found a bug in that system!)
- Added second backend - Layout map generator, as well as re-organized backend system.
- \[MapGen Room Previewer\] Added different tonemappers.
- Fixed possibility of spawning two same single rooms.

### v.11.3 (2026.01.15)
- EVEN MORE PERFORMANCE!!! Lowered average map generation time to ~ 1.1 ms (both backend and 3d frontend, tested on default 8x8 map x 1 zone)
### v.11.2 (2026.01.12)
- \[MapGen 3D frontend\] Add HLOD support for 3D models (it is `off` by default, and is `on` in `Demo app`)
- \[MapGen Room Previewer\] Refactor scene saver; introduce new Renderer frontend to save rooms as GLTF.
- \[MapGen Room Previewer\] You can no longer generate gltf scene on Android (because it requires multiple file creation AND for performance)

---

These changes improve performance A LOT!
### v.11.1 (2026.01.07)
- \[MapGen Room Previewer\] Added support for Web platform **(only handles preview, large >1GB ZIP files still NOT recommended to use in Web editor)**
- Synchronized map generator random.
### v.11.0 (2026.01.04)
- Added support for infinite facility (tweaked backend and added new 3d front-end) (room previewer not supported for semi-infinite map generation)
### v.10.4 (2025.12.30)
- \[MapGen Room Previewer\] Introduced v2 package format, but v1 is still supported.
- \[MapGen Room Previewer\] Added lighting toggle (because Blender lights are too bright for Godot (incompatibility))
### v.10.3 (2025.12.28)
- \[MapGen Room Previewer\] Android support
- Added support for native GLTF load in map generator + implemented cache for this feature.
### v.10.2 (2025.12.27)
- \[MapGen Room Previewer\] Added zoom in-zoom out from SCP: Containment Procedures
- \[MapGen Room Previewer\] Added layout exporter
### v.10.1 (2025.12.26)
- No generic map generation changes (except now room scene root can be every node3d), but...
- \[MapGen Room Previewer\] Added room previewer, which can load room packs.
### v.10.0 (2025.12.25)
- Double room overhaul - Double room creation became easier + supported also Room2C and Room3
### v.9.1 (2025.09.29)
- Fixed some rooms could not spawn due to unduplicated resources.
- Fixed double rooms spawn.
### v.9.0 (2025.07.31)
- Added support for double rooms (currently only for hallways and X-shaped crossrooms, and only as single rooms)
- Remove outdated 2D frontend (you can create your own 2D frontend, based on 8.x code)
### v.8.1 (2025.05.11)
- Single rooms (but not large) are also affected by room chance. *(3D version only!!!)*
- Improved MapGen 3D frontend code.
### v.8.0 (2025.04.24)
- Finally added checkpoints!
- Room can have a specific door set (as seen in *SCP: Secret Lab 14.0 and newer*)
- Reworked better zone generator again (it was reverted to previous behavior, but without hanging (tried multiple seeds))
- Separated MapGeneration core from 2D and 3D version, making it more portable. Now 2D and 3D frontend are representing only room spawn, while core backend does all.
### v.7.3 (2025.04.23)
- Fixed a generation error when generating many-zone facility (especially, when zone amount was >= 4).
### v.7.2 (2025.03.31)
- Add 2D version
- Add editor icons
- Fix bug, where MapGen could not connect on X axis more than once (which lead to disconnected generation)
### v.7.1 (2024.12.18)
- Fixed too straigh map generation by created toggleable *Better map generation* parameter. Now the map generation looks like a SCP: Containment Breach one
- Added documentation
- Replaced SCP: Site Online rooms with cubes (for better visibility of generation)
### v.7.0 (2024.11.29)
- Zones can be horizontal, not just vertical.
- Added support for room resources in map gen (e.g. for map gen HUD)
### v.6.2 (2024.11.06)
- More straight corridors! - changed the heuristic, how map is generated.
### v.6.1 (2024.11.06)
- Added more types of large rooms (previously only endrooms were supported)
### v.6.0 (2024.11.05)
- Added SCP-CB like large room support (no more using a hack)
### v.5.1 (2024.11.03)
- Add support for custom doors, as seen in *SCP: Secret Lab 14.0*
- Removed SCP-CB rooms (Research, or Entrance zone)
### v.5.0 (2024.XX.XX)
- Rewrite the entire algorithm to new one (AStar).
### v.3.0 (2023.06.01)
- Actually, the first version of my own map generator, map generator v2 and v1 are just third-party map generators (and v2 was under unknown license)