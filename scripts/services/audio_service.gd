extends Node
## Restrained, original sound palette synthesised at runtime (no third-party
## audio assets, so no licensing obligations). Separate toggles for sound
## effects, music and haptics. Audio stops when the app loses focus.

const MIX_RATE := 22050
const SOUNDS := ["tick", "run", "success", "error"]

var _streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next := 0
var _focused := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	SaveService.settings_changed.connect(_on_setting)
	_apply_volume()
	call_deferred("_update_music")


func stream(name: String) -> AudioStreamWAV:
	if not _streams.has(name):
		_streams[name] = _build(name)
	return _streams[name]


func play(name: String) -> void:
	if not bool(SaveService.get_setting("sfx")) or not _focused or not name in SOUNDS:
		return
	var p := _sfx_players[_next]
	_next = (_next + 1) % _sfx_players.size()
	p.stream = stream(name)
	p.play()


func haptic(ms := 15) -> void:
	if bool(SaveService.get_setting("haptics")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, 0.4)


func _on_setting(key: String, _value) -> void:
	if key == "music":
		_update_music()
	elif key == "volume":
		_apply_volume()


func _apply_volume() -> void:
	var v := clampf(float(SaveService.get_setting("volume")), 0.0, 1.0)
	var db := linear_to_db(maxf(v, 0.001))
	for p in _sfx_players:
		p.volume_db = db
	_music.volume_db = db - 14.0


func _update_music() -> void:
	var want := bool(SaveService.get_setting("music")) and _focused
	if want and not _music.playing:
		_music.stream = stream("ambient")
		_music.play()
	elif not want and _music.playing:
		_music.stop()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_focused = false
			for p in _sfx_players:
				p.stop()
			_update_music()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_focused = true
			_update_music()


# ---- Synthesis --------------------------------------------------------------

func _build(name: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	match name:
		"tick":
			samples = _tone(1320.0, 0.045, 0.25, 0.002, 0.04)
		"run":
			samples = _sweep(330.0, 660.0, 0.22, 0.22)
		"success":
			samples = _concat([_tone(523.25, 0.12, 0.22, 0.005, 0.1),
				_tone(659.25, 0.12, 0.22, 0.005, 0.1), _tone(783.99, 0.3, 0.22, 0.005, 0.28)])
		"error":
			samples = _tone(220.0, 0.16, 0.18, 0.01, 0.14)
		"ambient":
			samples = _pad(8.0)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = bytes
	if name == "ambient":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


static func _tone(freq: float, dur: float, amp: float, attack: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(t / attack, 1.0) * exp(-maxf(t - attack, 0.0) / maxf(decay, 0.001) * 3.0)
		out[i] = amp * env * (sin(TAU * freq * t) + 0.2 * sin(TAU * freq * 2.0 * t))
	return out


static func _sweep(f0: float, f1: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k) / MIX_RATE
		out[i] = amp * sin(phase) * sin(PI * k)
	return out


static func _pad(dur: float) -> PackedFloat32Array:
	# Soft sustained chord (A3, C#4, E4) with slow swell; loops seamlessly
	# because every partial completes whole cycles over the loop length.
	var n := int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var freqs := [220.0, 277.0, 330.0]
	for i in n:
		var t := float(i) / MIX_RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t)
		out[i] = 0.08 * v * (0.75 + 0.25 * sin(TAU * t / dur))
	return out


static func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out
