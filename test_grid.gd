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

const TILE_PATH := Vector2i(2, 0)
const TILE_ETHER := Vector2i(3, 0)
const TILE_PLAYER := Vector2i(5, 0)
const TILE_OBJECTS := Vector2i(0, 7)
const TILE_GOAL := Vector2i(4, 0)
const TILE_GOAL_REACHED := Vector2i(5, 0)
const TILE_OCTALS := Vector2i(0, 1)
const TILE_EMITTERS := Vector2i(0, 5)

var _last_input_action := ""
var _last_input_delta := 0.0
var _is_first_echo := true
var _step_delta := 0.0
var _player_pos := Vector2i.ZERO
var _player_tile := TILE_PLAYER

@onready var _particle_layer := $"ParticleLayer" as TileMapLayer


func _ready() -> void:
	var player_cells := _particle_layer.get_used_cells_by_id(0, _player_tile)
	if player_cells.size() > 0:
		_player_tile = TILE_OBJECTS + Vector2i(2, 0)
		_player_pos = player_cells[0]
		_particle_layer.set_cell(_player_pos, 0, _player_tile)


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
			if _action(dir_vec):
				_tick()
				_step_delta = delta


func _action(dir: Vector2i) -> bool:
	var new_pos := _player_pos + dir
	var current_tile := _particle_layer.get_cell_atlas_coords(new_pos)
	
	# TODO: Move these to the CA and only change the player tile (needs 4 player move directions)
	
	if current_tile == TILE_PATH or current_tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4):
		_particle_layer.set_cell(_player_pos, 0, TILE_PATH)
		_particle_layer.set_cell(new_pos, 0, _player_tile)
		_player_pos = new_pos
		return true
	
	if current_tile == TILE_GOAL:
		_particle_layer.set_cell(_player_pos, 0, TILE_PATH)
		_particle_layer.set_cell(new_pos, 0, TILE_GOAL_REACHED)
		_player_pos = new_pos
		return true
	
	if current_tile.y in [TILE_EMITTERS.y, TILE_EMITTERS.y + 1]:
		var new_tile := current_tile
		new_tile.y = TILE_EMITTERS.y + ((current_tile.y - TILE_EMITTERS.y + 1) % 2)
		_particle_layer.set_cell(new_pos, 0, new_tile)
		return true
	
	return false


func _tick() -> void:
	var cell_positions := _particle_layer.get_used_cells()
	var cell_tiles := {}
	
	for pos in cell_positions:
		cell_tiles[pos] = _particle_layer.get_cell_atlas_coords(pos)
	
	for pos in cell_positions:
		var tile: Vector2i = cell_tiles[pos]
		
		var valid_neighbors = 0
		var active_emitters = 0
		var neighbor_value := -1
		var neighbor_dir := -1
		
		for neighbor_i in VON_NEUMANN_NEIGHBORS.size():
			var neighbor_pos := VON_NEUMANN_NEIGHBORS[neighbor_i] + pos
			
			if neighbor_pos not in cell_tiles:
				continue
			
			var neighbor_tile: Vector2i = cell_tiles[neighbor_pos]
			var target_dir := (neighbor_i + 2) % 4
			
			if neighbor_tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4):
				var current_dir := neighbor_tile.y - TILE_OCTALS.y
				if current_dir == target_dir:
					neighbor_value = neighbor_tile.x
					neighbor_dir = neighbor_tile.y - TILE_OCTALS.y
					valid_neighbors += 1
			
			if neighbor_tile.y == TILE_EMITTERS.y + 1:
				neighbor_value = neighbor_tile.x
				neighbor_dir = target_dir
				valid_neighbors += 1
				active_emitters += 1
		
		if tile == TILE_PATH:
			if valid_neighbors == 1:
				var new_tile := TILE_OCTALS + Vector2i(neighbor_value, neighbor_dir)
				_particle_layer.set_cell(pos, 0, new_tile)
				continue
		
		if tile.y == TILE_EMITTERS.y:
			if valid_neighbors == 1 and tile.x == neighbor_value:
				var new_tile := tile + Vector2i(0, 1)
				_particle_layer.set_cell(pos, 0, new_tile)
				continue
		
		if tile.y == TILE_EMITTERS.y + 1:
			if valid_neighbors == 0 or tile.x != neighbor_value:
				var new_tile := tile + Vector2i(0, -1)
				_particle_layer.set_cell(pos, 0, new_tile)
				continue
		
		if tile.y in range(TILE_OCTALS.y, TILE_OCTALS.y + 4):
			if valid_neighbors == 0:
				_particle_layer.set_cell(pos, 0, TILE_PATH)
				continue
