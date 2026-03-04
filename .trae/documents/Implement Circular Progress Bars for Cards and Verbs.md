I will implement circular progress bars for both Cards (showing lifetime) and Verbs (showing active event duration).

**1. Modify** **`Card.tscn`** **&** **`Card.gd`**

* **Scene:** Add a `TextureProgressBar` node named `LifetimeBar`.

  * Settings: `fill_mode = 4` (Clockwise), `value = 100`, `modulate.a = 0.8`.

  * Position: Centered on the card.

  * Texture: Use a circular texture (I'll need to generate or reuse an existing one like `icon.svg` temporarily or procedurally).

* **Script:**

  * In `_process()`: Update `LifetimeBar.value` based on `current_lifetime / data.lifetime`.

  * Only show the bar if `data.lifetime > 0`.

**2. Modify** **`Verb.tscn`** **&** **`Verb.gd`**

* **Scene:** Add a `TextureProgressBar` node named `ProgressBar`.

  * Settings: `fill_mode = 4` (Clockwise), `value = 0`, `modulate.a = 0.8`.

  * Position: Centered on the verb.

* **Script:**

  * In `_process()`:

    * Check if `active_panel` exists and is valid.

    * If `active_panel.current_state == WORKING`:

      * Get `timer.time_left` and `event_data.duration` from `active_panel`.

      * Update `ProgressBar.value` (inverse logic: empty to full or full to empty based on preference, user said "empty to full").

      * Show the bar.

    * Else: Hide the bar.

**3. Assets**

* Since I cannot create image files easily, I will use Godot's built-in `Curve2D` or just reuse `icon.svg` with a circular mask or a simple `StyleBoxFlat` if possible, but `TextureProgressBar` needs a texture. I will try to use `icon.svg` as the progress texture for now, or see if I can use a `StyleBox` based approach (though `TextureProgressBar` is best). Actually, for a simple circle, using a `TextureProgressBar` with a circular resource is standard. I'll check if I can use a generated `GradientTexture2D` as a placeholder circle if needed, or just the icon.

**Wait, user requirements:**

* "Circular progress bar, countdown in the middle, alpha 80%"

* "Card: lifetime countdown"

* "Verb: event timer countdown"

**Plan Update:**

* I will add a `Label` for the countdown text in the center of both.

* I will try to use `GradientTexture2D` to create a runtime circular texture for the progress bar to avoid needing external assets.

**Steps:**

1. **Card:** Add `TextureProgressBar` + `Label`. Update script to sync with `lifetime`.
2. **Verb:** Add `TextureProgressBar` + `Label`. Update script to sync with `active_panel.timer`.

