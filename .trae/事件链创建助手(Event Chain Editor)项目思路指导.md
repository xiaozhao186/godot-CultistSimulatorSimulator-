# 事件链创建助手 (Event Chain Editor) - 项目思路指导文档

## 1. 项目概述

**目标**：在 Godot 编辑器内部开发一个可视化的“节点图编辑器（Node Graph Editor）”，用于直观地创建、编辑和管理游戏的事件链逻辑。

**核心理念**：
*   **非侵入式**：完全基于现有的 Resource 数据结构 (`EventData`, `EventBranchData` 等)，不修改游戏运行时逻辑。
*   **所见即所得**：将抽象的数据引用关系转化为可视化的连线和节点。
*   **生产力工具**：提供批量操作、即时预览、错误检查等功能，提升策划配置效率。

**目标用户**：游戏策划、关卡设计师（非程序员背景）。

---

## 2. 架构设计

本工具将作为 Godot 的 **EditorPlugin**（编辑器插件）实现。

### 2.1 数据流向

```mermaid
graph LR
    A[策划操作 GraphEdit] -->|修改| B(EventGraphData 资源)
    B -->|序列化/保存| C[EventData 资源文件 (.tres)]
    C -->|游戏运行时加载| D[EventPanel / GameManager]
```

*   **前端**：Godot 编辑器界面，包含 GraphEdit（图布）、GraphNode（事件节点）、Inspector（属性面板）。
*   **中间层**：插件逻辑，负责将 Graph 的节点位置、连接关系映射到底层的 Resource 数据。
*   **后端**：现有的 Resource 文件系统。

### 2.2 核心组件

1.  **EventGraphData (Resource)**:
    *   **新定义的资源类型**，用于保存“图”本身的信息。
    *   存储内容：包含哪些 EventData、每个 EventData 在图中的位置 (Vector2)、图的缩放/偏移量。
    *   *注意：EventData 本身不存储“我在图里的坐标”，这样保持了运行时数据的纯净。*

2.  **EventChainEditor (EditorPlugin)**:
    *   插件入口。
    *   负责注册自定义资源 `EventGraphData`。
    *   负责添加编辑器底部的 Dock 或主视图的 Tab。
    *   负责处理“双击 EventGraphData 文件”时的打开逻辑。

3.  **EventGraphView (Control)**:
    *   包含 `GraphEdit` 控件的主 UI。
    *   处理节点的增删改查、连线、右键菜单、工具栏。

4.  **EventNode (GraphNode)**:
    *   可视化节点，对应一个 `EventData`。
    *   **端口 (Slots)** 设计：
        *   **左侧 (输入)**：表示“进入此事件”。
        *   **右侧 (输出)**：
            *   端口 0：`instant_branches` (即时/配置预览分支)。
            *   端口 1：`branches` (结果/运行时分支)。
            *   端口 2：`default_next_event` (默认后续)。

---

## 3. 功能规格

### 3.1 阶段一：原型 (Prototype)

**目标**：跑通“创建图 -> 添加节点 -> 连线 -> 保存 -> 游戏运行”的闭环。

*   **图管理**：
    *   创建/保存 `EventGraphData` 资源。
    *   图数据的序列化与反序列化。
*   **节点操作**：
    *   从文件系统拖拽现有的 `EventData` `.tres` 到图中生成节点。
    *   在图中右键新建空白 `EventData`（自动保存为独立文件）。
    *   节点显示：标题（Event ID/Name）、基础属性摘要（Duration）。
*   **基础连线**：
    *   仅支持 `default_next_event` 的连接。
    *   连线建立时，自动修改 `EventData` 的 `default_next_event` 字段。
    *   断开连线时，清空该字段。

### 3.2 阶段二：完善 (Production Ready)

**目标**：支持完整的分支、条件和奖励配置。

*   **复杂分支连线**：
    *   **Branch 端口**：支持从一个端口拉出多条线（对应 `branches` 数组中的多个 `EventBranchData`）。
    *   **连线属性**：点击连线，在 Inspector 中编辑 `EventCondition`（条件）和 `Probability`（概率）。
*   **可视化增强**：
    *   不同类型的连线使用不同颜色（如：即时分支用虚线，结果分支用实线）。
    *   节点内显示“奖励”摘要图标（卡牌、Verb）。
*   **辅助功能**：
    *   **自动布局**：简单的节点自动排列。
    *   **校验**：检测死循环、检测未配置的空分支。

---

## 4. 目录结构规划

建议将插件放置在 `addons/` 目录下：

```text
res://
  addons/
    event_chain_editor/
      plugin.cfg              # 插件配置文件
      event_chain_editor.gd   # 插件主脚本 (EditorPlugin)
      resources/
        event_graph_data.gd   # 自定义资源定义
      scenes/
        graph_view.tscn       # 主视图场景
        graph_view.gd
        event_node.tscn       # 节点预制体
        event_node.gd
      assets/                 # 图标、样式等
```

---

## 5. 开发步骤建议 (Next Steps)

1.  **环境准备**：
    *   创建 `addons/event_chain_editor/` 目录。
    *   创建 `plugin.cfg` 和主脚本，启用插件，确认能在编辑器看到“Event Chain”界面。

2.  **数据层实现**：
    *   编写 `EventGraphData.gd`，定义好存储图数据的格式。

3.  **UI 骨架搭建**：
    *   制作 `GraphView` 场景，放入 `GraphEdit`。
    *   制作 `EventNode` 场景，设计好 Slot 布局。

4.  **核心逻辑 - 加载与保存**：
    *   实现 `load_graph(data: EventGraphData)`：根据数据生成节点和连线。
    *   实现 `save_graph()`：遍历 GraphEdit 的子节点，写回 `EventGraphData` 和各个 `EventData`。

5.  **交互实现 - 连线**：
    *   监听 `connection_request` 和 `disconnection_request` 信号。
    *   编写逻辑将连线操作映射为 `EventData` 属性的修改。