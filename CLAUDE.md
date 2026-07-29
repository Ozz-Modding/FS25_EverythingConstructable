# EverythingConstructable

FS25 mod that turns instant building placement into multi-phase construction projects with fenced sites, monthly progress, and resource delivery.

## Architecture

- `EverythingConstructable.lua` — Entry point, mod event listener, save/load
- `ECProjectManager.lua` — Project lifecycle, phase advancement, completion/cancellation
- `ECProject.lua` — Project data model
- `ECSiteDecorator.lua` — Places i3d decorations on construction sites using grid-based allocation
- `ECSiteVehicles.lua` — Spawns construction vehicles on site (farm 0, non-drivable)
- `ECFenceBuilder.lua` — Outer/inner/pasture fence construction using cloned i3d panel nodes (no placeable system)
- `ECBuildingPlacer.lua` — Final building placement on completion
- `ECPalletCollector.lua` — Resource delivery trigger
- `ECConfig.lua` — All configuration constants, decoration/vehicle definitions
- `events/` — Network events for MP sync

## Key Patterns

- Vehicle spawning uses `VehicleLoadingData` API. Callback signature: `(self, loadedVehicles, loadState, args)` where `loadedVehicles` is a table. Check `VehicleLoadingState.OK`.
- Vehicles removed with `vehicle:delete()`, not `g_currentMission:removeVehicle()`.
- Blocking driving: `registerPlayerVehicleControlAllowedFunction` + `setIsTabbable(false)`. These are client-local — must apply on each client via event + retry queue (spec_drivable may not exist yet).
- Site decorations and vehicles share a grid system (1m cells). Vehicles mark cells first, decorations respect them.
- `StoreItemUtil.getSizeValues(xmlFilename, "vehicle", rotation, config)` for pre-spawn dimensions.
- Fences are placed by cloning named nodes from `assets/fence/Fence01.i3d` via `getChild(root, name)`. All panel TGs have `visibility="false"` by default — must call `setVisibility(c, true)` after cloning. Call `addToPhysics(c)` to enable collision, `removeFromPhysics(c)` before `delete(c)`. panel04 outer TG contains two sub-panels — clone `getChildAt(panel04Group, 0)` to get a single panel. Panels are start-edge aligned (mesh extends from Z=0 to Z=panelLength along the forward direction).

## Multiplayer

- Vehicle restrictions are client-side only. Two sync paths:
  1. `ECSiteVehicleEvent` — broadcast when vehicle loads on server
  2. `writeInitialClientState` / `readInitialClientState` — sends vehicle object IDs to late joiners
- Both feed into `pendingObjectIds` -> `pendingRestrictions` retry pipeline in `ECSiteVehicles.update()`
- Fences are built client-side from streamed `fenceCorners`/`innerFenceCorners` data. Three build sites: `ECCreateProjectEvent.run` (live broadcast), `onProjectCreatedOnClient` (late-joiner via `readInitialClientState`), and `onStartMission` (server load). All three must call `ECFenceBuilder.buildFence`.
- `migrateLegacyFencePlaceable` in `EverythingConstructable.lua` removes old pre-1.0.0.2 fence segments on first load, matched by project corner coordinates only.

## Reference

- UsedEquipmentYards (`C:\Users\steve\Documents\My FS 25 Mods\FS25_UsedEquipmentYards`) — reference for vehicle spawning, restriction patterns, MP sync
- Game source: decompiled Lua in C:\Users\steve\Documents\My FS 25 Mods\Reference\FS25_Lua
