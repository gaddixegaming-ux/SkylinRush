extends Node
## Fully synthesized audio: a 120 BPM synthwave loop plus all sound effects.
## Generated on a worker thread at startup, so no audio files are needed.

const RATE := 22050
const BPM := 120.0

var players: Array[AudioStreamPlayer] = []
var idx := 0
var sounds := {}
var music: AudioStreamPlayer
var music_on := true
var ready_audio := false
var _thread: Thread
var _t := 0.0
var _lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -9.0
	add_child(music)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 1400.0
	AudioServer.add_bus_effect(0, _lowpass)
	AudioServer.set_bus_effect_enabled(0, AudioServer.get_bus_effect_count(0) - 1, false)
	_thread = Thread.new()
	_thread.start(_generate)


func _process(delta: float) -> void:
	_t += delta
	if _thread and not _thread.is_alive():
		var data: Dictionary = _thread.wait_to_finish()
		_thread = null
		for k in data:
			if k == "music":
				continue
			sounds[k] = _wav(data[k], false)
		music.stream = _wav(data["music"], true)
		if music_on:
			music.play()
		ready_audio = true


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()


func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not sounds.has(name):
		return
	var p := players[idx]
	idx = (idx + 1) % players.size()
	p.stream = sounds[name]
	p.pitch_scale = pitch
	p.volume_db = -4.0 + vol_db
	p.play()


func beat_phase() -> float:
	if music.playing:
		return music.get_playback_position() * BPM / 60.0
	return _t * BPM / 60.0


func toggle_music() -> void:
	music_on = not music_on
	if music.stream == null:
		return
	if music_on:
		music.play()
	else:
		music.stop()


func set_warp(on: bool) -> void:
	music.pitch_scale = 0.8 if on else 1.0
	AudioServer.set_bus_effect_enabled(0, AudioServer.get_bus_effect_count(0) - 1, on)


func set_muffled(on: bool) -> void:
	music.pitch_scale = 0.75 if on else 1.0
	AudioServer.set_bus_effect_enabled(0, AudioServer.get_bus_effect_count(0) - 1, on)


