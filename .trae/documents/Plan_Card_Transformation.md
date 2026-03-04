# Plan: Implement Card Transformation System

## 1. Problem

The current system requires defining separate event chains for every possible item level transition (e.g., Level 3 -> 2, Level 2 -> 1), leading to an exponential increase in required Event resources.

## 2. Solution

Introduce a "Card Transformation" system that allows defining logic for transforming input cards based on conditions within a single `EventRewardData` resource.

### Key Components:

1. **Slot Action "Transform"**: Add a new action type to `EventSlotData` called `transform` (or reuse/rename `reward` to imply pending state). The user requested using `reward` for this "pending" state.

   * *Decision*: We will update `EventSlotData` to include `transform` or clarify `reward` behavior. The user said: "在eventslotdata里将原先没有用的reward状态利用起来...". So we will use `reward` action type to mean "Pending Transformation".
2. **Pending Storage**: Cards in slots marked as `reward` will be moved to a `pending_cards` list instead of being consumed immediately.
3. **Transformation Logic in** **`EventRewardData`**: Add a new property `transformations` to `EventRewardData`.

   * Structure: Array of `CardTransformation` (new Resource or Dictionary).

   * Logic: "If pending card X meets condition Y, transform into card Z".

   * Ordering: Transform rules apply to pending cards in order of their slots.

## 3. Implementation Steps

### Step 1: Update `EventSlotData.gd`

* Update `action_type` enum documentation/comments to reflect that `reward` now means "Pending / Subject to Transformation".

* (No code change needed if enum strings remain same, just logic update).

### Step 2: Define `CardTransformation` Resource

Create a new script `scripts/CardTransformation.gd` (extending Resource) to hold transformation rules.

* `target_card_index`: int (Which pending card to apply to? 0 = first pending card, etc.)

* `required_id`: String (Optional: Apply only if card ID matches)

* `required_tags`: Array\[String] (Optional: Apply only if card has tags)

* `required_attributes`: Dictionary (Optional: Apply only if attributes match)

* `resulting_card_id`: String (The ID of the card to transform into)

* `action`: Enum (TRANSFORM, CONSUME, RETURN) - Default TRANSFORM.

### Step 3: Update `EventRewardData.gd`

* Add `export var transformations: Array[CardTransformation] = []`

### Step 4: Update `EventPanel.gd`

* **Modify** **`_process_finished_cards`**:

  * Create a local list `pending_cards`.

  * If slot action is `reward`, DO NOT `queue_free`. Instead, add to `pending_cards` and hide/lock it.

* **Modify Reward Processing**:

  * Iterate through `event_data.rewards`.

  * For each reward, check its `transformations`.

  * Apply transformation logic:

    * Get target pending card by index.

    * Check conditions (ID, Tags, Attributes).

    * If match:

      * **TRANSFORM**: Remove old card, spawn new card (ID = `resulting_card_id`), add new card to `internal_storage` (as reward).

      * **CONSUME**: Destroy old card.

      * **RETURN**: Move old card to `internal_storage` (as return).

  * **Fallback**: Any `pending_cards` NOT handled by any transformation should probably be consumed? Or returned?

    * User said: "待定暂存状态... 另在结算时决定这个卡牌怎么处理".

    * Assumption: If not transformed, default to CONSUME (as per original `reward` behavior) or RETURN?

      （回答：没有设置则默认设置为返还）

    * Let's default to **CONSUME** to be safe (if rule doesn't save it, it's gone), or add a default setting.

## 4. Code Changes

### `scripts/CardTransformation.gd` (New)

```gdscript
class_name CardTransformation
extends Resource

@export var target_index: int = 0
@export var required_card_id: String = ""
@export_enum("transform", "consume", "return") var action: String = "transform"
@export var resulting_card_id: String = "" # For transform
```

(User mentioned "如果他是等级三卡牌...". This implies checking ID or Tags. Let's add simple ID check first as requested: "填入卡牌id... cr01 转 cr02").

### `scripts/EventRewardData.gd`

Add:

```gdscript
@export var transformations: Array[CardTransformation] = []
```

### `scripts/EventPanel.gd`

Update `_process_finished_cards`:

1. Collect `reward` cards into `pending_cards`.
2. Loop `transformations`.
3. Process.
4. Clean up remaining pending cards (queue\_free).

## 5. User Request Specifics

* "转换0对应事件链中第一张被设置为待定的暂存卡牌" -> `target_index`

* "输入多个条件" -> `CardTransformation` resource array.

## 6. Verification

* Create a test scenario.

* Slot action = `reward`.

* Reward data = Transformation: Index 0, ID "Level3" -> "Level2".

* Run event with "Level3" card. Result: Receive "Level2" card.

* Run event with "Level2" card (no rule). Result: Card consumed (or default behavior).

