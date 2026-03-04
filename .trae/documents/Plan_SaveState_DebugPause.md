# Plan: Save System State Restoration & Debug Console Improvements

## 1. Comprehensive State Saving (Fixing Issue 1)

**Problem**:

1. Dynamically spawned verbs (via Debug Console) are lost because they don't have a corresponding `.tres` file in `res://data/Verbs/`, causing `GameManager.spawn_verb` to fail during load.
2. `EventPanel` state (timer progress, inserted cards) is not serialized, causing resets on load.

**Solution**:
Implement a `serialize()` / `deserialize()` pattern for `Verb` and `EventPanel`.

### A. Modify `scripts/Verb.gd`

Add `serialize()` method:

* Returns a Dictionary containing:

  * `id`: Verb ID.

  * `pos_x`, `pos_y`: Position.

  * `is_debug`: Boolean flag (true if ID starts with "debug\_").

  * `debug_event_id`: If debug, store the ID of the event it was bound to.

  * `panel_state`: Result of `active_panel.serialize()` if active\_panel exists, else `null`.

### B. Modify `scripts/EventPanel.gd`

Add `serialize()` method:

* Returns a Dictionary containing:

  * `state`: Current state enum (CONFIGURING, WORKING, COLLECTING).

  * `time_left`: `timer.time_left`.

  * `duration`: `event_data.duration`.

  * `current_event_id`: `event_data.id`.

  * `slots_content`: Array of dictionaries for each slot `{ "slot_index": i, "card_id": id, "card_data": ... }`.

  * `internal_storage`: List of card IDs currently in storage (rewards or working cards).

Add `deserialize(data)` method:

* Restore state.

* If `WORKING`, resume timer with `time_left`.

* Restore cards into slots or internal storage. *Note: This is complex because we need to re-spawn the specific card instances or find them if they were saved separately. Since cards inside slots are usually "consumed" or "hidden" in storage, they might not be in the main* *`cards`* *list of the save file. We need to ensure we don't duplicate them or lose them.*

* **Refinement**: `SaveManager` currently saves ALL cards on Tabletop. If a card is inside an EventPanel's `internal_storage`, is it still a child of Tabletop?

  * In `EventPanel.gd`, `_on_card_dropped`: `card_node` is usually reparented or just hidden?

  * Let's assume for now we need to save the specific data of cards inside the panel within the panel's data, OR ensure they are properly referenced.

  * *Simpler approach*: If cards in panel are just hidden children of Tabletop, `SaveManager` will save them. But we need to know they belong to this panel.

  * *Better approach*: The `EventPanel` should re-create these cards from data if they are "inside" it.

### C. Modify `scripts/SaveManager.gd`

* Update `_serialize_verbs`: Call `child.serialize()` instead of manually building the dict.

* Update `_serialize_cards`: Exclude cards that are currently "inside" an EventPanel (if they are still in the tree) to avoid duplication, OR let EventPanel claim them.

  * *Correction*: If cards are in `internal_storage`, they might still be in the tree (just hidden).

  * We should probably verify if a card is "owned" by a panel.

### D. Modify `scripts/GameManager.gd`

* Update `restore_game_state`:

  * Iterate through `verbs` data.

  * If `is_debug` is true:

    * Manually instantiate `Verb.tscn`.

    * Create a temporary `VerbData` with `id` and `default_event` (loaded from `debug_event_id`).

    * Setup Verb.

  * Else:

    * Call `spawn_verb(id)`.

  * **Crucial**: After spawning, call `verb.deserialize(verb_data.panel_state)`.

  * `verb.deserialize` will trigger `active_panel.deserialize` which will restore the timer and cards.

## 2. Debug Console & Pause Improvements (Fixing Issue 2)

**Problem**: Debug console unresponsive during pause.

**Solution**:

1. **Debug Console Process Mode**:

   * Modify `scripts/DebugConsole.gd`: Set `process_mode = Node.PROCESS_MODE_ALWAYS` in `_ready`.
2. **Settings Toggle**:

   * Modify `scenes/SettingsPanel.tscn`: Add a `CheckButton` for "Enable Debug Console".

   * Modify `scripts/SettingsPanel.gd`: Handle toggle logic.

   * Modify `scripts/GameManager.gd` or `AppState.gd`: Store `debug_console_enabled` state.

   * Modify `scripts/DebugConsole.gd`: Check this state in `_process` or `_input` (or visibility).

## Implementation Steps

1. **EventPanel Serialization**: Implement `serialize` and `deserialize`.
2. **Verb Serialization**: Implement `serialize` and `deserialize` (delegating to panel).
3. **SaveManager Update**: Use the new serialization methods.
4. **GameManager Update**: Handle restoration of debug verbs and panel state.
5. **Debug Console Update**: Set process mode and add visibility toggle support.
6. **Settings Panel Update**: Add the toggle UI.

## Code References

* [SaveManager.gd](file:///d:/Program%20Files%20\(x86\)/Godot_v4.5.1/box/ppd-1/scripts/SaveManager.gd)

* [GameManager.gd](file:///d:/Program%20Files%20\(x86\)/Godot_v4.5.1/box/ppd-1/scripts/GameManager.gd)

* [EventPanel.gd](file:///d:/Program%20Files%20\(x86\)/Godot_v4.5.1/box/ppd-1/scripts/EventPanel.gd)

* [Verb.gd](file:///d:/Program%20Files%20\(x86\)/Godot_v4.5.1/box/ppd-1/scripts/Verb.gd)

* [DebugConsole.gd](file:///d:/Program%20Files%20\(x86\)/Godot_v4.5.1/box/ppd-1/scripts/DebugConsole.gd)

* [SettingsPanel.gd](file:///d:/Program%20Files%20\(x86\)/Godot_v4.5.1/box/ppd-1/scripts/SettingsPanel.gd)

