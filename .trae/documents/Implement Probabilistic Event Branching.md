I will implement multi-target probabilistic branching as requested.

**1. Create** **`EventOutcome.gd`**

* Define a new Resource `scripts/EventOutcome.gd`.

* Properties:

  * `target_event: EventData`

  * `probability: float` (Range 0.0-1.0, default 1.0)

**2. Modify** **`EventBranchData.gd`**

* Deprecate/Remove `target_event` (single).

* Add `outcomes: Array[EventOutcome]`.

* Add helper function `get_random_target() -> EventData` to handle the weighted selection logic internally.

**3. Modify** **`EventPanel.gd`**

* Update `_check_branches()`:

  * When a branch condition is met, call `branch.get_random_target()` to resolve the next event.

  * Support backward compatibility: If `outcomes` is empty but old `target_event` exists (if we keep it for legacy data), use it. (I will check if I need to migrate data or keep both fields for a moment, likely replacing is cleaner if I can update the logic).

**Logic for `get_random_target`**:

* Calculate total weight of all outcomes.

* Pick random value `r` between 0 and total weight.

* Iterate outcomes, subtract weight from `r`.

* Return outcome where `r <= 0`.

This approach allows a single branch condition (e.g. "Has Key") to lead to multiple possible results (e.g. "Success" 80%, "Key Breaks" 20%).

