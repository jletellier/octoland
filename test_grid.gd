@tool
extends Node2D


const VON_NEUMANN_NEIGHBORS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

const INPUT_ECHO_DELTA_INITIAL := 0.2
const INPUT_ECHO_DELTA := 0.2
const STEP_DURATION := 0.2
const INPUT_ACTIONS := [
	"game_right",
	"game_down",
	"game_left",
	"game_up",
]

const TILE_EMPTY := Vector2i(-1, -1)
const TILE_CONDUCTOR := Vector2i(0, 0)
const TILE_BLOCKED := Vector2i(1, 0)
const TILE_OCTALS := Vector2i(0, 1)
const TILE_EMITTERS := Vector2i(0, 5)
const TILE_MODIFIERS := Vector2i(0, 7)
const TILE_OBJECTS := Vector2i(0, 12)

@export_tool_button("Tick Repeat") var tick_repeat_action := _tick_repeat
@export var tick_limit := 50

var _last_input_action := ""
var _last_input_delta := 0.0
var _is_first_echo := true
var _step_delta := 0.0
var _tick_changes := false
#var _player_pos := Vector2i.ZERO
#var _player_tile := TILE_PLAYER

@onready var _particle_layer := $"ParticleLayer" as TileMapLayer


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
	
	#var player_cells := _particle_layer.get_used_cells_by_id(0, _player_tile)
	#if player_cells.size() > 0:
		#_player_tile = TILE_OBJECTS + Vector2i(1, 0)
		#_player_pos = player_cells[0]
		#_particle_layer.set_cell(_player_pos, 0, _player_tile)


func _process(delta: float) -> void:
	if _step_delta > 0.0:
		_step_delta += delta
		#step_process(delta, STEP_DURATION)
		
		if _step_delta > STEP_DURATION:
			_step_delta = 0.0
			_last_input_delta = INPUT_ECHO_DELTA
			#tick()
		
		return
	
	var next_input_action := ""
	for input_action in INPUT_ACTIONS:
		if Input.is_action_just_pressed(input_action):
			next_input_action = input_action
			_is_first_echo = true
			break
	
	_last_input_delta += delta
	var echo_delta := INPUT_ECHO_DELTA_INITIAL if _is_first_echo else INPUT_ECHO_DELTA
	var is_valid_delta := (_last_input_delta > echo_delta)
	
	var is_echo_input_action := false
	if next_input_action == "" and _last_input_action != "":
		is_echo_input_action = Input.is_action_pressed(_last_input_action)
		if is_echo_input_action:
			next_input_action = _last_input_action
	
	if next_input_action == "":
		for input_action in INPUT_ACTIONS:
			if Input.is_action_pressed(input_action):
				next_input_action = input_action
				break
	
	if next_input_action != _last_input_action or (is_echo_input_action and is_valid_delta):
		if is_echo_input_action:
			_is_first_echo = false
		
		_last_input_action = next_input_action
		_last_input_delta = 0.0
		
		var dir_vec := Vector2i.ZERO
		match _last_input_action:
			"game_right": dir_vec = Vector2i.RIGHT
			"game_down": dir_vec = Vector2i.DOWN
			"game_left": dir_vec = Vector2i.LEFT
			"game_up": dir_vec = Vector2i.UP
		if dir_vec != Vector2i.ZERO:
			_tick()
			#if _action(dir_vec):
				#_tick()
			_step_delta = delta


