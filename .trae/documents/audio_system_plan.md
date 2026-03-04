# Plan: Audio System Implementation

## Goal

Implement a comprehensive Audio System including Background Music (BGM), Sound Effects (SFX), and Volume Settings, integrated with the existing game architecture.

## 1. Core Audio System (AudioManager)

Create a global `AudioManager` to handle all audio playback.

* **Script**: `scripts/AudioManager.gd` (Autoload)

* **Features**:

  * **Buses**: Master, Music, SFX.

  * **Players**:

    * `music_player`: For BGM (looping).

    * `ambience_player`: For ambient sounds (looping).

    * `sfx_players`: Pool of players for one-shot sound effects.

  * **API**:

    * `play_music(stream: AudioStream, crossfade: float = 1.0)`

    * `play_ambience(stream: AudioStream)`

    * `play_sfx(stream_name: String)` (Loads from `sounds/` folder or preloaded dictionary)

    * `set_volume(bus_index: int, value: float)`

    * `stop_music()`

## 2. Settings Integration

Extend the existing settings system to support audio volume control.

* **SettingsService**:

  * Update `scripts/SettingsService.gd` to include `master_volume`, `music_volume`, `sfx_volume`.

  * Update `_save()` and `_load()` to persist these values.

  * Add `set_volume(bus_name, value)` method that calls `AudioManager`.

* **SettingsPanel**:

  * Update `scripts/SettingsPanel.gd` to dynamically add Volume Sliders (Master, Music, SFX) to the settings UI.

  * Connect sliders to `SettingsService`.

## 3. Data Integration

* **ScenarioData**:

  * Update `scripts/ScenarioData.gd` to include `@export var bgm: AudioStream`.

## 4. Game Integration (Hooks)

Inject audio triggers into existing scripts.

* **Main Menu**:

  * `scripts/MainMenu.gd`: Play main menu music on `_ready`.

* **Game Flow**:

  * `scripts/GameManager.gd`:

    * In `start_scenario`: Play the scenario's BGM (or default if null).

    * In `trigger_ending`: Play ending SFX/Music.

* **UI Interactions**:

  * `scripts/UIButton.gd`: Add click sound on `pressed`.

  * `scripts/Token.gd`: Add click sound in `_handle_click`.

  * `scripts/EventPanel.gd`:

    * Play "drop" sound in `_finish_drop_if_valid`.

    * Play "work complete" sound in `_on_timer_timeout`.

    * Play "open/close" sounds in `_ready` / `_on_close_button_pressed`.

  * `scripts/DetailsPanel.gd`:

    * Play "open" sound in `_on_token_clicked`.

    * Play "close" sound.

* **Table Interaction**:

  * Add input handling to `scripts/GameManager.gd` (or `Tabletop` scene script) to detect clicks on the background (Table) and play a sound.

## 5. Resources

* Use placeholders or existing files in `d:\Program Files (x86)\Godot_v4.5.1\box\ppd-1\sounds` for testing.

* The user will provide specific sound files later; we will implement the *system* to play them.

## 6. Verification

* Verify that settings are saved/loaded.

* Verify that music plays and loops.

* Verify that SFX plays on interactions.

* Verify that volume sliders work.

