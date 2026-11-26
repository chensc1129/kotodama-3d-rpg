extends Node
## Low-latency, zero-crackle WebAudio-safe SFX synthesizer & Japanese TTS voice controller.
## Pre-bakes procedural 44.1kHz 16-bit PCM AudioStreamWAV clips once at startup with soft
## tanh limiting & smooth zero-crossing envelopes, played via a pooled AudioStreamPlayer bank
## with per-SFX debounce and a Master bus AudioEffectLimiter (eliminates mobile Chrome audio
## worklet underruns, hard-clipping bursts, and 200ms generator ring-buffer lag).

signal audio_toggled(enabled: bool)

const SAMPLE_RATE: int = 44100
const POOL_SIZE: int = 10

var audio_enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _sfx_bank: Dictionary = {} # sfx_name -> AudioStreamWAV
var _last_play_ms: Dictionary = {} # sfx_name -> int (Time.get_ticks_msec)
var _ja_voice_id: String = ""
var _tts_checked: bool = false

# Minimum ms between retriggers of the same SFX (prevents AoE multi-kill stacking & clipping)
const SFX_COOLDOWN_MS: Dictionary = {
	"enemy_die": 70,
	"boss_die": 120,
	"impact_light": 45,
	"impact_heavy": 55,
	"impact_crit": 65,
	"hit": 80,
	"dash": 70,
	"jump": 80,
	"land": 90,
	"levelup": 140,
	"step_stone": 140,
	"step_grass": 150,
	"step_sand": 150,
	"water_step": 160,
	"water_splash": 180,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_master_limiter()

	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer_%d" % i
		p.bus = "Master"
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)

	_bake_all_sfx()
	call_deferred("_cache_tts_voice")


func _setup_master_limiter() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	var has_limiter := false
	for i in range(AudioServer.get_bus_effect_count(master_idx)):
		if AudioServer.get_bus_effect(master_idx, i) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.5
		lim.threshold_db = -3.5
		lim.soft_clip_db = 2.0
		lim.soft_clip_ratio = 8.0
		AudioServer.add_bus_effect(master_idx, lim)


func _cache_tts_voice() -> void:
	if _tts_checked:
		return
	_tts_checked = true
	var voices := DisplayServer.tts_get_voices_for_language("ja")
	if not voices.is_empty():
		_ja_voice_id = String(voices[0])


func toggle_audio() -> bool:
	audio_enabled = not audio_enabled
	if not audio_enabled:
		for p in _players:
			if p.playing:
				p.stop()
		if DisplayServer.tts_is_speaking():
			DisplayServer.tts_stop()
	audio_toggled.emit(audio_enabled)
	return audio_enabled


func play_sfx(sfx_name: String) -> void:
	if not audio_enabled:
		return
	var stream: AudioStreamWAV = _sfx_bank.get(sfx_name, null)
	if stream == null:
		return

	var now_ms := Time.get_ticks_msec()
	var cd_ms: int = int(SFX_COOLDOWN_MS.get(sfx_name, 30))
	var prev_ms: int = int(_last_play_ms.get(sfx_name, -9999))
	if now_ms - prev_ms < cd_ms:
		return
	_last_play_ms[sfx_name] = now_ms

	# Pick first idle player, otherwise round-robin steal the oldest slot
	var chosen: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		chosen = _players[_pool_cursor]
		_pool_cursor = (_pool_cursor + 1) % POOL_SIZE

	chosen.stream = stream
	if sfx_name.begins_with("atk_") or sfx_name.begins_with("impact_"):
		chosen.pitch_scale = randf_range(0.97, 1.03)
	elif sfx_name.begins_with("step_") or sfx_name.begins_with("water_"):
		chosen.pitch_scale = randf_range(0.94, 1.06)
	else:
		chosen.pitch_scale = 1.0
	chosen.play()


func speak_japanese(text: String) -> void:
	if not audio_enabled or text.is_empty():
		return
	if not _tts_checked:
		_cache_tts_voice()
	if _ja_voice_id.is_empty():
		return
	# Defer slightly on Web so Android Chrome AudioFocus transition doesn't pop skill impact transients
	if OS.has_feature("web"):
		var tw := create_tween()
		tw.tween_interval(0.06)
		tw.tween_callback(func() -> void:
			if not audio_enabled:
				return
			if DisplayServer.tts_is_speaking():
				DisplayServer.tts_stop()
			DisplayServer.tts_speak(text, _ja_voice_id, 68, 1.04, 1.08)
		)
	else:
		if DisplayServer.tts_is_speaking():
			DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, _ja_voice_id, 72, 1.05, 1.08)


