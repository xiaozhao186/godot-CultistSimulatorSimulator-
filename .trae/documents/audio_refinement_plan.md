# Plan: Audio System Refinement and Expansion

## Goal

Fix audio overlap issues, expand audio coverage to all UI elements, support hidden entity silencing, ensure BGM persistence on load, upgrade scenario music capabilities (playlists), and centralize audio resource management.

## 1. AudioManager Upgrade

Refactor `scripts/AudioManager.gd` to be the central hub for all music logic and resources.

* **Resource Centralization**: Move all hardcoded music paths (Menu, Default Game, Endings) into `AudioManager`.

* **Playlist Support**: Implement a playlist system to handle multiple BGM tracks for scenarios.

  * Add `play_playlist(streams: Array[AudioStream])`.

  * Handle `finished` signal from `music_player` to cycle through tracks.

  * Fallback to single loop if only one track exists.

* **Helper Methods**:

  * `play_menu_music()`

  * `play_default_game_music()`

  * `play_ending_music(stream: AudioStream)`

## 2. Data Structure Updates

* **ScenarioData** (`scripts/ScenarioData.gd`):

  * Replace `bgm` (single) with `bgm_playlist` (Array\[AudioStream]).

* **EndingData** (`scripts/EndingData.gd`):

  * Add `bgm` (AudioStream) field for ending-specific music.

## 3. Game Logic Fixes (GameManager)

* **Audio Overlap Fix** (`scripts/GameManager.gd`):

  * In `_unhandled_input` (table click), add checks to ensure we are NOT:

    * Hovering over any Token (`hovered_tokens` is not empty).

    * Currently dragging a token (`dragging_token != null`).

    * Clicking on a UI element (Godot's UI usually consumes input, but `_unhandled_input` fires if they don't; verify if `GuiInput` is needed).

* **Load Game BGM** (`scripts/GameManager.gd`):

  * In `restore_game_state`, trigger `AudioManager.play_playlist(current_scenario.bgm_playlist)` (or default) after loading the scenario.

* **Ending Music** (`scripts/GameManager.gd`):

  * In `trigger_ending`, check `ending_data.bgm`.

  * If present, call `AudioManager.play_music(ending_data.bgm)`.

  * If absent, play a default ending theme from `AudioManager`.

  * Remove the old "victory/defeat" SFX logic if it conflicts, or keep as SFX layer.

## 4. UI Audio Coverage

* **Main Menu** (`scripts/MainMenu.gd`):

  * Connect all menu buttons (`NewGame`, `Continue`, `Settings`, `Exit`, `StartScenario`, `Back`) to `AudioManager.play_sfx("ui_click")`.

* **Event Panel** (`scripts/EventPanel.gd`):

  * Connect `StartButton` and `CollectButton` (which reuses start button) to `AudioManager.play_sfx("ui_click")`.

  * Ensure these connections are dynamic since buttons might change state.

## 5. Hidden Verb Silencing

* **Verb Logic** (`scripts/Verb.gd`):

  * In `_on_clicked` and any other interaction points:

    * Check `if visible == false` or `if data.hidden_runtime`.

    * If hidden, return early or skip `AudioManager` calls.

    * Note: Hidden verbs shouldn't be clickable usually, but if they are triggered by other means (auto-start), ensure no sound leaks if not desired.

## 6. Implementation Steps

1. **Modify Data Scripts**: Update `ScenarioData` and `EndingData`.
2. **Update AudioManager**: Add playlist logic and centralize paths.
3. **Update GameManager**: Fix table click logic, add load game music, update ending logic.
4. **Update UI Scripts**: Add missing button sounds in `MainMenu` and `EventPanel`.
5. **Update Verb Script**: Add silence check.

