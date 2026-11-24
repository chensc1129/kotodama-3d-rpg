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
			_trigger_chord(["E5", "B5"], 0.09, 0.0, "tri")
		"slash2":
			_trigger_chord(["G5", "D6"], 0.09, 0.0, "tri")
		"slash3":
			_trigger_chord(["C5", "G5", "E6"], 0.16, 0.0, "tri")
		"skill":
			_trigger_chord(["A4", "E5", "A5", "C#6"], 0.30, 0.0, "sine")
		"dash":
			_trigger_chord(["C6"], 0.08, 0.0, "sine")
		"hit":
			_trigger_chord(["F2", "C3"], 0.16, 0.0, "square")
		"levelup":
			_trigger_chord(["C5", "E5", "G5"], 0.14, 0.0, "tri")
			_trigger_chord(["G5", "B5", "D6"], 0.28, 0.14, "tri")


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


func _trigger_chord(notes: Array, duration: float, delay: float, wave: String) -> void:
	var amp := 0.24 / maxf(1.0, float(notes.size()))
	for note in notes:
		var freq: float = float(NOTE_FREQ.get(note, 440.0))
		_voices.append({
			"freq": freq,
			"phase": 0.0,
			"time": -delay,
			"duration": duration,
			"amp": amp,
			"wave": wave,
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
				if t >= float(v["duration"]):
					_voices.remove_at(idx)
				elif t >= 0.0:
					var progress: float = t / float(v["duration"])
					var env: float = minf(1.0, t / 0.008) * exp(-progress * 4.2)
					var phase: float = float(v["phase"]) + float(v["freq"]) * dt
					if phase >= 1.0:
						phase -= floor(phase)
					v["phase"] = phase
					var osc := 0.0
					if v["wave"] == "tri":
						osc = 4.0 * absf(phase - 0.5) - 1.0
					elif v["wave"] == "square":
						osc = 0.65 if phase < 0.5 else -0.65
					else:
						osc = sin(phase * TAU)
					sample += osc * env * float(v["amp"])
				idx -= 1
		sample = clampf(sample, -0.9, 0.9)
		_playback.push_frame(Vector2(sample, sample))