# ==============================================================================
#  OFFLINE PRE-BAKING OF CLEAN 44.1kHz 16-BIT PCM WAV CLIPS (ZERO RUNTIME CPU!)
# ==============================================================================
func _bake_all_sfx() -> void:
	_sfx_bank["slash1"] = _bake_voices([
		_v("tri", 520.0, 210.0, 0.13, 0.28),
		_v("noise", 1200.0, 420.0, 0.08, 0.11),
	])
	_sfx_bank["slash2"] = _bake_voices([
		_v("tri", 620.0, 250.0, 0.14, 0.30),
		_v("noise", 1600.0, 500.0, 0.09, 0.12),
	])
	_sfx_bank["slash3"] = _bake_voices([
		_v("tri", 760.0, 180.0, 0.22, 0.34),
		_v("sine", 240.0, 75.0, 0.20, 0.30),
		_v("noise", 2200.0, 400.0, 0.14, 0.15),
	])

	# === Per-Hero Exclusive Attack Sound Signatures ===
	_sfx_bank["atk_sakura_1"] = _bake_voices([
		_v("sine", 780.0, 420.0, 0.12, 0.24),
		_v("tri", 1320.0, 960.0, 0.10, 0.15),
		_v("noise", 2400.0, 1200.0, 0.07, 0.08),
	])
	_sfx_bank["atk_sakura_2"] = _bake_voices([
		_v("sine", 920.0, 480.0, 0.13, 0.26),
		_v("tri", 1560.0, 1080.0, 0.11, 0.16),
		_v("noise", 2600.0, 1100.0, 0.08, 0.09),
	])
	_sfx_bank["atk_sakura_3"] = _bake_voices([
		_v("sine", 1180.0, 580.0, 0.22, 0.28),
		_v("tri", 1760.0, 1180.0, 0.20, 0.20),
		_v("sine", 340.0, 150.0, 0.18, 0.22),
		_v("noise", 3000.0, 900.0, 0.14, 0.11),
	])

	_sfx_bank["atk_kick_1"] = _bake_voices([
		_v("sine", 210.0, 62.0, 0.15, 0.38),
		_v("noise", 720.0, 180.0, 0.11, 0.18),
	])
	_sfx_bank["atk_kick_2"] = _bake_voices([
		_v("sine", 245.0, 55.0, 0.17, 0.40),
		_v("tri", 360.0, 110.0, 0.13, 0.16),
		_v("noise", 900.0, 200.0, 0.12, 0.19),
	])
	_sfx_bank["atk_kick_3"] = _bake_voices([
		_v("sine", 280.0, 46.0, 0.26, 0.42),
		_v("tri", 175.0, 52.0, 0.20, 0.20),
		_v("noise", 1400.0, 160.0, 0.20, 0.22),
	])

	_sfx_bank["atk_sword_1"] = _bake_voices([
		_v("tri", 980.0, 320.0, 0.15, 0.26),
		_v("sine", 1680.0, 820.0, 0.12, 0.16),
		_v("noise", 1100.0, 320.0, 0.12, 0.14),
	])
	_sfx_bank["atk_sword_2"] = _bake_voices([
		_v("tri", 1120.0, 290.0, 0.16, 0.28),
		_v("sine", 1840.0, 740.0, 0.13, 0.18),
		_v("noise", 1400.0, 360.0, 0.14, 0.16),
	])
	_sfx_bank["atk_sword_3"] = _bake_voices([
		_v("tri", 1360.0, 220.0, 0.26, 0.30),
		_v("sine", 280.0, 72.0, 0.24, 0.30),
		_v("noise", 2200.0, 260.0, 0.22, 0.20),
	])

	_sfx_bank["atk_raijin_1"] = _bake_voices([
		_v("tri", 1040.0, 560.0, 0.08, 0.22),
		_v("sine", 1720.0, 920.0, 0.07, 0.16),
		_v("noise", 3200.0, 1500.0, 0.06, 0.10),
	])
	_sfx_bank["atk_raijin_2"] = _bake_voices([
		_v("tri", 1220.0, 620.0, 0.085, 0.24),
		_v("sine", 1920.0, 1020.0, 0.075, 0.16),
		_v("noise", 3400.0, 1600.0, 0.065, 0.11),
	])
	_sfx_bank["atk_raijin_3"] = _bake_voices([
		_v("tri", 1480.0, 320.0, 0.19, 0.24),
		_v("sine", 420.0, 92.0, 0.18, 0.30),
		_v("noise", 3800.0, 720.0, 0.15, 0.16),
	])

	_sfx_bank["atk_yuki_1"] = _bake_voices([
		_v("sine", 1380.0, 1860.0, 0.14, 0.22),
		_v("tri", 1940.0, 1540.0, 0.11, 0.14),
		_v("noise", 3000.0, 2100.0, 0.08, 0.07),
	])
	_sfx_bank["atk_yuki_2"] = _bake_voices([
		_v("sine", 1560.0, 2080.0, 0.15, 0.24),
		_v("tri", 2180.0, 1680.0, 0.12, 0.15),
		_v("noise", 3200.0, 2200.0, 0.09, 0.08),
	])
	_sfx_bank["atk_yuki_3"] = _bake_voices([
		_v("sine", 1740.0, 2420.0, 0.24, 0.24),
		_v("sine", 1140.0, 820.0, 0.22, 0.20),
		_v("tri", 620.0, 240.0, 0.20, 0.16),
		_v("noise", 3600.0, 1200.0, 0.15, 0.10),
	])

	# === Crisp Impact, Death, Movement & UI SFX ===
	_sfx_bank["impact_light"] = _bake_voices([
		_v("sine", 260.0, 88.0, 0.09, 0.34),
		_v("noise", 1700.0, 560.0, 0.055, 0.16),
	])
	_sfx_bank["impact_heavy"] = _bake_voices([
		_v("sine", 210.0, 54.0, 0.15, 0.40),
		_v("tri", 420.0, 120.0, 0.11, 0.20),
		_v("noise", 2000.0, 340.0, 0.09, 0.20),
	])
	_sfx_bank["impact_crit"] = _bake_voices([
		_v("sine", 240.0, 48.0, 0.22, 0.40),
		_v("tri", 940.0, 460.0, 0.16, 0.20),
		_v("sine", 1380.0, 920.0, 0.24, 0.22),
		_v("noise", 2600.0, 440.0, 0.13, 0.16),
	])
	_sfx_bank["enemy_die"] = _bake_voices([
		_v("sine", 340.0, 95.0, 0.17, 0.32),
		_v("tri", 620.0, 180.0, 0.13, 0.18),
		_v("noise", 1600.0, 320.0, 0.11, 0.14),
	])
	_sfx_bank["boss_die"] = _bake_voices([
		_v("sine", 180.0, 38.0, 0.46, 0.42),
		_v("tri", 420.0, 85.0, 0.34, 0.24),
		_v("noise", 1200.0, 160.0, 0.30, 0.20),
	])
	_sfx_bank["skill"] = _bake_voices([
		_v("sine", 380.0, 860.0, 0.30, 0.28),
		_v("tri", 580.0, 1140.0, 0.26, 0.20),
	])
	_sfx_bank["hit"] = _bake_voices([
		_v("tri", 165.0, 58.0, 0.14, 0.34),
		_v("noise", 800.0, 200.0, 0.09, 0.16),
	])
	_sfx_bank["dash"] = _bake_voices([
		_v("sine", 340.0, 740.0, 0.12, 0.24),
		_v("noise", 1800.0, 620.0, 0.09, 0.11),
	])
	_sfx_bank["jump"] = _bake_voices([
		_v("sine", 240.0, 560.0, 0.13, 0.26),
		_v("tri", 380.0, 780.0, 0.10, 0.13),
	])
	_sfx_bank["land"] = _bake_voices([
		_v("sine", 140.0, 52.0, 0.09, 0.26),
		_v("noise", 500.0, 180.0, 0.055, 0.10),
	])
	_sfx_bank["levelup"] = _bake_voices([
		_v("sine", 523.25, 523.25, 0.20, 0.24, 0.0),
		_v("sine", 659.25, 659.25, 0.20, 0.24, 0.09),
		_v("sine", 783.99, 783.99, 0.22, 0.24, 0.18),
		_v("sine", 1046.50, 1046.50, 0.36, 0.26, 0.27),
	])

	# === Tactile Environmental Footstep & Water Splash SFX (Soft, Natural, Zero-Crackle) ===
	_sfx_bank["step_stone"] = _bake_voices([
		_v("sine", 195.0, 78.0, 0.045, 0.14),
		_v("bp_noise", 1650.0, 720.0, 0.036, 0.16),
	])
	_sfx_bank["step_grass"] = _bake_voices([
		_v("bp_noise", 2200.0, 1250.0, 0.075, 0.14),
		_v("noise", 420.0, 190.0, 0.055, 0.07),
	])
	_sfx_bank["step_sand"] = _bake_voices([
		_v("bp_noise", 1850.0, 920.0, 0.062, 0.16, 0.0),
		_v("bp_noise", 2400.0, 1150.0, 0.058, 0.12, 0.032),
		_v("sine", 130.0, 62.0, 0.055, 0.08, 0.0),
	])
	_sfx_bank["water_step"] = _bake_voices([
		_v("sine", 320.0, 740.0, 0.085, 0.22, 0.0),
		_v("bp_noise", 2100.0, 880.0, 0.110, 0.24, 0.008),
		_v("sine", 540.0, 960.0, 0.050, 0.10, 0.038),
	])
	_sfx_bank["water_splash"] = _bake_voices([
		_v("sine", 165.0, 58.0, 0.120, 0.30, 0.0),
		_v("sine", 290.0, 760.0, 0.100, 0.24, 0.012),
		_v("sine", 420.0, 1080.0, 0.095, 0.18, 0.055),
		_v("sine", 520.0, 1240.0, 0.085, 0.13, 0.110),
		_v("bp_noise", 2600.0, 720.0, 0.260, 0.42, 0.0),
		_v("noise", 950.0, 260.0, 0.220, 0.22, 0.015),
	])


