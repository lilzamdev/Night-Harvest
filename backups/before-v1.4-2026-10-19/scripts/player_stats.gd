extends Node
class_name PlayerStats

## Manages player health, hunger, defense, level, XP, and gold.
## Access via "player_stats" group.
##
## Defense Formula: final_damage = max(1, base_damage - int(current_defense / DEFENSE_DIVISOR))
## With DEFENSE_DIVISOR = 20:
##   0 defense  → 0 reduction  → zombie deals 3 → ~33 hits to die
##   20 defense → 1 reduction  → zombie deals 2 → 50 hits to die
##   40 defense → 2 reduction  → zombie deals 1 → 100 hits to die

signal health_changed(current_hp: int, max_hp: int)
signal defense_changed(current_def: int, max_def: int)
signal hunger_changed(current_hunger: float, max_hunger: float)
signal hunger_state_changed(state: String)
signal level_changed(new_level: int)
signal xp_changed(current_xp: int, max_xp: int)
signal xp_gained(amount: int)
signal gold_changed(total: int)
signal player_died()

# --- Health ---
@export var max_health: int = 100
var current_health: int = 100

# --- Hunger-powered healing ---
@export var regeneration_enabled: bool = true
@export_range(0.1, 60.0, 0.1) var regeneration_interval: float = 2.0
@export_range(0.1, 100.0, 0.1) var regeneration_hunger_per_hp: float = 1.0
var _regeneration_elapsed: float = 0.0

# --- Defense ---
@export var max_defense: int = 50
@export var DEFENSE_DIVISOR: float = 20.0
var current_defense: int = 0

# --- Level / XP ---
@export var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 100

# --- Hunger (Phase 6) ---
@export var max_hunger: float = 100.0
var current_hunger: float = 100.0
@export var hunger_drain_interval: float = 10.0 ## Real seconds between hunger drain ticks
@export var hunger_drain_amount: float = 1.0 ## Hunger points lost per tick
@export var starvation_damage: int = 1
@export var starvation_interval: float = 5.0 ## Real seconds between starvation HP ticks
var _starvation_timer: float = 0.0
var _hunger_drain_elapsed: float = 0.0
var _last_hunger_state: String = "FULL"

# --- Gold ---
var gold: int = 0

# --- State ---
var is_dead: bool = false

# --- Damage Cooldown ---
@export var damage_cooldown: float = 0.5
var _cooldown_timer: float = 0.0
var _is_invulnerable: bool = false


func _ready() -> void:
	current_health = max_health
	current_hunger = max_hunger
	_last_hunger_state = get_hunger_state()
	add_to_group("player_stats")


func _process(delta: float) -> void:
	if _is_invulnerable:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_invulnerable = false
			_cooldown_timer = 0.0
	
	# Real-time hunger drain (pauses automatically when tree is paused)
	if not is_dead and current_hunger > 0.0:
		_hunger_drain_elapsed += delta
		if _hunger_drain_elapsed >= hunger_drain_interval:
			_hunger_drain_elapsed -= hunger_drain_interval
			drain_hunger(hunger_drain_amount)
	
	# Starvation: periodic HP damage when hunger is empty
	if current_hunger <= 0.0 and not is_dead:
		_starvation_timer += delta
		if _starvation_timer >= starvation_interval:
			_starvation_timer -= starvation_interval
			_apply_starvation_damage()

	_process_regeneration(delta)


## Restore whole HP only when there is enough hunger to pay for it.
## No accumulated healing credit while healthy, dead, or without enough food.
func _process_regeneration(delta: float) -> void:
	if not regeneration_enabled or is_dead or current_health >= max_health \
			or regeneration_interval <= 0.0 or regeneration_hunger_per_hp <= 0.0 \
			or current_hunger < regeneration_hunger_per_hp:
		_regeneration_elapsed = 0.0
		return
	_regeneration_elapsed += delta
	var ticks := int(_regeneration_elapsed / regeneration_interval)
	if ticks <= 0:
		return
	var affordable_hp := int(current_hunger / regeneration_hunger_per_hp)
	var restored_hp := mini(ticks, mini(max_health - current_health, affordable_hp))
	_regeneration_elapsed -= float(restored_hp) * regeneration_interval
	drain_hunger(float(restored_hp) * regeneration_hunger_per_hp)
	heal(restored_hp)
	if current_health >= max_health or current_hunger < regeneration_hunger_per_hp:
		_regeneration_elapsed = 0.0


