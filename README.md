# Godot 复刻版《密教模拟器》(Cultist Simulator Godot Remake )(AKA Cultist Simulator Simulator )

本项目是一个使用 Godot 4.5.1 引擎复现《密教模拟器》(Cultist Simulator) 核心游戏系统的开源项目。

## 项目简介

通过Godot引擎重新构建《密教模拟器》中独特的卡牌交互、属性演变以及事件触发机制。
(作者注：最近比较忙，如果缺了什么等有时间再补）

## 技术栈

- **引擎版本**: Godot v4.5.1
- **编程语言**: GDScript
- **主要特性**:
  - 动态卡牌系统（的确很动态）
  - 事件系统逻辑（最为主要的）
  - 属性驱动的交互系统（指条件判断全看属性）
  - 灵活的数据驱动设计（指资源叠叠乐）
  - 事件链可视化编辑（较为主要的）

## 目录结构

- `scenes/`: 游戏主要场景（Tabletop, Card, Verb 等）
- `scripts/`: 核心逻辑脚本（GameManager, SaveManager, CardDatabase 等）
- `data/`: 游戏资源数据（卡牌定义、事件配置等）
- `pic/`: 图像素材资源
- `sounds/`: 音效与背景音乐
- `addons/event_chain_editor`: 事件链编辑助手（附加核心插件，实现事件的可视化编辑，在godot编辑器里添加）
- `.trae/`: 开发过程中积攒的和ai的垃圾话，可以一窥这个缺乏规范记录的项目的开发过程

## 快速开始

1. 确保已安装 [Godot Engine v4.5.1](https://godotengine.org/download)。
2. 克隆本仓库：
   
   ```bash
   git clone https://github.com/xiaozhao186/godot-CultistSimulatorSimulator-.git
   ```
3. 在 Godot 编辑器中导入并运行 `project.godot`。

## 开源协议

本项目采用 [MIT License](LICENSE)。
