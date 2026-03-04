# 事件链创建助手 (Event Chain Editor) - AI 开发实施指南

本文档旨在为 AI 辅助开发提供明确的上下文、架构设计和实施步骤，以便接手此任务的 AI Agent 能够独立完成 "Event Chain Editor" 插件的开发。

## 1. 项目背景与现状

当前项目是一个基于卡牌和行为（Verb）的叙事/管理游戏（类似《密教模拟器》）。

* **核心机制**：玩家将卡牌放入行为（Verb）的槽位中，触发事件（Event），经过一定时间后结算结果（分支跳转、奖励产出）。
* **数据驱动**：所有的事件逻辑均通过 Godot 的 `Resource` 系统定义（`EventData`, `EventBranchData` 等）。
* **当前痛点**：目前事件链的创建完全依赖手动编辑 `.tres` 文件，缺乏可视化视图，难以管理复杂的分支和跳转逻辑。

**现有核心代码参考**：

* [EventData.gd](file:///scripts/EventData.gd): 事件的数据定义。
* [EventBranchData.gd](file:///scripts/EventBranchData.gd): 分支数据定义。
* [EventPanel.gd](file:///scripts/EventPanel.gd): 运行时解析和执行事件逻辑的核心。

## 2. 任务目标

在 Godot 编辑器内部开发一个 **EditorPlugin**，提供可视化的 **节点图编辑器 (Node Graph Editor)**。

* **输入**：现有的 `.tres` 资源文件或新建的图文件。
* **输出**：符合项目现有格式的 `.tres` 资源文件（运行时无需修改即可直接使用）。
* **核心功能**：可视化拖拽节点、连线定义跳转关系、属性侧边栏编辑。

## 3. 技术架构设计

### 3.1 核心组件

1. **EventGraphData (Resource)**
   
   * **定义**：一个新的 Resource 类型，仅用于编辑器保存图的元数据（节点位置、缩放等）。
   * **职责**：它引用一组 `EventData` 资源，并记录它们在图中的 UI 坐标。它**不**替代 `EventData`，只是一个“容器”或“视图”。
   * **路径**：`addons/event_chain_editor/resources/event_graph_data.gd`

2. **EventChainEditor (EditorPlugin)**
   
   * **职责**：插件入口。注册 `EventGraphData` 资源，添加底部 Dock 或主界面 Tab，处理文件打开事件。
   * **路径**：`addons/event_chain_editor/event_chain_editor.gd`

3. **EventGraphView (Control)**
   
   * **职责**：主 UI 面板，包含 `GraphEdit` 控件。处理节点的添加、删除、连线（Connection）、断开（Disconnection）。
   * **路径**：`addons/event_chain_editor/scenes/graph_view.tscn`

4. **EventNode (GraphNode)**
   
   * **职责**：对应一个 `EventData` 的可视化节点。
   * **端口 (Slots)**：
     * **Left (In)**: 入口。
     * **Right (Out)**:
       * Slot 0: Instant Branches (即时分支)
       * Slot 1: Branches (结果分支)
       * Slot 2: Default Next Event (默认后续)
   * **路径**：`addons/event_chain_editor/scenes/event_node.tscn`

### 3.2 目录结构规划

```text
res://addons/event_chain_editor/
├── plugin.cfg                  # 插件元数据
├── event_chain_editor.gd       # EditorPlugin 入口脚本
├── resources/
│   └── event_graph_data.gd     # 图数据资源定义
├── scenes/
│   ├── graph_view.tscn         # 主编辑器视图
│   ├── graph_view.gd
│   ├── event_node.tscn         # 单个事件节点
│   └── event_node.gd
└── assets/                     # 图标等资源
```

## 4. 分阶段实施计划

### 阶段一：原型闭环 (Prototype)

**目标**：跑通“新建图 -> 拖入/创建节点 -> 简单连线 -> 保存”流程。

1. **环境搭建**：创建插件目录结构，启用插件，确保 Dock/Tab 可见。
2. **数据层**：实现 `EventGraphData`，支持存储 `{ event_resource_path: Vector2 }` 的字典。
3. **UI 基础**：实现 `GraphView` 和基础 `EventNode`（仅显示标题）。
4. **连线逻辑**：仅实现 `default_next_event` 的连线。
   * 连线时：`from_node.event_data.default_next_event = to_node.event_data`
   * 断线时：`from_node.event_data.default_next_event = null`
5. **保存/加载**：实现将 GraphEdit 的状态保存到 `EventGraphData`，并将修改写回 `EventData` 文件。

### 阶段二：核心功能 (Core Features)

**目标**：支持完整的分支逻辑。

1. **多分支支持**：`EventNode` 扩展端口，支持 `branches` 数组的连线。
2. **条件编辑**：点击连线（或在节点属性中），弹出/显示 Inspector 编辑 `EventCondition`。
3. **即时分支**：支持 `instant_branches` 的连线和区分显示（如不同颜色的线）。

### 阶段三：体验优化 (Polishing)

**目标**：生产级易用性。

1. **拖拽支持**：支持从 FileSystem Dock 拖拽 `.tres` 文件到 GraphEdit 中生成节点。
2. **自动布局**：简单的自动排列算法。
3. **校验与提示**：检测死循环、空分支等问题。

## 5. 开发注意事项 (给 AI 的 Tips)

1. **不要修改运行时代码**：除非万不得已，不要修改 `scripts/` 下的现有文件。所有逻辑应封装在 `addons/` 中。
2. **使用 ResourceFormatLoader/Saver**：如果需要处理自定义扩展名，但尽量复用 Godot 原生的 Resource 保存机制。
3. **GraphEdit API**：熟悉 Godot 4.5.1 的 `GraphEdit` 信号（`connection_request`, `disconnection_request`, `delete_nodes_request`）。
4. **工具脚本 (`@tool`)**：插件代码必须是 `@tool` 才能在编辑器内运行。记得在修改 `@tool` 脚本后重启插件或重新加载项目以生效。

## 6. 下一步行动

请按照 **阶段一** 的计划开始工作：

1. 创建 `addons/event_chain_editor/` 文件夹。
2. 创建 `plugin.cfg` 和 `event_chain_editor.gd`。
3. 验证插件能否在 Godot 项目设置中启用。
