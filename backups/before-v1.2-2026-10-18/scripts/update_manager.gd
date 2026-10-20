extends Node

## UpdateManager — in-game updates for Night Harvest (autoload, must stay FIRST).
##
## How it works
##   1. The team publishes a small JSON "manifest" online (see UPDATES.md) that names
##      the newest version and a link to a .pck file exported from Godot.
##   2. Settings > Updates > CHECK FOR UPDATES reads the manifest.
##   3. DOWNLOAD & INSTALL saves the .pck into user://updates/ and verifies it.
##   4. The game restarts. On boot this autoload loads the newest installed .pck over
##      the base game files *before* any other script or scene is loaded.
##
## Player data is never touched: saves live in user://saves/ and settings in
## user://settings.cfg, which updates never overwrite. The game is also saved
## before restarting.
##
## Safety: if a freshly installed update crashes before reaching the title screen,
## the next launch skips it automatically and the game falls back to the base build.

signal check_started
signal check_finished(result: String, info: Dictionary)  ## result: "update", "latest", "error"
signal download_progress(ratio: float, bytes_done: int, bytes_total: int)
signal download_finished(ok: bool, message: String)

## Version of the game files built into this executable.
const BASE_VERSION := "1.1.0"
const UPDATE_DIR := "user://updates"
const STATE_FILE := "user://updates/installed.json"
const PREFS_FILE := "user://updates/prefs.cfg"
const SETTING_URL := "night_harvest/updates/manifest_url"
const DEFAULT_MANIFEST_URL := "https://raw.githubusercontent.com/limbrasonadev/Night-Harvest/master/updates/manifest.json"

## Version the player is actually running (base, or the loaded update).
var current_version: String = BASE_VERSION
var patch_loaded: bool = false
var latest_info: Dictionary = {}
var state: String = "idle"  ## idle, checking, available, latest, downloading, ready, error
var status_text: String = ""
var auto_check: bool = true

var _http: HTTPRequest
var _dl: HTTPRequest
var _dl_total: int = 0
var _checked_this_launch := false


func _init() -> void:
	# Runs before the other autoloads are created, so they load patched scripts.
	_load_installed_patch()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_manifest_done)
	_dl = HTTPRequest.new()
	_dl.timeout = 0.0
	# Threaded with big chunks so the download speed doesn't depend on the frame rate.
	_dl.use_threads = true
	_dl.download_chunk_size = 1048576
	add_child(_dl)
	_dl.request_completed.connect(_on_download_done)
	set_process(false)
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_FILE) == OK:
		auto_check = bool(cfg.get_value("updates", "auto_check", true))
	status_text = "VERSION %s" % current_version


## Called by the title screen once it is up: the build booted fine.
func mark_boot_ok() -> void:
	var st := _read_state()
	if st.get("boot_pending", false):
		st["boot_pending"] = false
		_write_state(st)
	if auto_check and not _checked_this_launch:
		_checked_this_launch = true
		check_for_updates(true)


func manifest_url() -> String:
	return str(ProjectSettings.get_setting(SETTING_URL, DEFAULT_MANIFEST_URL))


# ==========================================================================
# Boot: load installed update
# ==========================================================================

func _load_installed_patch() -> void:
	if OS.has_feature("editor") and OS.get_environment("NH_TEST_PATCH") != "1":
		return  # Never shadow the project files while developing.
	var st := _read_state()
	var file := str(st.get("file", ""))
	if file == "" or not FileAccess.file_exists(file):
		return
	if bool(st.get("boot_pending", false)):
		# Last launch with this update never reached the title screen: skip it.
		push_warning("UpdateManager: update %s failed to start last time, using base game." % st.get("version", "?"))
		st["file"] = ""
		st["failed_version"] = st.get("version", "")
		st["boot_pending"] = false
		_write_state(st)
		return
	if _compare(str(st.get("version", "0")), BASE_VERSION) <= 0:
		return  # The executable is already newer than the installed update.
	if ProjectSettings.load_resource_pack(file, true):
		patch_loaded = true
		current_version = str(st.get("version", BASE_VERSION))
		st["boot_pending"] = true
		_write_state(st)
	else:
		push_warning("UpdateManager: could not load %s" % file)


# ==========================================================================
# Check
# ==========================================================================

func check_for_updates(quiet: bool = false) -> void:
	if state == "checking" or state == "downloading":
		return
	state = "checking"
	status_text = "CHECKING FOR UPDATES..."
	check_started.emit()
	var url := manifest_url()
	var err := _http.request(url + ("&" if "?" in url else "?") + "t=%d" % Time.get_unix_time_from_system())
	if err != OK:
		_fail("COULD NOT REACH THE UPDATE SERVER.", quiet)


