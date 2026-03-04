# UI Layering and Debug Features Plan

This plan addresses the user's feedback regarding the Event Panel's layer, interaction issues, and further Debug/UI enhancements.

## 1. Event Panel Layering & Interaction (Issue #1)
- **Problem**: The user feels the Event Panel is on the "Camera Layer" (likely meaning it's static on screen) which makes it hard for cards (in World Space) to interact with it properly, or visually confusing. The user wants the Event Panel to be draggable and "floating" between the card layer and camera layer, effectively acting like a window in the world or a specific UI layer that interacts with world objects.
- **Solution**:
    1.  **Move EventPanel to a separate CanvasLayer** or adjust its Z-index/Layer behavior. However, since cards are `Node2D` in the world and the Panel is `Control` in `CanvasLayer`, coordinate conversion is tricky.
    2.  **New Approach**: Keep EventPanel in `CanvasLayer` (so it doesn't move with camera pan), BUT:
        - Make it **Draggable**.
        - When dragging a card, we need to ensure it renders *above* the EventPanel if we want it to look like it's being dropped "in".
        - *Crucial Fix*: The user mentioned "temporarily adjust card layer to Event Panel layer". Since Card is `Node2D` and Panel is `CanvasItem` in a Layer, we can't easily merge them.
        - **Compromise/Implementation**: We will create a dedicated `WindowLayer` (CanvasLayer) for Event Panels. When a card is dragged, we will set its `z_index` very high (already done in `Token.gd`, `z_index = 100`). We need to ensure the `WindowLayer` is *below* the `z_index` max but *above* the base world.
        - Actually, `CanvasLayer` always renders on top of the viewport. To have a card (Node2D) render on top of a CanvasLayer (UI), we usually need a second `CanvasLayer` for the "Dragged Card" or use `RemoteTransform2D` to move the card to UI space.
        - **Selected Strategy**: We will implement a "Drag Layer" logic. When a card is picked up, reparent it (or a visual proxy) to a high-priority `CanvasLayer` so it floats above everything, including Event Panels.
    3.  **Draggable EventPanel**: Implement `_gui_input` in `EventPanel.gd` to handle dragging the window itself.

## 2. Debug Console Card Spawning (Issue #2)
- **Goal**: Add a dropdown for Cards similar to the one for Events.
- **Implementation**:
    - Update `DebugConsole.gd` to scan for `CardData` resources specifically.
    - Add a `CardOption` dropdown.
    - Update `SpawnCardButton` to spawn the selected card from the dropdown.

## 3. Details Panel Enhancements (Issue #3)
- **Goal**: Show card attributes in the Details Panel.
- **Implementation**:
    - Update `DetailsPanel.gd` to iterate through `token.data.attributes` (Dictionary) and append text to the `desc` label or a new `stats` label.

## Implementation Steps
1.  **EventPanel Draggable**: Add drag logic to `EventPanel.gd`.
2.  **Card Drag Visuals**: Modify `Token.gd` or `GameManager` to handle "Lift to UI".
    - *Simpler approach for now*: Just ensure `EventPanel` is not covering the whole screen and use `z_index` effectively. If `EventPanel` is in a `CanvasLayer` (Layer 1), it is *always* above `Node2D` (Layer 0).
    - To fix "Card not recognized/below": We must map the mouse position correctly. The `EventPanel` code already does coordinate conversion.
    - To fix "Visuals": We will try to make the Card render on a `CanvasLayer` when dragged.
    - *Plan*: When `dragging` starts in `Token.gd`, we can reparent the `Sprite` to a `CanvasLayer` temporarily, or just use a `CanvasLayer` for the whole `Tabletop` scene logic is too complex for a quick fix.
    - *Alternative*: Put `EventPanel` in the **World Space** (as a `Node2D` containing a `Control`) so it sorts with Z-Index. This matches "placed on table" feel better. **Decision**: Make `EventPanel` a child of `Tabletop` (World), not `CanvasLayer`. This solves the Z-sorting issue naturally. `Card` (Z=100 when dragged) will be above `EventPanel` (Z=10 or similar).
3.  **Debug Console**: Add Card Dropdown and logic.
4.  **Details Panel**: Add Attribute display loop.