#func _action(dir: Vector2i) -> bool:
	#var target_pos := _player_pos + dir
	#var current_tile := _particle_layer.get_cell_atlas_coords(_player_pos)
	#var target_tile := _particle_layer.get_cell_atlas_coords(target_pos)
	#
	## TODO: Move these to the CA and only change the player tile (needs 4 player move directions)
	#
	#if target_tile in [TILE_PATH, TILE_CONDUCTOR, TILE_LIQUID, TILE_LIQUID_POWERED, TILE_VOID] \
			#or target_tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4):
		#_particle_layer.set_cell(_player_pos, 0, Vector2i(current_tile.x, 0))
		#
		#if target_tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4):
			#_particle_layer.set_cell(target_pos, 0, TILE_OBJECTS + Vector2i(TILE_CONDUCTOR.x, 0))
		#else:
			#_particle_layer.set_cell(target_pos, 0, TILE_OBJECTS + Vector2i(target_tile.x, 0))
		#
		#_player_pos = target_pos
		#return true
	#
	#if target_tile == TILE_GOAL:
		#_particle_layer.set_cell(_player_pos, 0, TILE_PATH)
		#_particle_layer.set_cell(target_pos, 0, TILE_GOAL_REACHED)
		#_player_pos = target_pos
		#return true
	#
	#if target_tile.y in [TILE_EMITTERS.y, TILE_EMITTERS.y + 1]:
		#var new_tile := target_tile
		#new_tile.y = TILE_EMITTERS.y + ((target_tile.y - TILE_EMITTERS.y + 1) % 2)
		#_particle_layer.set_cell(target_pos, 0, new_tile)
		#return true
	#
	#return false


func _tick() -> void:
	var cell_positions := _particle_layer.get_used_cells()
	var cell_tiles := {}
	
	for pos in cell_positions:
		cell_tiles[pos] = _particle_layer.get_cell_atlas_coords(pos)
	
	for pos in cell_positions:
		var tile: Vector2i = cell_tiles[pos]
		
		if tile in [TILE_BLOCKED] or \
				tile.y in range(TILE_EMITTERS.y, TILE_EMITTERS.y + 1):
			continue
		
		var current_value := -1
		var current_dir := -1
		if tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4):
			current_value = tile.x
			current_dir = tile.y - TILE_OCTALS.y
		elif tile.y in range(TILE_MODIFIERS.y + 1, TILE_MODIFIERS.y + 5):
			current_value = tile.x
			current_dir = tile.y - TILE_MODIFIERS.y + 1
		elif tile.y == TILE_MODIFIERS.y:
			current_dir = tile.x
		
		var new_value := current_value
		var new_dir := current_dir
		
		for neighbor_i in VON_NEUMANN_NEIGHBORS.size():
			var neighbor_pos := VON_NEUMANN_NEIGHBORS[neighbor_i] + pos
			
			if neighbor_pos not in cell_tiles:
				continue
			
			var neighbor_tile: Vector2i = cell_tiles[neighbor_pos]
			
			if neighbor_tile in [TILE_BLOCKED]:
				continue
			
			var neighbor_value := -1
			var neighbor_dir := -1
			if neighbor_tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4):
				neighbor_value = neighbor_tile.x
				neighbor_dir = neighbor_tile.y - TILE_OCTALS.y
			elif neighbor_tile.y == TILE_EMITTERS.y + 1:
				neighbor_value = neighbor_tile.x
			
			# Values travel only one direction
			if neighbor_dir != -1 and neighbor_dir != (neighbor_i + 2) % 4:
				continue
			
			# Value gets erased, if the origin tile is empty
			if (neighbor_i + 2) % 4 == current_dir and neighbor_value == -1:
				new_value = -1
				break
			
			if current_value == -1 and neighbor_value != -1:
				new_value = neighbor_value
				new_dir = (neighbor_i + 2) % 4
		
		if current_value == new_value:
			continue
		
		_tick_changes = true
		
		if tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4) or tile == TILE_CONDUCTOR:
			if new_value == -1:
				_particle_layer.set_cell(pos, 0, TILE_CONDUCTOR)
			else:
				_particle_layer.set_cell(pos, 0, TILE_OCTALS + Vector2i(new_value, new_dir))
			continue
		
		#if tile.y == TILE_MODIFIERS.y:
			#if new_value != -1:
				#_particle_layer.set_cell(pos, 0, TILE_MODIFIERS + Vector2i(new_value, tile.x))
			#continue


func _tick_repeat() -> void:
	var tick_count := 0
	while true:
		_tick_changes = false
		_tick()
		
		if _tick_changes == false:
			break
		
		tick_count += 1
		if tick_count == tick_limit:
			push_warning("Tick limit reached")
			break
