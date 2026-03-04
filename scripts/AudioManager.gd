extends Node

# Audio Buses
const BUS_MASTER = "Master"
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"

# Volume Settings (0.0 to 1.0)
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

# Audio Players
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 10
var _sfx_pool_index = 0

# Music Playlist Logic
var _current_playlist: Array[AudioStream] = []
var _playlist_index: int = 0

# Music Resources (Paths)
const MUSIC_MENU = "res://sounds/music/伏尔加船夫 Эй, ухнем!.mp3"
const MUSIC_DEFAULT_GAME = "res://sounds/music/在满洲的山岗上 На сопках Маньчжурии.mp3"
# You can add more default paths here

# SFX Library (Name -> Resource Path)
# You can populate this with actual paths
var sfx_library: Dictionary = {
	"ui_click": "res://sounds/sound/sound1.mp3",
	"card_click": "res://sounds/sound/sound2.mp3",
	"panel_open": "res://sounds/sound/sound3.mp3",
	"panel_close": "res://sounds/sound/sound3.mp3",
	"table_click": "res://sounds/sound/sound4.mp3",
	"drop_card": "res://sounds/sound/sound2.mp3",
	"work_complete": "res://sounds/sound/sound4.mp3",
	"ending_default": "res://sounds/music/辞九门回忆莫问归期.mp3"
}

# Preloaded Resources
var _sfx_resources: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_create_players()
	# Preload SFX if files exist
	# _preload_sfx()

func _setup_buses() -> void:
	# Ensure buses exist. If not, we might need to rely on Master.
	# We can't easily create buses at runtime that persist, but we can set them up for the session.
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, BUS_MASTER)
		
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)

func _create_players() -> void:
	# Music
	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)
	
	# Ambience
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = BUS_SFX # Or separate Ambience bus
	add_child(ambience_player)
	
	# SFX Pool
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		sfx_players.append(p)

func play_playlist(streams: Array[AudioStream], crossfade_duration: float = 1.0) -> void:
	_current_playlist = streams
	_playlist_index = 0
	
	if _current_playlist.is_empty():
		stop_music(crossfade_duration)
		return
		
	play_music(_current_playlist[0], crossfade_duration)

func _on_music_finished() -> void:
	if _current_playlist.size() > 1:
		_playlist_index = (_playlist_index + 1) % _current_playlist.size()
		play_music(_current_playlist[_playlist_index])
	elif _current_playlist.size() == 1:
		# Single track loops automatically if imported as loop, but we can force it here just in case
		play_music(_current_playlist[0])

func play_menu_music() -> void:
	var stream = load(MUSIC_MENU)
	if stream:
		play_music(stream)

func play_default_game_music() -> void:
	var stream = load(MUSIC_DEFAULT_GAME)
	if stream:
		play_music(stream)

func play_music(stream: AudioStream, crossfade_duration: float = 1.0) -> void:
	# If we call play_music directly, we clear playlist or set it to single item
	if _current_playlist.size() <= 1 or not _current_playlist.has(stream):
		_current_playlist = [stream]
		_playlist_index = 0
	
	if music_player.stream == stream:
		if not music_player.playing:
			music_player.play()
		return
		
	if stream == null:
		stop_music(crossfade_duration)
		return
		
	# Simple crossfade logic could be added here using Tweens
	# For now, just switch
	music_player.stop()
	music_player.stream = stream
	music_player.play()

func stop_music(fade_duration: float = 1.0) -> void:
	music_player.stop()
	_current_playlist.clear()
	_playlist_index = 0

func play_ambience(stream: AudioStream) -> void:
	if ambience_player.stream == stream:
		if not ambience_player.playing:
			ambience_player.play()
		return
	ambience_player.stream = stream
	ambience_player.play()

func play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> void:
	var stream = _get_sfx_stream(sfx_name)
	if stream:
		var player = sfx_players[_sfx_pool_index]
		player.stream = stream
		player.pitch_scale = pitch_scale
		player.play()
		_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	else:
		# Silently fail or log debug if needed
		pass

func _get_sfx_stream(name: String) -> AudioStream:
	if _sfx_resources.has(name):
		return _sfx_resources[name]
		
	if sfx_library.has(name):
		var path = sfx_library[name]
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				_sfx_resources[name] = res
				return res
	return null

# Volume Control
func set_bus_volume(bus_name: String, linear_value: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db = linear_to_db(linear_value)
		AudioServer.set_bus_volume_db(idx, db)
		AudioServer.set_bus_mute(idx, linear_value <= 0.001)

func set_master_volume(value: float) -> void:
	master_volume = value
	set_bus_volume(BUS_MASTER, value)

func set_music_volume(value: float) -> void:
	music_volume = value
	set_bus_volume(BUS_MUSIC, value)

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	set_bus_volume(BUS_SFX, value)
