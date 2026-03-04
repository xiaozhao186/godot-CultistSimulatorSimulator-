I will implement the requested visual and interaction overhaul for the Card system.

**1. Card Visual Restructuring (Scene & Assets)**

*   **Update `Card.tscn`**:
    *   Change root `Area2D` size/collision shape to match new standard (e.g., 140x190px).
    *   Add a `TextureRect` (or Sprite2D) for the **Background** using `res://pic/card.jpeg`.
    *   Add a `TextureRect` for the **Card Image** using the dynamic `data.icon` (defaulting to `res://pic/01.jpg` style placeholder if needed, but `data.icon` is the source). Layout: Top 60-70% of the card.
    *   Update `Label` (Name): Position at the bottom area of the background.
    *   Ensure `TextureProgressBar` (Lifetime) is positioned correctly (e.g., centered or top-right corner).
    *   Update `CollisionShape2D`: Set size to `130x180` (slightly smaller than visual).

*   **Update `EventSlot.tscn`**:
    *   Update `custom_minimum_size` to match new card size (e.g., `150x200` to include padding).

**2. Interaction & Collision Logic (Script)**

*   **Modify `Token.gd` (Base class for dragging)**:
    *   Implement **static z-index management**:
        *   When `drag_started`: Set `z_index = 100` (Top).
        *   When `dropped`: Restore `z_index` based on stack order (or just 0 if no stack logic yet, but user asked for stack management).
    *   **Collision Layer/Mask**:
        *   Ensure Cards are on a specific layer (e.g., Layer 1).
        *   Implement a "Top Card Only" check in `_input_event`.
    *   **"Top Card" Logic**:
        *   Since Godot's `_input_event` fires for all overlapping shapes, we need a way to filter.
        *   **Solution**: Use `GameManager` to track "hovered tokens".
        *   In `Token.gd`: `mouse_entered` -> `GameManager.add_hovered(self)`, `mouse_exited` -> `GameManager.remove_hovered(self)`.
        *   In `_input`: Only process click if `self == GameManager.get_top_hovered_token()`.

*   **Modify `GameManager.gd`**:
    *   Add `hovered_tokens: Array[Token]`.
    *   Add `add_hovered(token)`: Append.
    *   Add `remove_hovered(token)`: Erase.
    *   Add `get_top_hovered_token()`: Return the token with the highest `z_index` (or tree order if z-index is same).

**3. Implementation Steps**

1.  **Assets**: Confirm paths `res://pic/card.jpeg` and `res://pic/01.jpg` exist (User provided absolute paths, I will assume they are/will be imported to `res://pic/`).
2.  **Scene**: Edit `Card.tscn` nodes and layout.
3.  **Script**: Update `Token.gd` and `GameManager.gd` for the "Top Only" interaction logic.
4.  **EventSlot**: Resize.

