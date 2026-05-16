# Persistence

Vehicle Manager saves the complete state of a vehicle to per-player JSON files on the server. Players can save, load, and delete vehicle presets through the menu.

## How It Works

### What Gets Saved

A vehicle save captures:

| Category             | Data                                                                                                            |
| -------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Identity**         | Model hash, save ID, display name                                                                               |
| **Tuning Selection** | All fields from `TUNING_SELECTION_SCHEMA` (engine pack, brake bias, suspension raise, etc.)                     |
| **Colours**          | Primary/secondary colour IDs, paint types, custom RGB colours, pearl coat, wheel colour, interior/extra colours |
| **Wheels**           | Wheel type, wheel model index, tyre smoke colour                                                                |
| **Window Tint**      | Tint level                                                                                                      |
| **Neon**             | Neon enable state (left/right/front/back) and RGB colour                                                        |
| **Xenon**            | Headlight colour ID                                                                                             |
| **Plate**            | Plate text and index                                                                                            |
| **Mods**             | All visual and stat mods (index, toggle, variation)                                                             |
| **Extras**           | Extra on/off state for all valid extra IDs                                                                      |
| **Doors**            | Open/broken state for all doors                                                                                 |
| **Tyres**            | Burst state for all tyre positions                                                                              |
| **Livery**           | Livery index                                                                                                    |
| **Proofs**           | Bulletproof, fireproof, explosion-proof, etc.                                                                   |

### Save File Format

Saves are stored in `savedvehicles/` as JSON files named:

```
<identifier>_<modelHash><suffix>.json
```

Where `<identifier>` is the player's license hash and `<modelHash>` is the vehicle model hash in uppercase hex.

An **index file** per player (`index_<identifier>.json`) maps save IDs to filenames for fast lookup.

### Server Events

The client communicates with the server via events:

| Event                              | Direction       | Description                                                   |
| ---------------------------------- | --------------- | ------------------------------------------------------------- |
| `vehiclemanager:requestIndex`      | Client → Server | Requests the player's save index.                             |
| `vehiclemanager:loadSave`          | Client → Server | Requests a specific save to be loaded (returns vehicle data). |
| `vehiclemanager:saveVehicle`       | Client → Server | Sends vehicle data to be saved.                               |
| `vehiclemanager:vehicleDeleted`    | Client → Server | Requests deletion of a specific save.                         |
| `vehiclemanager:receiveIndex`      | Server → Client | Sends the player's save index.                                |
| `vehiclemanager:vehicleSaved`      | Server → Client | Confirms a save was successful.                               |
| `vehiclemanager:vehicleLoaded`     | Server → Client | Sends loaded vehicle data to the client.                      |
| `vehiclemanager:vehicleDeletedAck` | Server → Client | Confirms a save was deleted.                                  |

### Autosave

When the player modifies their vehicle (changing mods, colours, tuning, etc.), a 6-second debounce timer starts. When it expires, the vehicle state is automatically saved to the current save slot, if one exists.

### State Bag Integration

Vehicle Manager reads/writes three entity state bags for integration with performancetuning:

| State Bag Key                     | Purpose                                      |
| --------------------------------- | -------------------------------------------- |
| `performancetuning:tuneState`     | Current tuning selection parameters.         |
| `performancetuning:handlingState` | Original + modified handling values.         |
| `vehiclemanager:saveId`           | Current save ID associated with the vehicle. |

### Apply Process

When loading a save, the client:

1. Sets the vehicle model (if different from current).
2. Waits for network ownership of the vehicle entity.
3. Applies all mods, colours, extras, neon, window tint, plate, livery, tyres, and proofs.
4. Sets the tuning selection via state bags.
5. Restores door states and tyre burst states.

## Server Commands

| Command                     | Description                                                          |
| --------------------------- | -------------------------------------------------------------------- |
| `/vm_save_inspect <saveId>` | Prints a summary of the specified save to the calling player's chat. |
| `/vm_save_delete <saveId>`  | Deletes the specified save file for the calling player.              |

## Configuration

See [configuration.md](configuration.md) for `TUNING_SELECTION_SCHEMA` defaults, door/tyre mappings, and UI settings.
