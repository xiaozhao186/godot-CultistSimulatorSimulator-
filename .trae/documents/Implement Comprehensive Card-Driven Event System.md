# Core Game Logic Overhaul Plan

This plan implements the "Card-Driven Event Flow" system as specified, including precise card management, branching events, and configurable rewards.

## 1. Data Structure Updates
- **`EventSlotData`**: Add `action_type` enum/string (Return, Consume, Reward) to define what happens to the card in this slot after the event.
- **`EventData`**:
    - Add `branches`: Array of `EventBranchData` (new resource) to replace simple `linked_events`.
    - Add `rewards`: Array of `EventRewardData` (new resource) to replace `end_effects`.
- **New Resource: `EventBranchData`**:
    - `target_event`: `EventData`
    - `conditions`: Array of `BranchCondition` (Helper class/Dictionary).
        - Types: Attribute Check (Reason > 5), Card Type Check, Specific ID Check.
- **New Resource: `EventRewardData`**:
    - `type`: Fixed (ID list) or Random (Pool + Count).
    - `card_ids`: Array[String] (for Fixed).
    - `pool_id`: String (for Random, assumes a global pool manager or directory scan).
    - `count`: int.

## 2. Card Management System (The "Black Box")
- **Refactor `EventPanel.gd`**:
    - **Recording Phase**: When "Start" is clicked:
        - Create a `recorded_cards` Dictionary: `{ slot_index: { "card_node": node, "original_data": data, "slot_action": slot_data.action_type } }`.
    - **Temporary Removal**:
        - Iterate `recorded_cards`.
        - If action is `Consume` (immediate) -> `queue_free()` the card node, but keep data.
        - If action is `Return` or `Consume` (delayed) -> `card.visible = false`, `card.input_pickable = false`.
    - **Completion/Settlement Phase** (`_on_timer_timeout`):
        - **Settlement**:
            - If `Return`: Restore `visible = true`, `input_pickable = true`, move to return position (or keep in slot).
            - If `Consume`: `queue_free()` if not already done.
            - If `Reward`: `queue_free()`, and add a new card instance to the reward pile (conceptually).
        - **Branching**:
            - Calculate total attributes from `recorded_cards`.
            - Iterate `event_data.branches`. First match -> Load new Event. Default -> End or Default Event.
        - **Rewards**:
            - Process `event_data.rewards`. Spawn new cards based on ID or Pool.
            - Place spawned cards on the table (near the event panel).

## 3. Implementation Steps
1.  **Define New Resources**: Create `EventBranchData.gd` and `EventRewardData.gd`. Update `EventData.gd` and `EventSlotData.gd`.
2.  **Update Event Logic (`EventPanel.gd`)**:
    - Implement `_start_event()`: Record cards, hide/lock them.
    - Implement `_settle_cards()`: Handle Return/Consume logic.
    - Implement `_check_branches()`: Logic to evaluate conditions against recorded cards.
    - Implement `_generate_rewards()`: Logic to spawn new cards.
    - Update `_on_timer_timeout()` to chain these methods.
3.  **Global Card Database**: Since we need to spawn cards by ID (for rewards), we need a way to look up `CardData` by ID.
    - Update `GameManager` (or `CardDatabase` autoload) to scan `res://data/cards` on startup and map IDs to file paths.
4.  **Verification**: Update `DebugConsole` to support the new system (ensure it can still spawn things to test).

## Key Technical Details
- **Condition Checking**: `total_attributes` will be a Dictionary summed from all input cards. `BranchCondition` will check `total_attributes.get(attr, 0) >= value`.
- **Card Database**: A simple static Dictionary in a new Autoload or `GameManager` is sufficient.

## Branch & Reward Logic
- **Branch**: `if condition_met: load(target_event)`
- **Reward**: `instantiate_card(id)` -> `add_child(tabletop)`

This plan strictly follows the user's requirements: "Record -> Temporary Remove -> Settle -> Branch -> Reward".
