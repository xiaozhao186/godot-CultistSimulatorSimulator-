# Godot Cultist Framework

A Cultist Simulator-inspired card game framework for Godot 4.5.

## How to Run
1. Open the project in Godot 4.5.
2. Run `scenes/Tabletop.tscn` as the main scene.
3. Use WASD to move the camera, Mouse Wheel to zoom.
4. Use the Debug Console (top left) to spawn cards and verbs.

## How to Add Content
### Create New Cards
1. In the FileSystem dock, right-click -> Create New -> Resource.
2. Search for `CardData`.
3. Fill in the ID, Name, Description, and Attributes (e.g., `{"reason": 1}`).
4. Save it in `res://data/cards/`.

### Create New Events
1. Create `EventSlotData` resources for your requirements (e.g., "Requires Reason").
2. Create `EventData` resource.
3. Add slots to the `Slots` array.
4. Set duration and other properties.

## Architecture
- **Scripts**:
  - `CardData`, `EventData`: Define the data.
  - `Token`: Base class for draggable objects.
  - `Card`, `Verb`: Specific token types.
  - `EventPanel`: The UI window for events.
  - `EventSlot`: Handles card acceptance logic.
  - `GameManager`: Handles global signals (drag/drop, clicks).
- **Scenes**:
  - `Tabletop.tscn`: The main game world.
  - `Card.tscn`, `Verb.tscn`: Prefabs.
