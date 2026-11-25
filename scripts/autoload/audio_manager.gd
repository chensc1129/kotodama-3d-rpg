extends Node
## Procedural polyphonic SFX synthesizer (replacing Tone.js) and Japanese TTS helper.

signal audio_toggled(enabled: bool)

const SAMPLE_RATE: float = 22050.0

var audio_enabled: bool = true
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array = [] # Each voice: {freq, phase, time, duration, delay, amp, wave}

const NOTE_FREQ: Dictionary = {
	"F2": 87.31,
	"C3": 130.81,
	"A4": 440.00,
	"C5": 523.25,
	"E5": 659.25,
	"G5": 783.99,
	"A5": 880.00,
	"B5": 987.77,
	"C6": 1046.50,
	"C#6": 1108.73,
	"D6": 1174.66,
	"E6": 1318.51,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.12
	_player.stream = stream
	_player.volume_db = -8.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func toggle_audio() -> bool:
	audio_enabled = not audio_enabled
	audio_toggled.emit(audio_enabled)
	GameState.toast_requested.emit("🔊 戰鬥音效已開啟" if audio_enabled else "🔇 戰鬥音效已靜音")
	return audio_enabled


func play_sfx(sfx_type: String) -> void:
	if not audio_enabled:
		return
	match sfx_type:
		"slash1":
			_trigger_chord(["E5", "B5"], 0.085, 0.0, "tri", 0.22)
			_trigger_noise(0.065, 0.0, 0.14, 12.0)
		"slash2":
			_trigger_chord(["G5", "D6"], 0.085, 0.0, "tri", 0.24)
			_trigger_noise(0.070, 0.0, 0.16, 11.0)
		"slash3":
			_trigger_chord(["C5", "G5", "E6"], 0.16, 0.0, "tri", 0.28)
			_trigger_noise(0.11, 0.0, 0.20, 8.5)
		# === 5 Heroes Exclusive Attack SFX ===
		"atk_sakura_1":
			_trigger_chord(["A5", "E6"], 0.095, 0.0, "sine", 0.20)
			_trigger_noise(0.06, 0.0, 0.10, 14.0)
		"atk_sakura_2":
			_trigger_chord(["B5", "E6"], 0.10, 0.0, "sine", 0.22)
			_trigger_noise(0.07, 0.0, 0.12, 13.0)
		"atk_sakura_3":
			_trigger_chord(["E5", "A5", "B5", "E6"], 0.22, 0.0, "sine", 0.28)
			_trigger_noise(0.12, 0.0, 0.15, 9.5)
		"atk_kick_1":
			_trigger_punch(220.0, 58.0, 0.11, 0.0, 0.34, "sine")
			_trigger_noise(0.09, 0.0, 0.22, 10.5)
		"atk_kick_2":
			_trigger_punch(250.0, 52.0, 0.13, 0.0, 0.38, "sine")
			_trigger_noise(0.10, 0.0, 0.25, 9.5)
		"atk_kick_3":
			_trigger_punch(310.0, 42.0, 0.20, 0.0, 0.48, "sine")
			_trigger_punch(180.0, 65.0, 0.12, 0.02, 0.22, "square")
			_trigger_noise(0.16, 0.0, 0.32, 7.5)
		"atk_sword_1":
			_trigger_punch(640.0, 220.0, 0.09, 0.0, 0.22, "tri")
			_trigger_noise(0.085, 0.0, 0.20, 11.0)
		"atk_sword_2":
			_trigger_punch(740.0, 260.0, 0.10, 0.0, 0.24, "tri")
			_trigger_noise(0.095, 0.0, 0.22, 10.0)
		"atk_sword_3":
			_trigger_punch(920.0, 180.0, 0.16, 0.0, 0.30, "tri")
			_trigger_punch(190.0, 48.0, 0.18, 0.01, 0.34, "sine")
			_trigger_noise(0.15, 0.0, 0.28, 7.5)
		"atk_raijin_1":
			_trigger_punch(1180.0, 460.0, 0.055, 0.0, 0.20, "square")
			_trigger_noise(0.045, 0.0, 0.18, 18.0)
		"atk_raijin_2":
			_trigger_punch(1380.0, 540.0, 0.060, 0.0, 0.22, "square")
			_trigger_noise(0.050, 0.0, 0.20, 17.0)
		"atk_raijin_3":
			_trigger_punch(1650.0, 340.0, 0.12, 0.0, 0.26, "square")
			_trigger_chord(["G5", "D6", "E6"], 0.14, 0.01, "tri", 0.24)
			_trigger_noise(0.095, 0.0, 0.26, 12.0)
		"atk_yuki_1":
			_trigger_chord(["C6", "E6"], 0.11, 0.0, "sine", 0.22)
			_trigger_punch(1450.0, 880.0, 0.08, 0.0, 0.14, "sine")
		"atk_yuki_2":
			_trigger_chord(["D6", "E6"], 0.12, 0.0, "sine", 0.24)
			_trigger_punch(1620.0, 960.0, 0.09, 0.0, 0.16, "sine")
		"atk_yuki_3":
			_trigger_chord(["G5", "C6", "D6", "E6"], 0.24, 0.0, "sine", 0.30)
			_trigger_noise(0.11, 0.02, 0.18, 12.0)
		"impact_light":
			_trigger_punch(135.0, 52.0, 0.095, 0.0, 0.34, "sine")
			_trigger_noise(0.060, 0.0, 0.24, 15.0)
		"impact_heavy":
			_trigger_punch(155.0, 42.0, 0.15, 0.0, 0.44, "sine")
			_trigger_punch(320.0, 95.0, 0.09, 0.0, 0.22, "square")
			_trigger_noise(0.10, 0.0, 0.32, 11.0)
		"impact_crit":
			_trigger_punch(175.0, 38.0, 0.22, 0.0, 0.50, "sine")
			_trigger_punch(420.0, 110.0, 0.12, 0.0, 0.26, "square")
			_trigger_noise(0.14, 0.0, 0.36, 9.0)
			_trigger_chord(["G5", "D6", "E6"], 0.24, 0.015, "tri", 0.24)
		"enemy_die":
			_trigger_punch(210.0, 65.0, 0.16, 0.0, 0.30, "sine")
			_trigger_noise(0.12, 0.0, 0.22, 9.5)
			_trigger_chord(["C6", "E6"], 0.16, 0.02, "sine", 0.16)
		"boss_die":
			_trigger_punch(140.0, 32.0, 0.42, 0.0, 0.52, "sine")
			_trigger_noise(0.30, 0.0, 0.32, 5.5)
			_trigger_chord(["C5", "G5", "C6", "E6"], 0.45, 0.06, "tri", 0.30)
		"skill":
			_trigger_chord(["A4", "E5", "A5", "C#6"], 0.30, 0.0, "sine", 0.26)
			_trigger_punch(160.0, 48.0, 0.18, 0.0, 0.32, "sine")
		"dash":
			_trigger_chord(["C6"], 0.09, 0.0, "sine", 0.22)
			_trigger_punch(240.0, 95.0, 0.11, 0.0, 0.20, "sine")
			_trigger_noise(0.11, 0.0, 0.18, 9.0)
		"jump":
			_trigger_punch(220.0, 520.0, 0.11, 0.0, 0.22, "sine")
			_trigger_noise(0.06, 0.0, 0.10, 14.0)
		"land":
			_trigger_punch(95.0, 42.0, 0.075, 0.0, 0.18, "sine")
			_trigger_noise(0.045, 0.0, 0.09, 16.0)
		"hit":
			_trigger_punch(120.0, 44.0, 0.18, 0.0, 0.42, "square")
			_trigger_noise(0.10, 0.0, 0.26, 12.0)
		"levelup":
			_trigger_chord(["C5", "E5", "G5"], 0.14, 0.0, "tri", 0.26)
			_trigger_chord(["G5", "B5", "D6"], 0.28, 0.14, "tri", 0.28)


func speak_japanese(text: String) -> void:
	if not audio_enabled or text.is_empty():
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices := DisplayServer.tts_get_voices_for_language("ja")
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voices[0], 60, 1.0, 1.05)


