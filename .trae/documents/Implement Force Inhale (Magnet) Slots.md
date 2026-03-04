* [ ] I will implement the "Force Inhale Card" functionality (Magnet Slot).

- [ ] **1. Update** **`EventSlotData.gd`**

* [ ] Add `specific_card_ids: Array[String]` to define which cards can be targeted.

- [ ] Add `force_inhale: bool` (default false) to enable the magnet behavior.

* [ ] Add `lock_after_inhale: bool` (default true) to prevent taking the card out ("无法取出").

- [ ] **2. Modify** **`EventPanel.gd`**

* [ ] In `_process()` (or a timer-based check if performance is a concern, but `_process` is fine for now):

- [ ] Iterate through all `active_slots`.

* [ ] If a slot has `force_inhale` enabled AND is empty:

- [ ] Scan the `Tabletop` (via `GameManager` or `get_tree().root`) for valid cards.

* [ ] A card is valid if:

- [ ] It is not held by another slot or mouse.

* [ ] Its ID matches `specific_card_ids` (or meets other slot requirements if `specific_card_ids` is empty, but user asked for precise retrieval).

- [ ] If found:

* [ ] **Animate/Move** the card to the slot.

- [ ] **Lock** the card (set `input_pickable = false` if `lock_after_inhale` is true).

* [ ] **Trigger** slot acceptance logic (`try_accept_card`, update `held_card`, check requirements).

- [ ] **3. Modify** **`EventSlot.gd`**

* [ ] Update `try_accept_card` or `held_card` setter to handle locking logic if needed, or handle it in `EventPanel`.

- [ ] **4. Validation**

* [ ] Ensure the "Force Inhale" only works during the correct state (e.g., WORKING state, as user described "event starts and timer runs").

- [ ] Ensure "Lock" prevents user from dragging the card out (`input_pickable = false` on the card is the easiest way, but need to ensure it's restored if returned).

<br />

