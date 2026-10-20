extends Node

## Music — background music with crossfades (autoload "Music").
##   Title screen: music-box lullaby
##   Day: bouncy farm tune · Night: tense heartbeat · Blood Moon: driving drums
## Plays on the "Music" bus, so Settings > Audio > Music controls it.

const TRACKS := {
	"title": "res://Assets/Audio/Music/title_theme.ogg",
	"day": "res://Assets/Audio/Music/day_theme.ogg",
	"night": "res://Assets/Audio/Music/night_theme.ogg",
	"blood": "res://Assets/Audio/Music/blood_moon_theme.ogg",
	"mines": "res://Assets/Audio/Music/mines_theme.ogg",
}
const BASE_DB := -6.0
const FADE := 1.6

var current: String = ""
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _indoors := false
## "" = the farm/overworld, "mines" = The Hollow Mines (its own music).
var area: String = ""
var _night := false
var _blood := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _make()
	_b = _make()


func _make() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	p.volume_db = -60.0
	add_child(p)
	return p


func play_track(id: String) -> void:
	if id == current or not TRACKS.has(id):
		return
	current = id
	var stream: AudioStream = load(TRACKS[id]) if ResourceLoader.exists(TRACKS[id]) else null
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var old := _a if _a.playing else null
	var nxt := _b if old == _a else _a
	if old == null:
		nxt = _a
		old = _b
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", _target_db(), FADE)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, FADE)
		tw.chain().tween_callback(old.stop)


func _target_db() -> float:
	return BASE_DB - (5.0 if _indoors else 0.0)


func play_title() -> void:
	_indoors = false
	area = ""
	_blood = false
	play_track("title")


## Picks day or night music from the current game clock.
func play_game_music() -> void:
	var clock := get_tree().get_first_node_in_group("game_clock")
	_night = clock != null and clock.is_night()
	if area == "mines":
		play_track("mines")
		return
	play_track(("blood" if _blood else "night") if _night else "day")


func set_night(night: bool, blood: bool) -> void:
	_night = night
	_blood = blood
	if area == "mines":
		return
	play_track(("blood" if blood else "night") if night else "day")


## Switches music when the player changes dimension.
func set_area(a: String) -> void:
	area = a
	if a == "mines":
		play_track("mines")
	else:
		play_track(("blood" if _blood else "night") if _night else "day")


func set_indoors(on: bool) -> void:
	_indoors = on
	for p in [_a, _b]:
		if p.playing and p.volume_db > -30.0:
			create_tween().tween_property(p, "volume_db", _target_db(), 0.4)
