extends Node

## GameAudio — Central audio manager for Night Harvest.
##
## Registered as an autoload singleton. Access globally via: GameAudio.play("sound_name")
##
## Procedurally generates lightweight tonal sound effects for UI and gameplay
## feedback. All sounds are modular and replaceable: drop a .wav or .ogg file
## at res://Assets/Audio/SFX/{sound_name}.wav and it will be used instead of
## the procedural version automatically.
##
## Sounds that cannot be convincingly generated (zombie groans, footsteps,
## sword swings, music) are left as silent hooks with ASSET_REQUIRED markers.

const SAMPLE_RATE := 22050  # Lower rate is fine for short SFX, saves memory
const MIX_RATE := 22050

## Volume offsets per category (dB)
const VOL_UI := -10.0
const VOL_GAMEPLAY := -6.0
const VOL_WARNING := -4.0

## Asset override directory
const SFX_DIR := "res://Assets/Audio/SFX/"

# --- Cached procedural streams ---
var _streams: Dictionary = {}

# --- Player pool ---
var _players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
var _warning_player: AudioStreamPlayer  # Dedicated for warnings (never cut off)

# --- Asset paths for real sounds (placeholder hooks) ---
# When these files exist, they are loaded and used automatically.
var _asset_hooks: Dictionary = {
	"sword_swing": "sword_swing",
	"sword_hit": "sword_hit",
	"footstep": "footstep",
	"zombie_groan": "zombie_groan",
	"zombie_death": "zombie_death",
	"tree_chop": "tree_chop",
	"crop_plant": "crop_plant",
	"crop_harvest": "crop_harvest",
	"eat_bite": "eat_bite",
	"animal_ambient": "animal_ambient",
	"ambient_day": "ambient_day",
	"ambient_night": "ambient_night",
}


func _ready() -> void:
	# Create player pool (4 general + 1 warning)
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	
	_warning_player = AudioStreamPlayer.new()
	_warning_player.bus = "Master"
	add_child(_warning_player)
	
	# Generate all procedural sounds
	_streams["ui_click"] = _gen_ui_click()
	_streams["hotbar_select"] = _gen_hotbar_select()
	_streams["xp_gain"] = _gen_xp_gain()
	_streams["level_up"] = _gen_level_up()
	_streams["quest_complete"] = _gen_quest_complete()
	_streams["zombie_warning"] = _gen_zombie_warning()
	_streams["night_arrival"] = _gen_night_arrival()


## Play a named sound effect.
## Checks for a real asset override first, then falls back to procedural.
## For warning-category sounds, uses the dedicated warning player.
func play(sfx_name: String, volume_override: float = NAN) -> void:
	var stream: AudioStream = _load_override(sfx_name)
	if not stream:
		stream = _streams.get(sfx_name)
	if not stream:
		return  # No procedural version and no asset — silent hook
	
	var vol := _get_volume_for(sfx_name)
	if not is_nan(volume_override):
		vol = volume_override
	
	# Use dedicated player for warning sounds so they don't get cut off
	if sfx_name in ["zombie_warning", "night_arrival"]:
		_warning_player.stream = stream
		_warning_player.volume_db = vol
		_warning_player.play()
	else:
		var player := _players[_player_index]
		_player_index = (_player_index + 1) % _players.size()
		player.stream = stream
		player.volume_db = vol
		player.play()


## Check if a real asset file exists and load it.
func _load_override(sfx_name: String) -> AudioStream:
	var extensions: Array[String] = ["wav", "ogg"]
	for ext in extensions:
		var path: String = SFX_DIR + sfx_name + "." + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


func _get_volume_for(sfx_name: String) -> float:
	match sfx_name:
		"ui_click", "hotbar_select":
			return VOL_UI
		"xp_gain", "quest_complete", "level_up":
			return VOL_GAMEPLAY
		"zombie_warning", "night_arrival":
			return VOL_WARNING
		_:
			return VOL_GAMEPLAY


# ==============================================================================
# PROCEDURAL SOUND GENERATORS
# ==============================================================================
# All generators return AudioStreamWAV with 16-bit mono PCM data.
# Sounds are intentionally simple, short, and game-feel oriented.

## Short tick/pop — 50ms square wave at 800Hz
func _gen_ui_click() -> AudioStreamWAV:
	var duration := 0.05
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - float(i) / samples  # Linear decay
		envelope = envelope * envelope  # Faster decay curve
		var wave := signf(sin(TAU * 800.0 * t))  # Square wave
		var sample := int(wave * envelope * 12000.0)
		sample = clampi(sample, -32768, 32767)
		data.encode_s16(i * 2, sample)
	
	return _make_wav(data)


