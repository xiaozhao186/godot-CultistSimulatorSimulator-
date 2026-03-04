# UI and Debug System Overhaul Plan

This plan addresses the layer hierarchy issues and redesigns the debug console as requested.

## 1. UI Layering Fix (Issue #1)
- **Goal**: Cards (`Card`) and Verbs (`Verb`) share the same layer (Tabletop world space). Event Panel (`EventPanel`) and Details Panel (`DetailsPanel`) are on the UI layer (`CanvasLayer`).
- **Correction**: The user pointed out `DetailsPanel` currently moves with the camera or is in a weird state. In the previous turn, we moved `DetailsPanel` to `CanvasLayer`, so it *should* already be fixed (fixed on screen, not moving with camera).
- **Refinement**: We will double-check `EventPanel` is also added to `CanvasLayer` when spawned. Currently `Verb.gd` finds "CanvasLayer" and adds it there, which is correct.
- **Action**: Verify `Tabletop.tscn` structure. Ensure `CanvasLayer` has a high layer index if needed, but default (1) is fine over Node2D.

## 2. Debug Console Redesign (Issue #2 & #4)
- **Goal**:
    - Dropdown (OptionButton) to list available `EventData` in `res://data/`.
    - Dropdown to list active Verbs on the board (by ID or Index).
    - "Bind" button to assign the selected Event to the selected Verb.
    - "Spawn Verb" button to create a generic, empty Verb token if needed.
- **Logic Change**: Verbs are now containers/triggers. They don't inherently own one specific event forever; they can be reassigned.
- **Implementation**:
    - **`DebugConsole.tscn`**: Replace old buttons with:
        - `OptionButton` (Event List)
        - `OptionButton` (Verb List) - *Self-correction: Since Verbs are dynamic, maybe just "Spawn specific Verb with Event" is simpler for now, OR a "Update Verb 1" approach.*
        - *User Request specific*: "Only 5 buttons, debug interface can dropdown to set Button 1 to Event X".
    - **Script Update**:
        - Scan `res://data` for `EventData`. Populate Dropdown A.
        - Track existing Verbs (or just assume fixed 5 for this requirement).
        - Function: `_on_bind_pressed()`: Get selected Event from Dropdown A, get target Verb from Dropdown B, apply `verb.event_data = selected_event`.

## 3. Event Panel Close Button (Issue #3)
- **Goal**: Add "X" button to `EventPanel`.
- **Implementation**:
    - Edit `EventPanel.tscn` to add a Button.
    - Connect to `queue_free()` or `close()` function.

## 4. Logic Clarification (Issue #4)
- **Concept**: Verbs are reusable tokens (Work, Dream, Explore). They open the Event Panel. The *Event Panel* runs the logic based on the `EventData` assigned to that Verb.
- **Action**: Ensure `Verb.gd` just holds a reference to `EventData` and passes it to the Panel. This is already mostly how it works, but we'll ensure the Debug Console supports swapping this data.

## Implementation Steps
1.  **Modify `DebugConsole.tscn`**: Add `OptionButton` for Events, `OptionButton` for Verbs (or a list of "Slot 1", "Slot 2"... if we go with fixed verbs), and a "Bind/Spawn" button.
2.  **Update `DebugConsole.gd`**:
    - Scan `res://data` to populate Event Dropdown.
    - Implement logic to spawn a Verb with the selected Event.
    - (Optional) If user wants *existing* verbs to change, we need a way to reference them. For now, "Spawn with Event" is the most direct interpretation of "generate", but "set 1st button to event" implies modifying existing. I will support both: Spawn new, and list existing.
3.  **Update `EventPanel.tscn`**: Add Close Button.
4.  **Verify Layering**: Check `Verb.gd` spawning logic to ensure Panels go to `CanvasLayer`.

*Self-Correction on "5 Buttons"*: The user mentioned "only 5 buttons". I will create a "Verb Manager" or just spawn 5 generic Verbs at start, and the Debug Console allows assigning events to them.
