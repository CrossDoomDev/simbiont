extends Node
## Original synthesized music and effects. Remains active while gameplay is paused.

const AUDIO_DIRECTORY: String = "res://assets/audio/"
const EFFECTS: Array[String] = ["shoot", "hit", "hurt", "enemy_die", "pickup", "ui", "organ", "upgrade", "objective", "success", "boss", "death"]
const ALIASES: Dictionary = {"click": "ui", "enemy_death": "enemy_die", "damage": "hurt", "loot": "pickup", "buy": "upgrade", "win": "success", "lose": "death", "node": "objective"}

var _music_players: Array[AudioStreamPlayer] = []
var _effects_players: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _context: String = ""
var _active_music: int = 0
var _music_volume: float = 0.5
var _sfx_volume: float = 0.7
var _fade: Tween
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Automated headless checks have no audible output device.
	if DisplayServer.get_name() == "headless":
		return
	_rng.randomize()
	for i: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Music" + str(i)
		add_child(player)
		_music_players.append(player)
	for i: int in range(12):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Effect" + str(i)
		add_child(player)
		_effects_players.append(player)
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "OrganicAmbience"
	add_child(_ambient)
	_ambient.stream = _load_stream("ambient", true)
	if _ambient.stream != null:
		_ambient.play()
	var progress: Node = get_node_or_null("/root/Progress")
	if progress != null and progress.has_signal("changed"):
		progress.connect("changed", update_volumes)
	update_volumes()
	set_context("hub")

func _load_stream(name: String, looping: bool = false) -> AudioStream:
	var key: String = name + ("_loop" if looping else "")
	if _cache.has(key):
		return _cache[key] as AudioStream
	var path: String = AUDIO_DIRECTORY + name + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return null
	if looping and stream is AudioStreamWAV:
		var wave: AudioStreamWAV = stream.duplicate() as AudioStreamWAV
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = int(wave.get_length() * wave.mix_rate)
		stream = wave
	_cache[key] = stream
	return stream

func play_sfx(name: String) -> void:
	name = str(ALIASES.get(name, name))
	if not EFFECTS.has(name) or _sfx_volume <= 0.0 or _effects_players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var interval: int = 45 if name in ["shoot", "hit", "pickup"] else 90
	if now - int(_last_played.get(name, -10000)) < interval:
		return
	var stream: AudioStream = _load_stream(name)
	if stream == null:
		return
	_last_played[name] = now
	var selected: AudioStreamPlayer = _effects_players[0]
	for candidate: AudioStreamPlayer in _effects_players:
		if not candidate.playing:
			selected = candidate
			break
	selected.stop()
	selected.stream = stream
	selected.volume_db = linear_to_db(maxf(_sfx_volume * (0.66 if name == "shoot" else 0.9), 0.0001))
	selected.pitch_scale = _rng.randf_range(0.96, 1.04) if name in ["shoot", "hit", "enemy_die", "pickup"] else 1.0
	selected.play()

func set_context(context: String) -> void:
	var next_context: String = "mission" if context in ["mission", "combat", "forest", "swamp", "boss"] else "hub"
	if next_context == _context or _music_players.is_empty():
		return
	_context = next_context
	var stream: AudioStream = _load_stream(next_context, true)
	if stream == null:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var previous: AudioStreamPlayer = _music_players[_active_music]
	_active_music = 1 - _active_music
	var current: AudioStreamPlayer = _music_players[_active_music]
	current.stop()
	current.stream = stream
	current.volume_db = -70.0
	current.play()
	current.stream_paused = _music_volume <= 0.0
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(previous, "volume_db", -70.0, 0.8)
	_fade.tween_property(current, "volume_db", _music_decibels(), 0.8)
	_fade.chain().tween_callback(previous.stop)

func _music_decibels() -> float:
	return linear_to_db(maxf(_music_volume * 0.78, 0.0001))

func update_volumes() -> void:
	var progress: Node = get_node_or_null("/root/Progress")
	if progress != null:
		var preferences: Dictionary = progress.get("settings")
		_music_volume = clampf(float(preferences.get("music", 0.5)), 0.0, 1.0)
		_sfx_volume = clampf(float(preferences.get("sfx", 0.7)), 0.0, 1.0)
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not _music_players.is_empty():
		_music_players[_active_music].volume_db = _music_decibels()
		_music_players[_active_music].stream_paused = _music_volume <= 0.0
		_music_players[1 - _active_music].stop()
	if _ambient != null:
		_ambient.volume_db = linear_to_db(maxf(_sfx_volume * 0.18, 0.0001))
		_ambient.stream_paused = _sfx_volume <= 0.0
	for player: AudioStreamPlayer in _effects_players:
		if _sfx_volume <= 0.0:
			player.stop()

func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	for player: AudioStreamPlayer in _music_players + _effects_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.stream = null
	_cache.clear()
