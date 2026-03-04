class_name ScenarioData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var bgm_playlist: Array[AudioStream] = []
@export var initial_card_entries: Array[ScenarioInitialCardEntry] = []
@export var initial_verbs: Array[VerbData] = []
@export var starting_events: Array[EventData] = []
@export var endings: Array[EndingData] = []
