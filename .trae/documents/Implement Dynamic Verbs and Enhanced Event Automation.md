I will implement dynamic Verbs and enhanced event automation.

**1. Create** **`VerbData.gd`**

* Define a new `Resource` script `scripts/VerbData.gd`.

* Properties: `id`, `title`, `description`, `icon`, `default_event` (EventData).

**2. Modify** **`Verb.gd`**

* Add `data: VerbData` property.

* Update `_ready` to initialize from `data` if present (set title, icon, bind default event).

* Add `id` property (derived from data).

**3. Update** **`EventRewardData.gd`**

* Add `verb_ids_to_spawn` (Array\[String]) and `verb_ids_to_delete` (Array\[String]).

* Add `delete_source_verb` (bool) to handle self-deletion.

**4. Update** **`EventData.gd`**

* Add `auto_collect` (bool) property.

**5. Modify** **`EventPanel.gd`**

* Update `_process_finished_cards`:

  * Handle `delete_source_verb`: Signal/Call to GameManager to delete the source verb.

  * Handle `verb_ids_to_delete`: Signal/Call to GameManager.

* Update `_add_reward_to_storage`:

  * Handle spawning new Verbs from `verb_ids_to_spawn`.

  * If spawned verb has `default_event` and `auto_start`, trigger its start logic.

* Update `_check_collection_complete` or `_enter_collection_mode`:

  * If `event_data.auto_collect` is true, automatically trigger `_on_collect_all_pressed`.

**6. Modify** **`GameManager.gd`** **(or** **`Tabletop`** **controller)**

* Add `register_verb(verb)`, `unregister_verb(verb)`.

* Implement `spawn_verb(verb_id)` and `delete_verb(verb_id)`.

* Maintain a dictionary of active verbs for lookup.

**7. Integration**

* Ensure `Verb` calls `GameManager.register_verb` on ready.

* Ensure `EventPanel` knows which Verb created it (pass `source_verb` in `setup`).

This structure supports the user's scenario:

1. Event chain ends -> Reward spawns Verb X.
2. Verb X spawns -> Auto-starts its default event (if configured).
3. Event runs -> Auto-collects (if configured).
4. Reward triggers `delete_source_verb` -> Verb X disappears.