## Apply damage with defense reduction. Returns actual damage dealt (0 if invulnerable).
func take_damage(base_damage: int) -> int:
	if is_dead or _is_invulnerable:
		return 0
	
	var reduction := int(current_defense / DEFENSE_DIVISOR)
	var final_damage := maxi(1, base_damage - reduction)
	
	current_health = maxi(0, current_health - final_damage)
	health_changed.emit(current_health, max_health)
	
	# Start invulnerability window
	_is_invulnerable = true
	_cooldown_timer = damage_cooldown
	
	if current_health <= 0:
		_die()
	
	return final_damage


## Restore health.
func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


## Set defense value.
func set_defense(value: int) -> void:
	current_defense = clampi(value, 0, max_defense)
	defense_changed.emit(current_defense, max_defense)


## Add XP with automatic level-up.
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.2)
		level_changed.emit(level)
	# Presentation notifications only; XP and level calculations above are unchanged.
	xp_changed.emit(xp, xp_to_next_level)
	xp_gained.emit(amount)


## Add gold.
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	player_died.emit()


## Full reset (used on scene restart).
func reset() -> void:
	current_health = max_health
	current_hunger = max_hunger
	is_dead = false
	_is_invulnerable = false
	_cooldown_timer = 0.0
	_starvation_timer = 0.0
	_hunger_drain_elapsed = 0.0
	_regeneration_elapsed = 0.0
	_last_hunger_state = get_hunger_state()
	health_changed.emit(current_health, max_health)
	defense_changed.emit(current_defense, max_defense)
	hunger_changed.emit(current_hunger, max_hunger)


# ==============================================================================
# HUNGER SYSTEM (Phase 6)
# ==============================================================================

## Drains hunger by the given amount. Called by the internal real-time timer.
func drain_hunger(amount: float = -1.0) -> void:
	if is_dead:
		return
	if amount < 0.0:
		amount = hunger_drain_amount
	current_hunger = clampf(current_hunger - amount, 0.0, max_hunger)
	hunger_changed.emit(current_hunger, max_hunger)
	_check_hunger_state()


## Restore hunger by the given amount. Returns actual amount restored.
## Returns 0.0 if already full.
func restore_hunger(amount: float) -> float:
	if is_dead:
		return 0.0
	var old := current_hunger
	current_hunger = clampf(current_hunger + amount, 0.0, max_hunger)
	var restored := current_hunger - old
	if restored > 0.0:
		hunger_changed.emit(current_hunger, max_hunger)
		_check_hunger_state()
		_starvation_timer = 0.0 # Reset starvation timer on eating
	return restored


## True when hunger is at maximum.
func is_full() -> bool:
	return current_hunger >= max_hunger


## Returns hunger state string for gameplay logic and HUD.
## Thresholds: 75-100=FULL, 40-74=NORMAL, 20-39=HUNGRY, 1-19=STARVING, 0=EMPTY
func get_hunger_state() -> String:
	if current_hunger <= 0.0:
		return "EMPTY"
	elif current_hunger < 20.0:
		return "STARVING"
	elif current_hunger < 40.0:
		return "HUNGRY"
	elif current_hunger < 75.0:
		return "NORMAL"
	else:
		return "FULL"


## Returns hunger as a 0.0–1.0 ratio for stamina/modifier checks.
func get_hunger_ratio() -> float:
	if max_hunger <= 0.0:
		return 0.0
	return current_hunger / max_hunger


func _check_hunger_state() -> void:
	var new_state := get_hunger_state()
	if new_state != _last_hunger_state:
		_last_hunger_state = new_state
		hunger_state_changed.emit(new_state)


func _apply_starvation_damage() -> void:
	if is_dead:
		return
	current_health = maxi(0, current_health - starvation_damage)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()
