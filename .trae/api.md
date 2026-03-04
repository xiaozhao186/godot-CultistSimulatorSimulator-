# API 文档（底部UI栏 / 设置面板）

## AppState（全局状态，观察者模式）

路径：`res://scripts/AppState.gd`（autoload）

### 信号

- `paused_changed(is_paused: bool)`：全局暂停状态变化
- `speed_changed(multiplier: float)`：速度倍率变化（1.0 / 2.0）
- `settings_open_changed(open: bool)`：设置面板开关变化

### 方法

- `is_paused() -> bool` / `set_paused(paused: bool)` / `toggle_pause()`
- `get_speed_multiplier() -> float` / `set_speed_multiplier(multiplier: float)` / `toggle_speed()`
- `is_settings_open() -> bool` / `open_settings()` / `close_settings()`

### 约束

- 打开设置面板会记录打开前的暂停状态，并自动暂停；关闭会恢复该状态。
- 调速通过 `Engine.time_scale` 影响基于 delta 的逻辑与 Timer（如事件计时、卡牌寿命）。

## SettingsService（设置持久化与应用）

路径：`res://scripts/SettingsService.gd`（autoload）

### 存储

- 位置：`user://settings.json`
- 字段：
  - `resolution`: `[w, h]`
  - `speed`: `1` 或 `2`

### 信号

- `resolution_changed(size: Vector2i)`
- `settings_saved(path: String)`
- `settings_load_failed(message: String)`
- `settings_save_failed(message: String)`

### 方法

- `get_resolution() -> Vector2i`
- `set_resolution(size: Vector2i) -> bool`

## UI 组件

### BottomBar

- Scene：`res://scenes/BottomBar.tscn`
- Script：`res://scripts/BottomBar.gd`
- 行为：监听 AppState 的信号同步按钮状态；设置面板打开时禁用暂停与调速按钮。

### SettingsPanel

- Scene：`res://scenes/SettingsPanel.tscn`
- Script：`res://scripts/SettingsPanel.gd`
- 行为：面板可见性由 `AppState.settings_open_changed` 驱动；分辨率变更调用 `SettingsService.set_resolution()` 并保存。
