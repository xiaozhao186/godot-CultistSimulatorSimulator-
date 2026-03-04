# Godot 4.5 2D Card Game Framework Plan

This plan aims to build a "Cultist Simulator"-like framework that is highly extensible through Godot's `Resource` system.

## 1. Project Setup & Architecture
- **Goal**: Initialize project settings and directory structure.
- **Settings**: Resolution 1920x1080 (Windowed/Fullscreen), Stretch Mode: Canvas Items.
- **Directory Structure**:
  - `res://data/` (Resources for Cards and Events)
  - `res://scenes/` (Scene files)
  - `res://scripts/` (Core logic)
  - `res://assets/` (Placeholder graphics)

## 2. Data System (The "Extensible" Part)
We will use `Resource` classes so you can create new cards and events directly in the Inspector.
- **`CardData` (Resource)**:
  - `id`: String
  - `name`: String
  - `description`: String
  - `icon`: Texture2D
  - `attributes`: Dictionary (e.g., `{"reason": 1, "mortal": 1}`)
  - `lifetime`: float (Optional, for decaying cards)
- **`EventSlotData` (Resource)**:
  - `required_attributes`: Dictionary (e.g., `{"reason": 1}`)
  - `forbidden_attributes`: Dictionary
- **`EventData` (Resource)**:
  - `id`: String
  - `title`: String
  - `description`: String
  - `slots`: Array[EventSlotData]
  - `duration`: float
  - `start_effects`: Dictionary (Immediate changes)
  - `end_effects`: Dictionary (Rewards/Results)
  - `linked_events`: Array[EventData] (Next stages)

## 3. Core Interaction (The "Tabletop")
- **`MainCamera`**:
  - WASD to pan.
  - Mouse Wheel to zoom.
  - Middle mouse drag to pan.
- **`Token` (Base Node)**:
  - Base scene for draggable objects (Cards and Verbs).
  - Handles: Click (Select), Drag & Drop physics, Hover effects.
- **`Card` (extends Token)**: Displays info from `CardData`.
- **`Verb` (extends Token)**: Represents actions (e.g., "Work", "Dream"). Opens `EventWindow`.

## 4. Event System Logic
- **`EventWindow` (UI)**:
  - Pop-up panel when a `Verb` is clicked.
  - **Slots**: Dynamic containers that accept `Card` tokens.
  - **Logic**:
    1. Check if dropped card matches `EventSlotData` requirements.
    2. "Start" button enables when requirements met.
    3. **Timer Phase**: Progress bar fills up.
    4. **Completion**: Spawn result cards, trigger next event, or modify stats.
- **`DetailsPanel` (UI)**:
  - Top-right overlay showing details of the currently selected card/verb.

## 5. Debug Console
- A collapsible UI panel.
- **Functions**:
  - "Spawn Card [ID]": Creates a card at mouse position.
  - "Trigger Event [ID]": Force starts an event.
  - "Add Time": Fast forward timers.

## 6. Implementation Steps
1.  **Core Resources**: Define `CardData` and `EventData` scripts.
2.  **Table & Camera**: specific basic tabletop environment.
3.  **Card/Verb Interaction**: Implement dragging and clicking.
4.  **Event UI**: Build the window with slots that validate cards.
5.  **Game Loop**: Connect the start button, timer, and result generation.
6.  **Debug Tools**: Add the testing console.

This framework allows you to add new content by simply right-clicking in the FileSystem -> Create New -> Resource -> CardData/EventData, without writing code.
