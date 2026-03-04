# Plan: Optimization of Event Editor Assistant

This plan addresses the user's feedback regarding connection management (specifically disconnecting specific lines) and the save button's feedback/reliability.

## 1. Save Button & Feedback Fix

**Problem**: User reports no "saved" output when clicking the manual save button, and feels changes aren't loaded in-game.
**Cause**:

1. `save_manager.gd` has print statements commented out.
2. The manual "Save Graph" button uses the same debounced (delayed) save as auto-save, which might feel unresponsive or be interrupted if the editor is closed immediately.

**Solution**:

* **Modify** **`save_manager.gd`**:

  * Uncomment and improve print statements to give clear feedback (e.g., `[EventEditor] Saved graph and 3 resources.`).

  * Add a `force_save()` method that flushes pending saves immediately and stops the timer.

* **Modify** **`graph_view.gd`**:

  * Update `save_graph()` (called by the toolbar button) to use `force_save()` instead of `request_save_graph()`, ensuring immediate disk write and feedback.

## 2. Improved Connection Management (Incoming Links)

**Problem**: Disconnecting multiple lines entering a single node is unintuitive (FIFO order) using standard GraphEdit dragging. User wants to delete specific connections.
**Solution**: Add an "Incoming Connections" section to the **Target Node** that lists all sources and allows individual disconnection.

* **Modify** **`event_node.tscn`**:

  * Add a `VBoxContainer` named `IncomingLinksContainer` (e.g., inside a "Relations" section or at the bottom).

  * Add a `Label` header "Incoming Links".

* **Modify** **`event_node.gd`**:

  * Define signal `request_disconnect_incoming(source_node_name, source_port)`.

  * Add function `update_incoming_links(links: Array)`. `links` will be a list of dictionaries `{from_node: String, from_port: int}`.

  * Implement UI rebuilding in `update_incoming_links`:

    * Clear existing list.

    * For each link, add a row: "From \[NodeName] (Port \[X])" + \[Unlink] button.

    * \[Unlink] button emits `request_disconnect_incoming`.

* **Modify** **`graph_view.gd`**:

  * Implement `_refresh_node_incoming_links(node_name)`:

    * Get `graph_edit.get_connection_list()`.

    * Filter connections where `to == node_name`.

    * Call `node.update_incoming_links(filtered_list)`.

  * Update `_add_node`:

    * Connect `node.request_disconnect_incoming` to a new handler `_on_node_request_disconnect_incoming`.

  * Implement `_on_node_request_disconnect_incoming(from, from_port, to, to_port)`:

    * Call `_on_disconnection_request` (reuse existing logic).

  * Hook into events to refresh links:

    * `_restore_connections` (end of load): Update all nodes.

    * `_on_connection_request`: Update `to_node`.

    * `_on_disconnection_request`: Update `to_node`.

## 3. Verification

* **Save**: Click "Save Graph", verify Output console shows confirmation. Check file timestamp.

* **Connections**:

  * Connect Node A -> Node C.

  * Connect Node B -> Node C.

  * Select Node C. See "Incoming Links" section showing A and B.

  * Click "Unlink" for A. Verify line disappears and A is removed from list.

