# Devices that failed the simulator smoke test

Written by `scripts/device-smoke.sh`: devices that were tried and left out of `manifest.xml`, with the first error seen. A device that passes a later run is removed from this list. The simulator may differ from a real watch.

| Device | Last tried | Reason |
| --- | --- | --- |
| `approachs62` | 2026-11-05 | build failed: ERROR: Device 'approachs62' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Manager, |
| `d2air` | 2026-11-05 | Starts without an error, but the widget price renders as garbage (corrupted digits, missing text) in the simulator. Needs a rendering fix for this display/font setup. |
| `d2charlie` | 2026-11-05 | build failed: ERROR: Device 'd2charlie' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Manager, c |
| `d2delta` | 2026-11-05 | build failed: ERROR: Device 'd2delta' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Manager, cha |
| `d2deltapx` | 2026-11-05 | build failed: ERROR: Device 'd2deltapx' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Manager, c |
| `d2deltas` | 2026-11-05 | build failed: ERROR: Device 'd2deltas' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Manager, ch |
| `descentmk1` | 2026-11-05 | build failed: ERROR: Device 'descentmk1' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Manager, |
| `epix` | 2026-11-05 | build failed: ERROR: Device 'epix' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Manager, changi |
| `fenix5` | 2026-11-09 | crash in glance/start: Error: Out Of Memory Error Details: Failed invoking <symbol> |
| `venud` | 2026-11-05 | Same garbled price rendering as `d2air`. |
| `vivoactive3mlte` | 2026-11-05 | build failed: ERROR: Device 'vivoactive3mlte' does not support API Level '3.2.0'. Try updating the device with the Connect IQ SDK Mana |
