# EverythingConstructable

FS25 mod that turns instant building placement into multi-phase construction projects with fenced sites, monthly progress, and resource delivery.

## Architecture

- `EverythingConstructable.lua` — Entry point, mod event listener, save/load
- `ECProjectManager.lua` — Project lifecycle, phase advancement, completion/cancellation
- `ECProject.lua` — Project data model
- `ECSiteDecorator.lua` — Places i3d decorations on construction sites using grid-based allocation
- `ECSiteVehicles.lua` — Spawns construction vehicles on site (farm 0, non-drivable)
- `ECFenceBuilder.lua` — Outer/inner fence construction
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

## Multiplayer

- Vehicle restrictions are client-side only. Two sync paths:
  1. `ECSiteVehicleEvent` — broadcast when vehicle loads on server
  2. `writeInitialClientState` / `readInitialClientState` — sends vehicle object IDs to late joiners
- Both feed into `pendingObjectIds` -> `pendingRestrictions` retry pipeline in `ECSiteVehicles.update()`

## Reference

- UsedEquipmentYards (`C:\Users\steve\Documents\My FS 25 Mods\FS25_UsedEquipmentYards`) — reference for vehicle spawning, restriction patterns, MP sync
- Game source: decompiled Lua in Reference/FS25_Lua