func _on_manifest_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("COULD NOT CONNECT. CHECK YOUR INTERNET AND TRY AGAIN.", false)
		return
	if code == 404:
		state = "latest"
		status_text = "NO UPDATES PUBLISHED YET. YOU HAVE V%s." % current_version
		check_finished.emit("latest", {})
		return
	if code != 200:
		_fail("THE UPDATE SERVER IS BUSY (CODE %d). TRY AGAIN LATER." % code, false)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not data.has("version"):
		_fail("THE UPDATE INFO IS DAMAGED. TRY AGAIN LATER.", false)
		return
	latest_info = data
	var latest := str(data["version"])
	if _compare(latest, current_version) > 0 and str(data.get("pck_url", "")) != "":
		var min_base := str(data.get("min_base", "0"))
		if _compare(BASE_VERSION, min_base) < 0:
			state = "error"
			status_text = "VERSION %s NEEDS A FULL REINSTALL. DOWNLOAD IT FROM THE GAME PAGE." % latest
			check_finished.emit("error", data)
			return
		state = "available"
		status_text = "VERSION %s IS AVAILABLE!" % latest
		check_finished.emit("update", data)
	else:
		state = "latest"
		status_text = "YOU HAVE THE LATEST VERSION (%s)." % current_version
		check_finished.emit("latest", data)


func _fail(msg: String, _quiet: bool) -> void:
	state = "error"
	status_text = msg
	check_finished.emit("error", {})


# ==========================================================================
# Download & install
# ==========================================================================

func download_update() -> void:
	if state != "available" or latest_info.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	var tmp := UPDATE_DIR + "/download.tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	_dl.download_file = tmp
	_dl_total = int(latest_info.get("size", 0))
	var err := _dl.request(str(latest_info["pck_url"]))
	if err != OK:
		state = "error"
		status_text = "DOWNLOAD COULD NOT START."
		download_finished.emit(false, status_text)
		return
	state = "downloading"
	status_text = "DOWNLOADING VERSION %s..." % latest_info["version"]
	set_process(true)


func _process(_delta: float) -> void:
	if state != "downloading":
		set_process(false)
		return
	var done := _dl.get_downloaded_bytes()
	var total := _dl.get_body_size()
	if total <= 0:
		total = _dl_total
	download_progress.emit(float(done) / float(total) if total > 0 else 0.0, done, total)


func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	var tmp := UPDATE_DIR + "/download.tmp"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(tmp):
		state = "available"
		status_text = "DOWNLOAD FAILED (CODE %d). CHECK YOUR CONNECTION AND TRY AGAIN." % code
		download_finished.emit(false, status_text)
		return
	var want := str(latest_info.get("sha256", "")).to_lower()
	if want != "" and FileAccess.get_sha256(tmp).to_lower() != want:
		DirAccess.remove_absolute(tmp)
		state = "available"
		status_text = "THE DOWNLOAD WAS DAMAGED. PLEASE TRY AGAIN."
		download_finished.emit(false, status_text)
		return
	var ver := str(latest_info["version"])
	var final_path := "%s/night_harvest_%s.pck" % [UPDATE_DIR, ver]
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	DirAccess.rename_absolute(tmp, final_path)
	var old := _read_state()
	var old_file := str(old.get("file", ""))
	_write_state({"version": ver, "file": final_path, "installed_at": Time.get_unix_time_from_system(),
		"notes": latest_info.get("notes", []), "boot_pending": false, "previous_file": old_file})
	# Keep just one older update around for safety; clean anything older.
	_cleanup_old_packs([final_path, old_file])
	state = "ready"
	status_text = "VERSION %s IS READY. RESTART TO PLAY IT." % ver
	download_finished.emit(true, status_text)


## Saves the game (if one is running) and restarts the executable.
func restart_game() -> void:
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").save_game(false)
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


## Removes the installed update and goes back to the base game files.
func remove_installed_update() -> void:
	var st := _read_state()
	var file := str(st.get("file", ""))
	_write_state({"file": "", "version": BASE_VERSION})
	if file != "" and FileAccess.file_exists(file) and not patch_loaded:
		DirAccess.remove_absolute(file)
	state = "ready"
	status_text = "UPDATE REMOVED. RESTART TO GO BACK TO VERSION %s." % BASE_VERSION


func has_installed_update() -> bool:
	return str(_read_state().get("file", "")) != ""


func installed_notes() -> Array:
	return _read_state().get("notes", [])


func set_auto_check(on: bool) -> void:
	auto_check = on
	var cfg := ConfigFile.new()
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	cfg.load(PREFS_FILE)
	cfg.set_value("updates", "auto_check", on)
	cfg.save(PREFS_FILE)


# ==========================================================================
# Helpers
# ==========================================================================

func _cleanup_old_packs(keep: Array) -> void:
	var d := DirAccess.open(UPDATE_DIR)
	if d == null:
		return
	for f in d.get_files():
		var path := UPDATE_DIR + "/" + f
		if f.ends_with(".pck") and not keep.has(path):
			DirAccess.remove_absolute(path)


func _read_state() -> Dictionary:
	if not FileAccess.file_exists(STATE_FILE):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_FILE))
	return v if v is Dictionary else {}


func _write_state(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	var f := FileAccess.open(STATE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


## Compares "1.2.10" style versions. Returns -1, 0 or 1.
static func _compare(a: String, b: String) -> int:
	var pa := a.strip_edges().trim_prefix("v").split(".")
	var pb := b.strip_edges().trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0
