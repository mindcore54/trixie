extends Node
## Synthesizes procedural SFX in memory (pentatonic click escalation, coin pitch,
## cauldron sizzle, explosion, anime cut-in) and coordinates hitstop/screen-shake.

const SAMPLE_RATE: int = 22050
const PENTATONIC_FREQS: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.51]

var _sfx_players: Array[AudioStreamPlayer] = []
var _pentatonic_streams: Array[AudioStreamWAV] = []
var _coin_stream: AudioStreamWAV
var _cauldron_ready_stream: AudioStreamWAV
var _explosion_stream: AudioStreamWAV
var _cutin_stream: AudioStreamWAV
var _stir_stream: AudioStreamWAV
var _active_camera: Camera2D
var _shake_tween: Tween


func _ready() -> void:
	for i: int in range(10):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_sfx_players.append(player)

	for freq: float in PENTATONIC_FREQS:
		_pentatonic_streams.append(_synth_tone(freq, 0.11, "sine", 0.45))

	_coin_stream = _synth_arpeggio([880.0, 1174.66, 1567.98], 0.06, 0.45)
	_cauldron_ready_stream = _synth_arpeggio([659.25, 987.77], 0.08, 0.4)
	_stir_stream = _synth_tone(340.0, 0.14, "triangle", 0.35)
	_explosion_stream = _synth_noise_boom(0.38, 0.55)
	_cutin_stream = _synth_arpeggio([440.0, 659.25, 880.0, 1318.51], 0.055, 0.55)

	EventBus.action_queued.connect(_on_action_queued)
	EventBus.action_step_completed.connect(_on_action_step_completed)
	EventBus.cauldron_potion_ready.connect(_on_cauldron_potion_ready)
	EventBus.cauldron_exploded.connect(_on_cauldron_exploded)
	EventBus.customer_served.connect(_on_customer_served)
	EventBus.witch_ability_triggered.connect(_on_witch_ability_triggered)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func register_camera(cam: Camera2D) -> void:
	_active_camera = cam


func play_pentatonic(step_index: int, volume_offset_db: float = 0.0) -> void:
	if _pentatonic_streams.is_empty():
		return
	var idx: int = clampi(step_index, 0, _pentatonic_streams.size() - 1)
	_play_stream(_pentatonic_streams[idx], 1.0, volume_offset_db)


func play_stir() -> void:
	_play_stream(_stir_stream, randf_range(0.95, 1.12), -3.0)


func play_explosion(volume_offset_db: float = 2.0, pitch: float = 0.88) -> void:
	_play_stream(_explosion_stream, pitch, volume_offset_db)


func trigger_screen_shake(intensity: float = 10.0, duration: float = 0.25) -> void:
	if _active_camera == null or not is_instance_valid(_active_camera):
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: int = maxi(4, int(duration / 0.035))
	for i: int in range(steps):
		var decay: float = 1.0 - (float(i) / float(steps))
		var offset: Vector2 = Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay
		)
		_shake_tween.tween_property(_active_camera, "offset", offset, duration / float(steps))
	_shake_tween.tween_property(_active_camera, "offset", Vector2.ZERO, 0.04)


func trigger_hitstop(duration_sec: float = 0.045) -> void:
	if duration_sec <= 0.0:
		return
	Engine.time_scale = 0.08
	var timer: SceneTreeTimer = get_tree().create_timer(duration_sec, true, false, true)
	await timer.timeout
	Engine.time_scale = 1.0


func _on_action_queued(_station_id: StringName, queue_index: int, _world_pos: Vector2) -> void:
	play_pentatonic(queue_index, -4.0)


func _on_action_step_completed(_station_id: StringName, combo_pitch_step: int) -> void:
	play_pentatonic(combo_pitch_step, -2.0)


func _on_cauldron_potion_ready(_cauldron_id: int, _recipe_id: StringName, is_hot_bonus: bool) -> void:
	_play_stream(_cauldron_ready_stream, 1.15 if is_hot_bonus else 1.0, -3.0)


func _on_cauldron_exploded(_cauldron_id: int, _remaining_hearts: int) -> void:
	_play_stream(_explosion_stream, 1.0, 0.0)
	trigger_screen_shake(18.0, 0.35)
	trigger_hitstop(0.06)


func _on_customer_served(_customer_id: StringName, _gold_earned: int, tip_multiplier: float, _affinity: int) -> void:
	var pitch: float = clampf(0.95 + (tip_multiplier - 1.0) * 0.14, 0.95, 1.55)
	_play_stream(_coin_stream, pitch, -1.0)
	if tip_multiplier >= 1.5:
		trigger_hitstop(0.035)


func _on_witch_ability_triggered(_witch_id: StringName, _cutin: Texture2D) -> void:
	_play_stream(_cutin_stream, 1.0, 1.0)
	trigger_screen_shake(12.0, 0.25)


func _play_stream(stream: AudioStream, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if stream == null:
		return
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.volume_db = -8.0 + volume_offset_db
			player.play()
			return
	_sfx_players[0].stream = stream
	_sfx_players[0].pitch_scale = pitch
	_sfx_players[0].volume_db = -8.0 + volume_offset_db
	_sfx_players[0].play()


func _synth_tone(freq: float, duration: float, wave: String, gain: float) -> AudioStreamWAV:
	var count: int = maxi(1, int(SAMPLE_RATE * duration))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(count * 2)
	for i: int in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 14.0 / maxf(duration, 0.05))
		var phase: float = fmod(t * freq, 1.0)
		var sample_f: float = 0.0
		if wave == "triangle":
			sample_f = (4.0 * absf(phase - 0.5) - 1.0)
		else:
			sample_f = sin(TAU * freq * t)
		var s16: int = clampi(int(sample_f * env * gain * 32767.0), -32767, 32767)
		pcm[i * 2] = s16 & 0xFF
		pcm[i * 2 + 1] = (s16 >> 8) & 0xFF

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _synth_arpeggio(freqs: Array[float], note_dur: float, gain: float) -> AudioStreamWAV:
	var samples_per_note: int = maxi(1, int(SAMPLE_RATE * note_dur))
	var total: int = samples_per_note * freqs.size()
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(total * 2)
	for n: int in range(freqs.size()):
		var f: float = freqs[n]
		for i: int in range(samples_per_note):
			var t: float = float(i) / float(SAMPLE_RATE)
			var env: float = 1.0 - (float(i) / float(samples_per_note)) * 0.65
			var sample_f: float = sin(TAU * f * t)
			var idx: int = (n * samples_per_note + i) * 2
			var s16: int = clampi(int(sample_f * env * gain * 32767.0), -32767, 32767)
			pcm[idx] = s16 & 0xFF
			pcm[idx + 1] = (s16 >> 8) & 0xFF

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _synth_noise_boom(duration: float, gain: float) -> AudioStreamWAV:
	var count: int = maxi(1, int(SAMPLE_RATE * duration))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(count * 2)
	var lp: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 7.5)
		var noise: float = randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.18)
		var sub: float = sin(TAU * lerpf(110.0, 38.0, t / duration) * t)
		var sample_f: float = (lp * 0.6 + sub * 0.4) * env
		var s16: int = clampi(int(sample_f * gain * 32767.0), -32767, 32767)
		pcm[i * 2] = s16 & 0xFF
		pcm[i * 2 + 1] = (s16 >> 8) & 0xFF

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream
