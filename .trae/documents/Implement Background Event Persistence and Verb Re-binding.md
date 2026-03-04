I will implement a "minimize" behavior for the Event Panel when it is running, allowing it to continue in the background and be reopened via the Verb token.

**1. Modify** **`EventPanel.gd`**

* Refactor card return logic into a helper function `_return_all_cards()`.

* Update `_on_close_button_pressed()`:

  * **If CONFIGURING**: Execute "Cancel" behavior (return cards and destroy panel).

  * **If WORKING or COLLECTING**: Execute "Minimize" behavior (hide panel, keep state running).

**2. Modify** **`Verb.gd`**

* Add a variable `active_panel` to track the currently associated event panel.

* Update `_on_clicked()`:

  * Check if `active_panel` exists and is valid.

  * **If valid**: Show the existing panel (restore state).

  * **If invalid**: Create a new panel and assign it to `active_panel`.

This ensures that:

* Closing a running event doesn't stop it.

* The event chain continues in the background (auto-start works).

* Clicking the Verb again opens the *current* event interface, not the original one.