func _v(wave: String, f0: float, f1: float, dur: float, amp: float, delay: float = 0.0) -> Dictionary:
	return {
		"wave": wave,
		"f0": f0,
		"f1": f1,
		"dur": dur,
		"amp": amp,
		"delay": delay,
	}


func _bake_voices(voices: Array) -> AudioStreamWAV:
	var max_end := 0.05
	for v in voices:
		max_end = maxf(max_end, float(v["delay"]) + float(v["dur"]))
	max_end += 0.015 # Clean silence tail for zero-crossing safety

	var total_frames := int(ceil(max_end * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(total_frames)
	buf.fill(0.0)

	var sr_f := float(SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4219

	for v in voices:
		var wave: String = v["wave"]
		var f0: float = float(v["f0"])
		var f1: float = float(v["f1"])
		var dur: float = maxf(0.01, float(v["dur"]))
		var amp: float = float(v["amp"])
		var start_idx := int(round(float(v["delay"]) * sr_f))
		var len_frames := int(round(dur * sr_f))
		var phase := 0.0
		var lp_noise := 0.0
		var lp_noise_lo := 0.0

		for i in range(len_frames):
			var out_idx := start_idx + i
			if out_idx >= total_frames:
				break
			var t := float(i) / sr_f
			var p := clampf(t / dur, 0.0, 1.0)
			var freq := lerpf(f0, f1, p)
			# Smooth 3ms attack + exponential decay + smooth 6ms release tail -> zero clicks!
			var atk_env := minf(1.0, t / 0.003)
			var rel_env := minf(1.0, (dur - t) / 0.006)
			var env := atk_env * rel_env * exp(-p * 3.8)

			var osc := 0.0
			if wave == "sine":
				phase = fmod(phase + freq / sr_f, 1.0)
				osc = sin(phase * TAU)
			elif wave == "tri":
				phase = fmod(phase + freq / sr_f, 1.0)
				osc = 4.0 * absf(phase - 0.5) - 1.0
			elif wave == "bp_noise":
				# Clean dual-pole band-pass noise for natural foliage, sand, and water swish
				var raw_bp := rng.randf_range(-1.0, 1.0)
				var c_hi := clampf(freq / (sr_f * 0.22), 0.06, 0.88)
				var c_lo := clampf((freq * 0.35) / (sr_f * 0.22), 0.02, 0.45)
				lp_noise = lerpf(lp_noise, raw_bp, c_hi)
				lp_noise_lo = lerpf(lp_noise_lo, raw_bp, c_lo)
				osc = (lp_noise - lp_noise_lo) * 1.65
			else:
				# Gently low-pass filtered noise (warm & punchy, zero harsh aliasing)
				var raw_n := rng.randf_range(-1.0, 1.0)
				var cutoff := clampf(freq / (sr_f * 0.25), 0.04, 0.85)
				lp_noise = lerpf(lp_noise, raw_n, cutoff)
				osc = lp_noise

			buf[out_idx] += osc * env * amp

	# Soft tanh saturation + normalize headroom to ~0.72 peak -> warm, punchy, NEVER hard-clips!
	var pcm := PackedByteArray()
	pcm.resize(total_frames * 2)
	for i in range(total_frames):
		var s := tanh(buf[i] * 1.15) * 0.72
		var i16 := clampi(int(round(s * 32767.0)), -32768, 32767)
		pcm.encode_s16(i * 2, i16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav
