# Godot 复刻版《密教模拟器》(Cultist Simulator Godot Remake)

本项目是一个使用 Godot 4.5.1 引擎复现《密教模拟器》(Cultist Simulator) 核心游戏系统的开源项目。

## 项目简介

通过Godot引擎重新构建《密教模拟器》中独特的卡牌交互、属性演变以及事件触发机制。

## 技术栈

- **引擎版本**: Godot v4.5.1
- **编程语言**: GDScript
- **主要特性**:
  - 动态卡牌系统
  - 事件与时间流逝逻辑
  - 属性驱动的交互系统
  - 灵活的数据驱动设计

## 目录结构

- `scenes/`: 游戏主要场景（Tabletop, Card, Verb 等）
- `scripts/`: 核心逻辑脚本（GameManager, SaveManager, CardDatabase 等）
- `data/`: 游戏资源数据（卡牌定义、事件配置等）
- `pic/`: 图像素材资源
- `sounds/`: 音效与背景音乐

## 快速开始

1. 确保已安装 [Godot Engine v4.5.1](https://godotengine.org/download)。
2. 克隆本仓库：
   
   ```bash
   git clone https://github.com/xiaozhao186/godot-CultistSimulatorSimulator-.git
   ```
3. 在 Godot 编辑器中导入并运行 `project.godot`。

## 开源协议

本项目采用 [MIT License](LICENSE)。
