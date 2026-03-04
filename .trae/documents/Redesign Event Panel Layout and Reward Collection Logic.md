I will redesign the Event Panel and Reward Panel to match the new visual requirements.

**1. Scene Redesign (`scenes/EventPanel.tscn`)**

* **Root Layout**:

  * Resize to a wider aspect ratio (e.g., `800x450`) to accommodate the Left-Text/Right-Slots layout.

  * Background: Use `res://pic/shijianmianban.jpg` (or placeholder if missing, user said "schematic diagram", so I'll check if file exists, if not use `ColorRect` or `Panel` with style). User provided `d:\Program Files (x86)\Godot_v4.5.1\box\ppd-1\.trae\shijianmianban.jpg` which is likely outside `res://`. I will use a standard `Panel` style for now or `cardlay.png` if appropriate, but layout is key.

  * **Left Section (Text)**:

    * `TitleLabel`: Top-Left corner.

    * `DescLabel`: Left side, taking up \~40% width.

    * `StartButton` (Confirm): Bottom-Left corner.

  * **Right Section (Slots)**:

    * `SlotsContainer`: Right side, taking up \~60% width.

    * **Layout Logic**:

      * 1-3 Slots: Center vertically in the right panel.

      * 4-6 Slots: Grid layout (2 rows of 3).

      * To implement this, I will use a `GridContainer` instead of `HBoxContainer`, and manage columns/positioning via script.

    * `TimerBar`: Positioned below the Slots area on the right.

    * `AttributesContainer` (New): Bottom-Right corner. Same "Right-to-Left" icon logic as DetailsPanel.

  * **Top Right**: `CloseButton`.

**2. Script Updates (`scripts/EventPanel.gd`)**

* **Dynamic Slot Layout**:

  * Update `setup()` to configure the `SlotsContainer` (GridContainer).

  * Logic:

    * If `slots.size() <= 3`: `columns = 3`, center alignment.

    * If `slots.size() > 3`: `columns = 3`, creates 2 rows.

* **Attribute Visualization**:

  * Add `AttributesContainer` node reference.

  * Add `_update_attributes_display()` function.

  * Call this function whenever a card is added/removed from a slot.

  * Logic: Iterate all `active_slots` -> get `held_card` -> collect all tags/attributes -> Populate icons using `IconMapping` (reuse logic from DetailsPanel refactor).

* **Reward Panel Logic**:

  * The user wants a "Stack" visual for rewards > 1.

  * In `_enter_collection_mode`:

    * Check `internal_storage.size()`.

    * Clear `active_slots`.

    * Create **ONE** output slot in the center.

    * If `internal_storage` has items:

      * Take the **first** item, put it in the slot.

      * If `internal_storage.size() > 1`:

        * Show a "Stack Underlay" (TextureRect with `cardlay.png` darkened) below the slot to indicate more cards.

  * Update `_on_card_drag_started` (or slot release logic):

    * When the card in the reward slot is taken (dragged out):

      * Remove it from `internal_storage`.

      * If `internal_storage` still has items:

        * Immediately pop the next item into the slot.

        * Update "Stack Underlay" visibility.

      * If empty, hide slot/underlay, show "Collection Complete" state (or close).

  * Update `StartButton` (Collect All) position: Move to below the single slot.

**3. Assets**

* Check `res://pic/cardlay.png` availability (User confirmed usage).

* `shijianmianban.jpg` is a reference, I will try to approximate the layout.

**4. Implementation Steps**

1. **Modify** **`EventPanel.tscn`**: Change layout containers, add AttributesContainer.
2. **Modify** **`EventPanel.gd`**:

   * Implement Grid layout for input slots.

   * Implement Attribute aggregation display.

   * Rewrite `_enter_collection_mode` and collection interaction logic for the "Stack" effect.

