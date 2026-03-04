# 开始界面与存档系统设计方案

## 1. 概述
本方案旨在为游戏添加一个主菜单（开始界面），并实现基础的存档/读档功能，以及基于剧本文件的战役加载机制。

## 2. 界面设计

### 2.1 主菜单场景 (`MainMenu.tscn`)
- **背景**：简单的背景图或动态背景。
- **UI布局**：垂直排列的按钮组（VBoxContainer）。
  - **开始新游戏 (New Game)**：点击后弹出剧本选择子菜单。
  - **继续游戏 (Continue)**：若存在最新存档，则激活；点击直接加载最近的存档。
  - **加载游戏 (Load Game)**：点击弹出存档列表窗口（预留，本次先实现基础功能）。
  - **设置 (Settings)**：点击打开现有的设置面板。
  - **退出 (Exit)**：退出游戏。

### 2.2 剧本选择子菜单 (`ScenarioSelectionPanel`)
- **显示方式**：模态窗口或覆盖层。
- **内容**：显示可用剧本列表。
  - 剧本数据来源：扫描特定目录下的剧本定义文件（.tres 或 .json/.md 解析）。
  - 初始阶段：硬编码或读取指定的测试剧本路径（如用户提供的 markdown 文件路径，需转换为游戏可读格式或仅作为元数据引用）。
  - 选中剧本后点击“开始”，进入 `Tabletop` 场景并初始化该剧本。

## 3. 数据结构与存档系统

### 3.1 剧本定义 (`ScenarioData`)
创建一个新的资源类型 `ScenarioData` (继承 Resource)，用于定义一局游戏的初始状态：
- `id`: String
- `title`: String
- `description`: String
- `initial_cards`: Array[CardData] (初始拥有的卡牌)
- `initial_verbs`: Array[VerbData] (初始可用的行动)
- `starting_events`: Array[EventData] (自动触发的起始事件)

*注：用户提供的 Markdown 文件包含剧本设计，我们需要将其转化为游戏内的 `ScenarioData` 资源或通过解析器读取。为简化实现，初期建议手动配置一个 `ScenarioData` 资源对应 Markdown 内容。*

### 3.2 存档数据结构 (`SaveGameData`)
定义存档格式（JSON 或 Resource），包含：
- `scenario_id`: String (当前剧本ID)
- `timestamp`: String (存档时间)
- `cards`: Array[Dictionary] (桌面上所有卡牌的状态：ID, 位置, 寿命, 堆叠数等)
- `verbs`: Array[Dictionary] (当前解锁的行为：ID, 位置)
- `events`: Array[Dictionary] (当前运行中的事件面板状态：EventID, 倒计时, 内部卡牌等)
- `global_variables`: Dictionary (全局变量/黑板数据)

### 3.3 存档管理器 (`SaveManager` - Autoload)
- `save_game(slot_name: String)`: 序列化当前 `Tabletop` 状态并写入文件。
- `load_game(slot_name: String)`: 读取文件，切换到 `Tabletop` 场景，并反序列化恢复状态。
- `get_save_list()`: 获取所有可用存档。
- `continue_last_save()`: 加载最新的自动存档或手动存档。

## 4. 实施步骤

### 第一阶段：基础设施
1.  **创建 `SaveManager` (Autoload)**：实现序列化/反序列化逻辑。
2.  **创建 `ScenarioData` 资源脚本**：定义剧本数据结构。
3.  **创建测试剧本资源**：根据《工厂撤离战》文档，配置一个基础的 `ScenarioData.tres`（包含初始卡牌、Verb等）。

### 第二阶段：主菜单实现
1.  **制作 `MainMenu.tscn`**：搭建 UI，连接按钮信号。
2.  **实现剧本选择逻辑**：列出可用的 `ScenarioData` 资源。
3.  **对接游戏启动**：点击开始后，将选中的 `ScenarioData` 传递给 `GameManager`，然后切换场景。

### 第三阶段：游戏内加载逻辑
1.  **修改 `GameManager`**：
    - 添加 `start_scenario(data: ScenarioData)` 方法，用于初始化一局新游戏（生成初始卡牌/Verb）。
    - 在 `Tabletop` 场景加载完成 (`_ready`) 时，检查是否有待加载的剧本或存档数据。
2.  **实现 `save_game` 逻辑**：遍历 `Tabletop` 节点，收集所有 `Card`, `Verb`, `EventPanel` 的数据。
3.  **实现 `load_game` 逻辑**：清空当前 `Tabletop`，根据数据重建对象。

## 5. 针对用户需求的特别说明
- **剧本文件关联**：用户提到的 `.md` 文件是设计文档。我们将创建一个名为 `scenario_factory_evacuation.tres` 的资源文件来“代表”这个剧本，并在游戏内读取它。
- **设置面板复用**：直接复用现有的 `SettingsPanel`，在主菜单中实例化调用。

## 6. 验证计划
1.  启动游戏进入主菜单。
2.  点击“设置”，确认面板正常弹出且可用。
3.  点击“开始新游戏”，选择“工厂撤离战”，确认进入游戏且初始卡牌/行为正确生成。
4.  在游戏中进行操作（移动卡牌、开始事件）。
5.  （后续）点击保存，退出，再点击“继续游戏”，确认状态恢复。
