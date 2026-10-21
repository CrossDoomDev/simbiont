extends SceneTree
## Capture actual Godot mixer output; this is not a WAV-header-only test.
## godot --headless --path . --script res://tests/test_audio.gd -- --audio-test

var checks: int = 0
var failures: int = 0
var audio: Node
var progress: Node
var capture: AudioEffectCapture
var bus_index: int = -1

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("AUDIO_CHECK_FAILED: " + message)

func _measure(seconds: float = 0.4) -> Dictionary:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var count: int = capture.get_frames_available()
	var data: PackedVector2Array = capture.get_buffer(count)
	var power: float = 0.0
	var peak: float = 0.0
	for frame: Vector2 in data:
		power += frame.x * frame.x + frame.y * frame.y
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	var rms: float = sqrt(power / maxf(1.0, count * 2.0))
	return {"frames": count, "rms": rms, "peak": peak, "samples": data}

func _record(name: String, samples: PackedVector2Array) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/audio")
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(samples.size() * 4)
	for i: int in range(samples.size()):
		pcm.encode_s16(i * 4, roundi(clampf(samples[i].x, -1.0, 1.0) * 32767.0))
		pcm.encode_s16(i * 4 + 2, roundi(clampf(samples[i].y, -1.0, 1.0) * 32767.0))
	var wave: AudioStreamWAV = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.stereo = true
	wave.mix_rate = int(AudioServer.get_mix_rate())
	wave.data = pcm
	check(wave.save_to_wav("res://artifacts/audio/" + name + "_runtime.wav") == OK, "record actual " + name + " mixer output")

func _run() -> void:
	audio = root.get_node("Audio")
	progress = root.get_node("Progress")
	var original_settings: Dictionary = progress.settings.duplicate(true)
	var original_path: String = progress.save_path
	check(audio._music_players.size() == 2, "explicit audio test initializes both music players")
	if audio._music_players.is_empty():
		print("AUDIO_TESTS: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	bus_index = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "AudioVerification")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 8.0 if "--record-audio" in OS.get_cmdline_user_args() else 2.0
	AudioServer.add_bus_effect(bus_index, capture)
	for player: AudioStreamPlayer in audio._music_players + audio._effects_players:
		player.bus = "AudioVerification"
	audio._ambient.bus = "AudioVerification"
	progress.settings["music"] = 0.5
	progress.settings["sfx"] = 0.0
	audio.update_volumes()
	for context: String in ["hub", "mission", "boss"]:
		audio.set_context(context)
		await create_timer(1.0).timeout
		var player: AudioStreamPlayer = audio._music_players[audio._active_music]
		var stream: AudioStreamWAV = player.stream as AudioStreamWAV
		check(audio._context == context and player.playing, context + " selects and starts its own score")
		check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0, context + " has an explicit full-length loop")
		var meter: Dictionary = await _measure(6.0 if "--record-audio" in OS.get_cmdline_user_args() else 0.4)
		if "--record-audio" in OS.get_cmdline_user_args():
			_record(context, meter.samples)
		print("AUDIO_MIXER %s: %d frames, RMS %.2f dBFS, peak %.3f" % [context, meter.frames, linear_to_db(maxf(meter.rms, 0.000001)), meter.peak])
		check(meter.frames > 4000, context + " actually passes through AudioServer capture")
		check(meter.rms > 0.015 and meter.peak < 0.95, context + " is audible at default volume with headroom")
	check(audio._music_players[audio._active_music].stream.get_length() < 45.0, "boss uses the accelerated separate soundtrack")
	progress.settings["music"] = 0.8
	audio.update_volumes()
	var high_db: float = audio._music_players[audio._active_music].volume_db
	progress.settings["music"] = 0.2
	audio.update_volumes()
	check(is_equal_approx(high_db - audio._music_players[audio._active_music].volume_db, linear_to_db(4.0)), "saved music slider controls actual gain logarithmically")
	progress.settings["music"] = 0.0
	audio.update_volumes()
	await create_timer(0.15).timeout
	var silence: Dictionary = await _measure(0.2)
	check(audio._music_players[audio._active_music].stream_paused and silence.peak < 0.00001, "zero music volume truly pauses and silences playback")
	progress.settings["music"] = 0.5
	audio.update_volumes()
	paused = true
	await create_timer(0.25, true).timeout
	var paused_output: Dictionary = await _measure(0.2)
	check(paused_output.rms > 0.015, "music continues while gameplay is paused")
	paused = false
	progress.settings["music"] = 0.0
	progress.settings["sfx"] = 0.7
	audio.update_volumes()
	# Ambient is excluded so the assertion proves the action sound plays.
	audio._ambient.stream_paused = true
	capture.clear_buffer()
	audio.play_sfx("shoot")
	var effect: Dictionary = await _measure(0.15)
	check(effect.peak > 0.02, "action effects remain audible independently of muted music")
	progress.settings = original_settings
	audio.update_volumes()
	check(progress.save_path == original_path, "mixer tests preserve the user's save path and never write a profile")
	for player: AudioStreamPlayer in audio._music_players + audio._effects_players:
		player.stop()
		player.stream = null
		player.bus = "Master"
	audio._ambient.stop()
	audio._ambient.stream = null
	audio._ambient.bus = "Master"
	audio._cache.clear()
	# Let the audio thread release queued playback references before teardown.
	await create_timer(0.15).timeout
	AudioServer.remove_bus(bus_index)
	capture = null
	await process_frame
	print("AUDIO_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
