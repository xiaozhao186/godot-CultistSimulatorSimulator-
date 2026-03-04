# Bug Fixes and Improvements Plan

This plan addresses the 4 issues identified by the user and implements the requested Debug Console enhancement.

## 1. Camera Control (WASD)
- **Problem**: Currently uses `ui_left/right/up/down` which map to arrow keys by default.
- **Solution**: Modify `CameraController.gd` to check for `KEY_W`, `KEY_A`, `KEY_S`, `KEY_D` explicitly using `Input.is_key_pressed` or `Input.get_vector` with ad-hoc actions if not configured in Project Settings.
- **Implementation**:
  ```gdscript
  # In CameraController.gd
  var input_dir = Vector2.ZERO
  if Input.is_key_pressed(KEY_W): input_dir.y -= 1
  if Input.is_key_pressed(KEY_S): input_dir.y += 1
  if Input.is_key_pressed(KEY_A): input_dir.x -= 1
  if Input.is_key_pressed(KEY_D): input_dir.x += 1
  input_dir = input_dir.normalized()
  ```

## 2. Click vs Drag Logic
- **Problem**: `clicked` signal fires immediately on mouse down.
- **Solution**: Defer `clicked` signal to mouse up (`!event.pressed`), and only if:
  1.  Time elapsed since press is short (< 0.2s).
  2.  Mouse hasn't moved significantly (drag distance < threshold).
- **Implementation**:
  - Store `press_pos` and `press_time` in `Token.gd`.
  - In `_input_event` (release), check distance and time.
  - Emit `clicked` only if valid.

## 3. UI Layering and Details Panel
- **Problem**: `DetailsPanel` is in the world layer (moving with camera) and lacks a close button.
- **Solution**:
  1.  Move `DetailsPanel` inside the `CanvasLayer` in `Tabletop.tscn`.
  2.  Add a "Close" button to `DetailsPanel.tscn` that hides the panel.
  3.  Ensure `DetailsPanel` does not conflict with `EventPanel`.
- **Implementation**:
  - Edit `Tabletop.tscn` to reparent `DetailsPanel` under `CanvasLayer`.
  - Edit `DetailsPanel.tscn` to add a Button.
  - Connect button to `hide()`.

## 4. Debug Console Enhancement
- **Problem**: Hardcoded spawn buttons.
- **Solution**: Scan `res://data/` for resources and generate buttons.
- **Implementation**:
  - Create a utility function in `DebugConsole.gd` to `DirAccess.open("res://data/")`.
  - Recursively find `.tres` or `.res` files.
  - Load them, check `is CardData` or `is EventData`.
  - Add buttons to the container dynamically.
  - **Prerequisite**: Ensure a `res://data` folder exists with some sample resources to test this.

## 5. UI Conflict Resolution
- **Problem**: Clicking a card "replaces" the Event Panel.
- **Cause**: Likely due to `DetailsPanel` being added to the scene root or `CanvasLayer` in a way that overlaps or the user perception of "replacing" (maybe Z-index).
- **Solution**: By moving `DetailsPanel` to `CanvasLayer` (same as `EventPanel`), they will stack. We will ensure `DetailsPanel` is on the Right and `EventPanel` is Center. They should coexist. We will verify `DetailsPanel` doesn't explicitly close other windows.

## Implementation Order
1.  **Camera**: Fix WASD.
2.  **Token**: Fix Click/Drag distinction.
3.  **UI Structure**: Move `DetailsPanel` to `CanvasLayer` in `Tabletop.tscn`.
4.  **Details Panel**: Add Close Button.
5.  **Debug Console**: Implement dynamic resource scanning.
