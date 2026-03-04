# Plan: Improve Save/Load, EventPanel Logic, and Fixes

This plan addresses the user's requests regarding EventPanel state persistence, card expiration in slots, empty output slots, and the "Collect All" button.

## 1. EventPanel State Persistence (Save/Load)

**Problem:** `Verb` always opens the `EventPanel` on load, even if it was closed/minimized/backgrounded.
**Solution:**

* Modify `EventPanel.gd`: Update `serialize()` to include the `visible` property.

* Modify `Verb.gd`: Update `deserialize()` to read the `visible` property from the saved `panel_state` and apply it to the restored panel.

## 2. Timer Card in Slot Expiration

**Problem:** If a card with a timer expires while in a slot, it causes errors because the slot isn't notified of the card's destruction.
**Solution:**

* Modify `Card.gd`:

  * Add a signal `timer_expired_in_slot(card)`.

  * In `_process()`, when lifetime <= 0:

    * Check if `has_meta("in_event_slot")`.

    * If true, emit `timer_expired_in_slot` and return (defer destruction).

    * If false, proceed with normal destruction/transformation.

* Modify `EventPanel.gd`:

  * Create a handler `_on_card_expired_in_slot(card)`.

  * In this handler:

    * Find the slot holding the card.

    * Release the card (removing the meta).

    * Trigger `_check_requirements` or `_update_attributes_display` to refresh the panel state (revert to Configuring if needed).

  * Connect this signal whenever a card is placed in a slot (in `_confirm_drop`, `_attempt_magnet_inhale`, `deserialize`).

  * Disconnect on removal.

## 3. Empty Output Slot

**Problem:** An empty "Output" slot is displayed even if the event yields no rewards.
**Solution:**

* Modify `EventPanel.gd` in `_enter_collection_mode`:

  * Check if `internal_storage` is empty.

  * Only create and add the "Output" slot if `internal_storage` has items.

  * If no items, skip slot creation.

## 4. "Collect All" Button Position & Text

**Problem:** Button position is unreliable (likely due to layout timing) and user wants to know where the text is.
**Solution:**

* Modify `EventPanel.gd`:

  * In `_enter_collection_mode`, use `call_deferred` or `await get_tree().process_frame` before calculating and setting the `start_button` ("Collect All") position.

  * Handle the case where no "Output" slot exists (center the button or place it at a default location).

  * Add a comment indicating where "Collect All" text is set for future user modification.

## Files to Edit

1. `scripts/EventPanel.gd`
2. `scripts/Verb.gd`
3. `scripts/Card.gd`

