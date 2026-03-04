# 增加卡牌计时结束变形功能计划

## 1. 目标
为卡牌增加一个可选功能：当卡牌的寿命（计时）结束时，不再直接销毁，而是变形成另一张指定的卡牌。该功能需在编辑器中通过复选项配置。

## 2. 修改范围

### 2.1 数据层 (CardData.gd)
在 `CardData.gd` 中添加以下导出变量，用于在编辑器中配置：
- `transform_on_expire`: bool (默认 false) —— 是否开启计时结束变形功能。
- `transform_card_id`: String (默认空字符串) —— 变形后的目标卡牌 ID。

### 2.2 逻辑层 (Card.gd)
修改 `Card.gd` 的 `_process` 函数中关于寿命结束的处理逻辑：
- 当 `current_lifetime <= 0` 时：
  - 检查 `data.transform_on_expire` 是否为 true 且 `data.transform_card_id` 有效。
  - 如果满足条件：
    - 从 `CardDatabase` 获取目标卡牌的数据。
    - 实例化一个新的卡牌场景 (`Card.tscn`)。
    - 将新卡牌添加到当前卡牌的父节点（通常是 Tabletop）。
    - 设置新卡牌的位置为当前卡牌的位置。
    - 调用新卡牌的 `setup(new_data)`。
    - 销毁当前卡牌 (`queue_free()`)。
  - 如果不满足条件（默认行为）：
    - 直接销毁当前卡牌 (`queue_free()`)。

## 3. 验证步骤
1.  在编辑器中挑选或创建一个 CardData 资源（例如 `card_test_transform`）。
2.  勾选 `transform_on_expire` 并设置 `transform_card_id` 为另一个存在的卡牌 ID（例如 `card_gold`）。
3.  设置一个较短的 `lifetime`（例如 5秒）。
4.  运行游戏，生成该卡牌。
5.  观察倒计时结束后，卡牌是否原地变为目标卡牌，且无报错。