func _trigger_chord(notes: Array, duration: float, delay: float, wave: String, total_amp: float = 0.24) -> void:
	var amp := total_amp / maxf(1.0, float(notes.size()))
	for note in notes:
		var freq: float = float(NOTE_FREQ.get(note, 440.0))
		_voices.append({
			"freq": freq,
			"freq_end": freq,
			"phase": 0.0,
			"time": -delay,
			"duration": duration,
			"amp": amp,
			"wave": wave,
			"decay": 4.2,
		})


func _trigger_punch(freq_start: float, freq_end: float, duration: float, delay: float, amp: float, wave: String) -> void:
	_voices.append({
		"freq": freq_start,
		"freq_end": freq_end,
		"phase": 0.0,
		"time": -delay,
		"duration": duration,
		"amp": amp,
		"wave": wave,
		"decay": 5.8,
	})


func _trigger_noise(duration: float, delay: float, amp: float, decay: float = 10.0) -> void:
	_voices.append({
		"freq": 0.0,
		"freq_end": 0.0,
		"phase": 0.0,
		"time": -delay,
		"duration": duration,
		"amp": amp,
		"wave": "noise",
		"decay": decay,
	})


func _process(_delta: float) -> void:
	if _playback == null:
		if _player != null and _player.playing:
			_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
		return

	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return

	var dt := 1.0 / SAMPLE_RATE
	for _i in range(frames_available):
		var sample := 0.0
		if not _voices.is_empty():
			var idx := _voices.size() - 1
			while idx >= 0:
				var v: Dictionary = _voices[idx]
				v["time"] = float(v["time"]) + dt
				var t: float = float(v["time"])
				var dur: float = float(v["duration"])
				if t >= dur:
					_voices.remove_at(idx)
				elif t >= 0.0:
					var progress: float = t / dur
					var decay: float = float(v.get("decay", 4.2))
					var env: float = minf(1.0, t / 0.004) * exp(-progress * decay)
					var osc := 0.0
					if v["wave"] == "noise":
						osc = randf_range(-1.0, 1.0)
					else:
						var cur_freq: float = lerpf(float(v["freq"]), float(v.get("freq_end", v["freq"])), progress)
						var phase: float = float(v["phase"]) + cur_freq * dt
						if phase >= 1.0:
							phase -= floor(phase)
						v["phase"] = phase
						if v["wave"] == "tri":
							osc = 4.0 * absf(phase - 0.5) - 1.0
						elif v["wave"] == "square":
							osc = 0.65 if phase < 0.5 else -0.65
						else:
							osc = sin(phase * TAU)
					sample += osc * env * float(v["amp"])
				idx -= 1
		sample = clampf(sample, -0.92, 0.92)
		_playback.push_frame(Vector2(sample, sample))