func _wav(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size() / 2
	return w


# ============================================================ synthesis (thread)
func _generate() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var d := {}
	d["coin"] = _coin(rng)
	d["jump"] = _synth(rng, 0.18, 260, 640, 1, 14, 0.0, 0.22)
	d["djump"] = _synth(rng, 0.25, 420, 1300, 3, 9, 0.0, 0.4)
	d["land"] = _synth(rng, 0.14, 150, 50, 0, 22, 0.35, 0.7)
	d["slide"] = _synth(rng, 0.3, 900, 300, 0, 8, 0.9, 0.35)
	d["dash"] = _synth(rng, 0.45, 200, 1500, 2, 5, 0.6, 0.35)
	d["shield"] = _synth(rng, 0.45, 500, 1000, 3, 6, 0.0, 0.4)
	d["magnet"] = _synth(rng, 0.35, 300, 700, 1, 7, 0.0, 0.2)
	d["warp"] = _synth(rng, 0.7, 1000, 160, 0, 3, 0.1, 0.45)
	d["shock"] = _synth(rng, 0.9, 110, 28, 0, 3.5, 0.55, 1.0)
	d["hover"] = _synth(rng, 0.45, 280, 560, 2, 5, 0.3, 0.3)
	d["overdrive"] = _synth(rng, 1.0, 220, 990, 2, 2.6, 0.2, 0.4)
	d["portal"] = _synth(rng, 0.8, 400, 1900, 3, 3.5, 0.15, 0.45)
	d["crash"] = _synth(rng, 0.7, 130, 32, 0, 5, 0.7, 1.0)
	d["smash"] = _synth(rng, 0.3, 220, 60, 0, 11, 0.8, 0.8)
	d["stumble"] = _synth(rng, 0.28, 200, 110, 1, 9, 0.2, 0.35)
	d["close"] = _synth(rng, 0.22, 900, 1700, 3, 11, 0.0, 0.4)
	d["deny"] = _synth(rng, 0.14, 160, 150, 1, 14, 0.0, 0.22)
	d["ready"] = _synth(rng, 0.16, 1300, 1700, 0, 16, 0.0, 0.25)
	d["click"] = _synth(rng, 0.05, 1100, 800, 0, 60, 0.0, 0.35)
	d["shield_break"] = _synth(rng, 0.45, 1600, 250, 3, 7, 0.5, 0.5)
	d["orb"] = _synth(rng, 0.35, 700, 1500, 0, 7, 0.0, 0.45)
	d["airdash"] = _synth(rng, 0.3, 350, 1700, 2, 7, 0.65, 0.35)
	d["wall"] = _synth(rng, 0.45, 260, 820, 1, 4, 0.5, 0.28)
	d["grapple"] = _synth(rng, 0.3, 2200, 500, 2, 7, 0.35, 0.35)
	d["phase"] = _synth(rng, 0.55, 1100, 2600, 3, 4, 0.25, 0.35)
	d["music"] = _music(rng)
	return d


func _encode(arr: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(arr.size() * 2)
	for i in arr.size():
		out.encode_s16(i * 2, int(clampf(arr[i], -1.0, 1.0) * 30000.0))
	return out


## wave: 0 sine, 1 square, 2 saw, 3 triangle
func _synth(rng: RandomNumberGenerator, dur: float, f0: float, f1: float, wave: int, decay: float, noise_amt: float, vol: float) -> PackedByteArray:
	var n := int(RATE * dur)
	var arr := PackedFloat32Array()
	arr.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := f0 * pow(f1 / f0, k)
		phase += f / RATE
		var ph := fposmod(phase, 1.0)
		var v := 0.0
		match wave:
			0: v = sin(TAU * phase)
			1: v = 1.0 if ph < 0.5 else -1.0
			2: v = 2.0 * ph - 1.0
			3: v = 4.0 * absf(ph - 0.5) - 1.0
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		v = v * (1.0 - noise_amt) + lp * noise_amt * 1.6
		var env := exp(-t * decay) * minf(1.0, t * 300.0) * minf(1.0, (dur - t) * 60.0)
		arr[i] = v * env * vol
	return _encode(arr)


func _coin(_rng: RandomNumberGenerator) -> PackedByteArray:
	var dur := 0.22
	var n := int(RATE * dur)
	var arr := PackedFloat32Array()
	arr.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1318.5 if t < 0.055 else 1975.5
		var tt := t if t < 0.055 else t - 0.055
		var v := sin(TAU * f * t) * 0.7 + (1.0 if fmod(f * t, 1.0) < 0.5 else -1.0) * 0.12
		arr[i] = v * exp(-tt * 18.0) * minf(1.0, t * 400.0) * 0.4
	return _encode(arr)


func _music(rng: RandomNumberGenerator) -> PackedByteArray:
	var spb := 60.0 / BPM
	var beats := 16
	var n := int(RATE * spb * beats)
	var arr := PackedFloat32Array()
	arr.resize(n)
	# Am - F - C - G
	var roots := [110.0, 87.31, 130.81, 98.0]
	var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
	var hp_prev := 0.0
	var bass_lp := 0.0
	var bass_phase := 0.0
	var bar_len := spb * 4.0
	for i in n:
		var t := float(i) / RATE
		var bi := int(t / spb)
		var tb := t - bi * spb
		var bar := int(bi / 4) % 4
		var ei := int(t / (spb * 0.5))
		var te := t - ei * spb * 0.5
		var si := int(t / (spb * 0.25))
		var ts := t - si * spb * 0.25
		var s := 0.0
		var duck := 1.0 - 0.55 * exp(-tb * 7.0)
		# kick
		if tb < 0.35:
			var ph := 45.0 * tb + 90.0 * (1.0 - exp(-tb * 30.0)) / 30.0
			s += sin(TAU * ph) * exp(-tb * 8.0) * 0.6
		# snare on 2 & 4
		var nz := rng.randf_range(-1.0, 1.0)
		if bi % 2 == 1 and tb < 0.3:
			s += nz * exp(-tb * 18.0) * 0.22 + sin(TAU * 190.0 * tb) * exp(-tb * 25.0) * 0.15
		# hats on off-beats
		var hp := nz - hp_prev
		hp_prev = nz
		if ei % 2 == 1:
			s += hp * exp(-te * 50.0) * 0.07
		else:
			s += hp * exp(-te * 120.0) * 0.03
		# bass (octave-bouncing saw, low-passed)
		var root: float = roots[bar]
		var bf := root if ei % 2 == 0 else root * 2.0
		bass_phase += bf / RATE
		var saw := 2.0 * fposmod(bass_phase, 1.0) - 1.0
		bass_lp += (saw - bass_lp) * 0.16
		s += bass_lp * (0.3 * exp(-te * 5.0) + 0.1) * duck * 0.9
		# pad
		var tbar := fmod(t, bar_len)
		var penv := minf(1.0, tbar * 6.0) * minf(1.0, (bar_len - tbar) * 6.0)
		var pad := 0.0
		var ch: Array = chords[bar]
		for f in ch:
			pad += sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.003 * t)
		s += pad * 0.035 * penv * duck
		# arpeggio (16ths)
		var af: float = ch[si % 3] * (2.0 if (si / 3) % 2 == 0 else 4.0)
		var av := sin(TAU * af * t) * 0.6 + (1.0 if fmod(af * t, 1.0) < 0.5 else -1.0) * 0.12
		s += av * exp(-ts * 16.0) * 0.06
		arr[i] = s * 0.85
	return _encode(arr)