## Soft blip — 80ms sine sweep 600→700Hz
func _gen_hotbar_select() -> AudioStreamWAV:
	var duration := 0.08
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / samples
		var freq := lerpf(600.0, 700.0, progress)
		var envelope := 1.0 - progress  # Linear decay
		var wave := sin(TAU * freq * t)
		var sample := int(wave * envelope * 10000.0)
		sample = clampi(sample, -32768, 32767)
		data.encode_s16(i * 2, sample)
	
	return _make_wav(data)


## Rising ding — 120ms sine at 880Hz (A5), sharp attack, medium decay
func _gen_xp_gain() -> AudioStreamWAV:
	var duration := 0.12
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / samples
		# Quick attack (first 5%), then decay
		var envelope := 1.0
		if progress < 0.05:
			envelope = progress / 0.05
		else:
			envelope = 1.0 - (progress - 0.05) / 0.95
		envelope = maxf(0.0, envelope)
		# Slight upward sweep for "rising" feel
		var freq := lerpf(840.0, 920.0, progress)
		var wave := sin(TAU * freq * t)
		var sample := int(wave * envelope * 11000.0)
		sample = clampi(sample, -32768, 32767)
		data.encode_s16(i * 2, sample)
	
	return _make_wav(data)


## Ascending chime — 500ms, three staggered tones (C5→E5→G5)
func _gen_level_up() -> AudioStreamWAV:
	var duration := 0.55
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	# Three notes: C5=523Hz, E5=659Hz, G5=784Hz
	var notes: Array[float] = [523.0, 659.0, 784.0]
	var note_start: Array[float] = [0.0, 0.15, 0.30]  # Stagger start times
	var note_duration := 0.22
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var mixed := 0.0
		
		for n in range(notes.size()):
			var nt: float = t - note_start[n]
			if nt >= 0.0 and nt < note_duration:
				var np: float = nt / note_duration
				# Attack-decay envelope
				var env := 1.0
				if np < 0.08:
					env = np / 0.08
				else:
					env = 1.0 - (np - 0.08) / 0.92
				env = maxf(0.0, env)
				mixed += sin(TAU * notes[n] * nt) * env
		
		var sample := int(mixed * 8000.0)
		sample = clampi(sample, -32768, 32767)
		data.encode_s16(i * 2, sample)
	
	return _make_wav(data)


## Triumphant two-tone — 400ms, G4→C5
func _gen_quest_complete() -> AudioStreamWAV:
	var duration := 0.45
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	# G4=392Hz, C5=523Hz
	var notes: Array[float] = [392.0, 523.0]
	var note_start: Array[float] = [0.0, 0.18]
	var note_duration := 0.25
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var mixed := 0.0
		
		for n in range(notes.size()):
			var nt: float = t - note_start[n]
			if nt >= 0.0 and nt < note_duration:
				var np: float = nt / note_duration
				var env := 1.0
				if np < 0.06:
					env = np / 0.06
				else:
					env = 1.0 - (np - 0.06) / 0.94
				env = maxf(0.0, env)
				mixed += sin(TAU * notes[n] * nt) * env
		
		var sample := int(mixed * 9000.0)
		sample = clampi(sample, -32768, 32767)
		data.encode_s16(i * 2, sample)
	
	return _make_wav(data)


## Ominous alarm — 600ms low square wave 120Hz, amplitude pulse
func _gen_zombie_warning() -> AudioStreamWAV:
	var duration := 0.65
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / samples
		# Pulsing envelope — two pulses
		var pulse := absf(sin(TAU * 3.0 * t))
		# Overall fade out
		var fade := 1.0 - progress * 0.4
		var envelope := pulse * fade
		# Low square wave with slight detune layer
		var wave := signf(sin(TAU * 120.0 * t)) * 0.6
		wave += signf(sin(TAU * 125.0 * t)) * 0.4  # Slight detune for thickness
		var sample := int(wave * envelope * 9000.0)
		sample = clampi(sample, -32768, 32767)
		data.encode_s16(i * 2, sample)
	
	return _make_wav(data)


## Deep dramatic hit — 500ms low sine 80Hz + 160Hz, heavy attack, long decay
func _gen_night_arrival() -> AudioStreamWAV:
	var duration := 0.55
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / samples
		# Sharp attack, exponential decay
		var envelope := 1.0
		if progress < 0.03:
			envelope = progress / 0.03
		else:
			envelope = exp(-4.0 * (progress - 0.03))
		envelope = maxf(0.0, envelope)
		# Layered low frequencies
		var wave := sin(TAU * 80.0 * t) * 0.6
		wave += sin(TAU * 160.0 * t) * 0.3
		wave += sin(TAU * 240.0 * t) * 0.1  # Subtle harmonic
		var sample := int(wave * envelope * 14000.0)
		sample = clampi(sample, -32768, 32767)
		data.encode_s16(i * 2, sample)
	
	return _make_wav(data)


# ==============================================================================
# HELPERS
# ==============================================================================

## Creates an AudioStreamWAV from raw PCM16 byte data.
func _make_wav(pcm_data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = pcm_data
	return wav
