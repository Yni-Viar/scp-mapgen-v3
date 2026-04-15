@icon("res://MapGen/icons/MapGenNode.svg")
extends MapGenCore
## AStar map generator backend
class_name MapGenAStar

## Works only if there are large endrooms, to prevent endless loop if cannot spawn
const NUMBER_OF_TRIES_TO_SPAWN: int = 4
## For performance reasons. Correct the code to increase the limit
const MAX_ROOMS_SPAWN: int = 512

const DOUBLE_ROOM_ROTATIONS: Dictionary[MapGenRoom.DoubleRoomFixedRotation, float] = {
	MapGenRoom.DoubleRoomFixedRotation.DEGREES_0: 0,
	MapGenRoom.DoubleRoomFixedRotation.DEGREES_90: 90,
	MapGenRoom.DoubleRoomFixedRotation.DEGREES_180: 180,
	MapGenRoom.DoubleRoomFixedRotation.DEGREES_270: 270,
}

func start_generation() -> void:
	clear()
	prepare_generation()
	# Determines, if the generation is too large to stop it.
	# You can change the limit in MAX_ROOM_SPAWN const.
	var all_rooms_count: int = size_x * size_y * room_amount
	if all_rooms_count > MAX_ROOMS_SPAWN:
		printerr("The limit of " + str(MAX_ROOMS_SPAWN) + " rooms for all zones reached. Stopping the program...")
		printerr("If you want to increase the limit, set MAX_ROOM_SPAWN constant to higher value, althrough it is not recommended.")
		return
	generate_zone_astar()
	place_room_positions()

## Prepares room generation
func prepare_generation() -> void:
	if debug_print:
		print("Preparing generation...")
	if infinite_generation && better_zone_generation:
		for i in range(zone_size / 2):
			var random_point: Vector2i = Vector2i(rng.randi_range(2, zone_size - 3), rng.randi_range(2, zone_size - 3))
			if random_point.x != zone_size / 2 && random_point.y != zone_size / 2:
				disabled_points.append(random_point)
	size_x = zone_size * (map_size_x + 1)
	size_y = zone_size * (map_size_y + 1)
	mapgen.resize(size_x)
	# Fill mapgen with zeros
	for g in range(size_x):
		mapgen[g].resize(size_y)
		for h in range(size_y):
			mapgen[g][h] = Room.new()
			
			# Waiting for Godot struct implementation
			#mapgen[g][h].exist = false
			#mapgen[g][h].north = false
			#mapgen[g][h].south = false
			#mapgen[g][h].east = false
			#mapgen[g][h].west = false
			#mapgen[g][h].room_type = RoomTypes.EMPTY
			#mapgen[g][h].angle = -1
			#mapgen[g][h].large = false
			#mapgen[g][h].checkpoint = false
			#mapgen[g][h].double_room = DoubleRoomTypes.NONE
	

## Main function, that generate the zones. Rewritten in 7.0
func generate_zone_astar() -> void:
	if debug_print:
		print("Generating the map...")
	# Zone counter. Used for determining a center of the map.
	var zone_counter: Vector2i = Vector2i.ZERO
	# Zone index. Used for iterating zone resources.
	var zone_index: int = 0
	
	# Zone center for the first quadrant.
	var zone_center: float = zone_size / 2
	for i in range(map_size_x + 1):
		zone_counter.x = i
		for j in range(map_size_y + 1):
			# Large room amount (when checkpoints enabled, there are fewer rooms)
			var large_room_amount: int = zone_size / 6 if !checkpoints_enabled else (zone_size - 2) / 6
			zone_counter.y = j
			var number_of_rooms: int = zone_size * room_amount
			# to deal with zero-sized zone_counter, there is a simple formula - if is not odd - 
			# add value to be not null
			
			var current_zone_center: Vector2i = Vector2i(zone_center + (zone_size * zone_counter.x), zone_center + (zone_size * zone_counter.y))
			mapgen[current_zone_center.x][current_zone_center.y].exist = true
			if number_of_rooms > (zone_size - 1) * 4 - 4 - large_room_amount * 6:
				printerr("Too many rooms, map won't spawn")
				return
			elif number_of_rooms < 1:
				printerr("Too few rooms, map won't spawn")
				return
			# Available room position (for AStar walk)
			var available_room_position: Array[Vector2i] = [Vector2i(size_x / (map_size_x + 1) * zone_counter.x, size_x / (map_size_x + 1) * (zone_counter.x + 1) - 1),Vector2i(size_y / (map_size_y + 1) * zone_counter.y, size_y / (map_size_y + 1) * (zone_counter.y + 1) - 1)]
			# Random room position. If large rooms enabled, also used for large room coordinates
			var random_room: Vector2i
			## Reworked large rooms module
			if large_rooms && endrooms_single_large_amount[zone_index] > 0:
				for k in range(large_room_amount):
					for l in range(NUMBER_OF_TRIES_TO_SPAWN):
						if checkpoints_enabled:
							## If checkpoints enabled, let's clean path for checkpoints
							## As a workaround, large rooms will be always near center of map.
							random_room = Vector2i(rng.randi_range(available_room_position[0].x + 3, available_room_position[0].y - 3), rng.randi_range(available_room_position[1].x + 3, available_room_position[1].y - 3))
						else:
							random_room = Vector2i(rng.randi_range(available_room_position[0].x, available_room_position[0].y), rng.randi_range(available_room_position[1].x, available_room_position[1].y))
						if check_room_dimensions(random_room.x, random_room.y, 0):
							walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), random_room)
							mapgen[random_room.x][random_room.y].large = true
							break
			## Walk before need-to-spawn rooms runs out
			while number_of_rooms > 0:
				if checkpoints_enabled:
					## If checkpoints enabled, disable non-checkpoint rooms in generic hallway generation
					random_room = Vector2i(rng.randi_range(available_room_position[0].x + 1, available_room_position[0].y - 1), rng.randi_range(available_room_position[1].x + 1, available_room_position[1].y - 1))
				else: ## Do as it was in 7.x, except reverted old better zone generation
					random_room = Vector2i(rng.randi_range(available_room_position[0].x, available_room_position[0].y), rng.randi_range(available_room_position[1].x, available_room_position[1].y))
				if better_zone_generation && mapgen[random_room.x][random_room.y].exist && endroom_amount < better_zone_generation_min_amount:
					continue
				walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), random_room)
				number_of_rooms -= 1
			
			## If infinite generation, go for all 4 directions
			if infinite_generation && map_size_x == 0 && map_size_y == 0:
				walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), Vector2i(current_zone_center.x, zone_size - 1), true)
				walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), Vector2i(current_zone_center.x, 0), true)
				walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), Vector2i(zone_size - 1, current_zone_center.y), true)
				walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), Vector2i(0, current_zone_center.y), true)
			else:
				## Connect two zones
				if zone_counter.x < map_size_x:
					var zone_center_x: int = zone_center + (zone_size * (zone_counter.x + 1))
					walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), Vector2(zone_center_x, current_zone_center.y))
				if zone_counter.y < map_size_y:
					var zone_center_y: int = zone_center + (zone_size * (zone_counter.y + 1))
					walk_astar(Vector2i(current_zone_center.x, current_zone_center.y), Vector2(current_zone_center.x, zone_center_y))
			zone_index += 1
		zone_counter.y = 0

## Checks spawn places for large rooms in given coordinates
## type: 0 - room1, 1 - room2, 2 - room2C, 3 - room3
func check_room_dimensions(x: int, y: int, type: int) -> bool:
	match type:
		0: ## ROOM1 - endroom
			if x == 0 && y == 0:
				if !mapgen[x + 1][y].exist:
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x][y + 1].exist:
					disabled_points.append(Vector2i(x, y + 1))
					return true
				else:
					return false
			elif x == size_x - 1 && y == size_y - 1:
				if !mapgen[x - 1][y].exist:
					disabled_points.append(Vector2i(x - 1, y))
					return true
				elif !mapgen[x][y - 1].exist:
					disabled_points.append(Vector2i(x, y - 1))
					return true
				else:
					return false
			elif x == 0 && y == size_y - 1:
				if !mapgen[x + 1][y].exist:
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x][y - 1].exist:
					disabled_points.append(Vector2i(x, y - 1))
					return true
				else:
					return false
			elif x == size_x - 1 && y == 0:
				if !mapgen[x - 1][y].exist:
					disabled_points.append(Vector2i(x - 1, y))
					return true
				elif !mapgen[x][y + 1].exist:
					disabled_points.append(Vector2i(x, y + 1))
					return true
				else:
					return false
			## |[x][x]  |        |[x]
			## |[o][x]  |[o][x]  |[o]
			## |        |[x][x]  |[x]
			elif x == 0:
				if !mapgen[x][y + 1].exist && !mapgen[x + 1][y + 1].exist && !mapgen[x + 1][y].exist: 
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x + 1, y + 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x][y - 1].exist && !mapgen[x + 1][y - 1].exist && !mapgen[x + 1][y].exist:
					disabled_points.append(Vector2i(x, y - 1))
					disabled_points.append(Vector2i(x + 1, y - 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x][y + 1].exist && !mapgen[x][y - 1].exist:
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x, y - 1))
					return true
				else:
					return false
			## [x][x]|        |  [x]|
			## [x][o]|  [x][o]|  [o]|
			##       |  [x][x]|  [x]|
			elif x == size_x - 1:
				if !mapgen[x][y + 1].exist && !mapgen[x - 1][y + 1].exist && !mapgen[x - 1][y].exist:
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x - 1, y + 1))
					disabled_points.append(Vector2i(x - 1, y))
					return true
				elif !mapgen[x][y - 1].exist && !mapgen[x - 1][y - 1].exist && !mapgen[x - 1][y].exist:
					disabled_points.append(Vector2i(x, y - 1))
					disabled_points.append(Vector2i(x - 1, y - 1))
					disabled_points.append(Vector2i(x - 1, y))
					return true
				elif !mapgen[x][y + 1].exist && !mapgen[x][y - 1].exist:
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x, y - 1))
					return true
				else:
					return false
			## [x][x]   [x][x]   
			## [o][x]   [x][o]   [x][o][x]
			## ------   ------   ---------
			elif y == 0:
				if !mapgen[x][y + 1].exist && !mapgen[x + 1][y + 1].exist && !mapgen[x + 1][y].exist:
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x + 1, y + 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x - 1][y].exist && !mapgen[x - 1][y + 1].exist && !mapgen[x][y + 1].exist:
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x - 1, y + 1))
					disabled_points.append(Vector2i(x, y + 1))
					return true
				elif !mapgen[x + 1][y].exist && !mapgen[x - 1][y].exist:
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				else:
					return false
			## ------   ------   ---------  
			## [o][x]   [x][o]   [x][o][x]
			## [x][x]   [x][x]
			elif y == size_y - 1:
				if !mapgen[x + 1][y].exist && !mapgen[x + 1][y - 1].exist && !mapgen[x][y - 1].exist:
					disabled_points.append(Vector2i(x + 1, y))
					disabled_points.append(Vector2i(x + 1, y - 1))
					disabled_points.append(Vector2i(x, y - 1))
					return true
				elif !mapgen[x - 1][y].exist && !mapgen[x - 1][y - 1].exist && !mapgen[x][y - 1].exist:
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x - 1, y - 1))
					disabled_points.append(Vector2i(x, y - 1))
					return true
				elif !mapgen[x + 1][y].exist && !mapgen[x - 1][y].exist:
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				else:
					return false
			## [x][x]   [x][x]   [x][x][x]
			## [x][o]   [o][x]   [x][o][x]   [x][o][x]
			## [x][x]   [x][x]               [x][x][x]
			else:
				if !mapgen[x][y + 1].exist && !mapgen[x - 1][y + 1].exist && !mapgen[x - 1][y - 1].exist && !mapgen[x][y - 1].exist && !mapgen[x - 1][y].exist:
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x - 1, y + 1))
					disabled_points.append(Vector2i(x - 1, y - 1))
					disabled_points.append(Vector2i(x, y - 1))
					disabled_points.append(Vector2i(x - 1, y))
					return true
				elif !mapgen[x][y + 1].exist && !mapgen[x + 1][y + 1].exist && !mapgen[x + 1][y - 1].exist && !mapgen[x][y - 1].exist && !mapgen[x + 1][y].exist:
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x + 1, y + 1))
					disabled_points.append(Vector2i(x + 1, y - 1))
					disabled_points.append(Vector2i(x, y - 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x - 1][y].exist && !mapgen[x - 1][y + 1].exist && !mapgen[x][y + 1].exist && !mapgen[x + 1][y + 1].exist  && !mapgen[x + 1][y].exist:
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x - 1, y + 1))
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x + 1, y + 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x - 1][y].exist && !mapgen[x - 1][y - 1].exist && !mapgen[x][y - 1].exist && !mapgen[x + 1][y - 1].exist  && !mapgen[x + 1][y].exist:
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x - 1, y - 1))
					disabled_points.append(Vector2i(x, y - 1))
					disabled_points.append(Vector2i(x + 1, y - 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				else:
					return false
		1: ## ROOM2 - hallway
			## |[o][x]  
			if x == 0:
				if !mapgen[x + 1][y].exist && !disabled_points.has(Vector2i(x + 1, y)):
					disabled_points.append(Vector2i(x + 1, y))
					return true
				else:
					return false
			## [x][o]|
			elif x == size_x - 1:
				if !mapgen[x - 1][y].exist && !disabled_points.has(Vector2i(x - 1, y)):
					disabled_points.append(Vector2i(x - 1, y))
					return true
				else:
					return false
			## [x]
			## [o]
			## ---
			elif y == 0:
				if !mapgen[x][y + 1].exist && !disabled_points.has(Vector2i(x, y + 1)):
					disabled_points.append(Vector2i(x, y + 1))
					return true
				else:
					return false
			## ---
			## [o]
			## [x]
			elif y == size_y - 1:
				if !mapgen[x][y - 1].exist && !disabled_points.has(Vector2i(x, y - 1)):
					disabled_points.append(Vector2i(x, y - 1))
					return true
				else:
					return false
			##             [x]
			## [x][o][x]   [o]
			##             [x]
			else:
				if !mapgen[x][y + 1].exist && !mapgen[x][y - 1].exist && !disabled_points.has(Vector2i(x, y + 1)) && !disabled_points.has(Vector2i(x, y - 1)):
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x, y - 1))
					return true
				elif !mapgen[x + 1][y].exist && !mapgen[x - 1][y].exist  && !disabled_points.has(Vector2i(x + 1, y)) && !disabled_points.has(Vector2i(x - 1, y)):
					disabled_points.append(Vector2i(x + 1, y))
					disabled_points.append(Vector2i(x - 1, y))
					return true
				else:
					return false
		2: ## ROOM2C - corner
			if (x == 0 && y == 0) || (x == size_x - 1 && y == size_y - 1) || (x == 0 && y == size_y - 1) || (x == size_x - 1 && y == 0):
				return true
			## |[x]  [x]|
			## |[o]  [o]|
			## |[x]  [x]|
			elif x == 0 || x == size_x - 1:
				if !mapgen[x][y + 1].exist && !mapgen[x][y - 1].exist && !disabled_points.has(Vector2i(x, y + 1)) && !disabled_points.has(Vector2i(x, y - 1)): 
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x, y - 1))
					return true
				else:
					return false
			## ---------
			## [x][o][x]   [x][o][x]
			##             ---------
			elif y == 0 || y == size_y - 1:
				if !mapgen[x + 1][y].exist && !mapgen[x - 1][y].exist && !disabled_points.has(Vector2i(x - 1, y)) && !disabled_points.has(Vector2i(x + 1, y)):
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				else:
					return false
			##                   [x][x]    [x][x]    
			## [x][o]   [o][x]   [x][o]    [o][x]
			## [x][x]   [x][x]
			else:
				if !mapgen[x - 1][y].exist && !mapgen[x - 1][y - 1].exist && !mapgen[x][y - 1].exist && !disabled_points.has(Vector2i(x - 1, y - 1)) && !disabled_points.has(Vector2i(x, y - 1)) && !disabled_points.has(Vector2i(x - 1, y)):
					disabled_points.append(Vector2i(x - 1, y - 1))
					disabled_points.append(Vector2i(x, y - 1))
					disabled_points.append(Vector2i(x - 1, y))
					return true
				elif !mapgen[x][y - 1].exist && !mapgen[x + 1][y - 1].exist && !mapgen[x + 1][y].exist && !disabled_points.has(Vector2i(x + 1, y - 1)) && !disabled_points.has(Vector2i(x, y - 1)) && !disabled_points.has(Vector2i(x + 1, y)):
					disabled_points.append(Vector2i(x + 1, y - 1))
					disabled_points.append(Vector2i(x, y - 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x - 1][y].exist && !mapgen[x - 1][y + 1].exist && !mapgen[x][y + 1].exist && !disabled_points.has(Vector2i(x - 1, y)) && !disabled_points.has(Vector2i(x - 1, y + 1)) && !disabled_points.has(Vector2i(x, y + 1)):
					disabled_points.append(Vector2i(x - 1, y))
					disabled_points.append(Vector2i(x - 1, y + 1))
					disabled_points.append(Vector2i(x, y + 1))
					return true
				elif !mapgen[x][y + 1].exist && !mapgen[x + 1][y + 1].exist && !mapgen[x + 1][y].exist && !disabled_points.has(Vector2i(x, y + 1)) && !disabled_points.has(Vector2i(x + 1, y + 1)) && !disabled_points.has(Vector2i(x + 1, y)):
					disabled_points.append(Vector2i(x, y + 1))
					disabled_points.append(Vector2i(x + 1, y + 1))
					disabled_points.append(Vector2i(x + 1, y))
					return true
				else:
					return false
		3: ## ROOM3 - TWay
			## |[o][x]  
			if x == 0 || y == 0 || x == size_x - 1 || y == size_y - 1:
				return true
			##                  [x]
			## [x][o]  [o][x]   [o]  [o]
			##                       [x]
			else:
				if !mapgen[x][y + 1].exist && !disabled_points.has(Vector2i(x, y + 1)):
					disabled_points.append(Vector2i(x, y + 1))
					return true
				elif !mapgen[x][y - 1].exist && !disabled_points.has(Vector2i(x, y - 1)):
					disabled_points.append(Vector2i(x, y - 1))
					return true
				elif !mapgen[x + 1][y].exist && !disabled_points.has(Vector2i(x + 1, y)):
					disabled_points.append(Vector2i(x + 1, y))
					return true
				elif !mapgen[x - 1][y].exist && !disabled_points.has(Vector2i(x - 1, y)):
					disabled_points.append(Vector2i(x - 1, y))
					return true
				else:
					return false
		_: ## ROOM4 and unknown types are not supported
			return false

## Main walker function, using AStarGrid2D
## infinite_gen "continues" generation at the end of chunk
func walk_astar(from: Vector2i, to: Vector2i, infinite_gen: bool = false) -> void:
	# Initialization
	var astar_grid: AStarGrid2D = AStarGrid2D.new()
	astar_grid.region = Rect2i(0, 0, size_x, size_y)
	astar_grid.cell_size = Vector2(1, 1)
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	for obstacle in disabled_points:
		astar_grid.set_point_solid(obstacle)
	var previous_map: Vector2i = from
	# Walk
	for map in astar_grid.get_point_path(from, to):
		# Get difference between previous and now position.
		# This is necessary for determining room connections
		var dir: Vector2i = Vector2i(map) - previous_map
		previous_map = map
		mapgen[map.x][map.y].exist = true
		
		match dir:
			Vector2i(1, 0):
				if mapgen[map.x - 1][map.y].exist:
					mapgen[map.x - 1][map.y].coordinate |= Room.Coordinates.EAST
					mapgen[map.x][map.y].coordinate |= Room.Coordinates.WEST
			Vector2i(-1, 0):
				if mapgen[map.x + 1][map.y].exist:
					mapgen[map.x + 1][map.y].coordinate |= Room.Coordinates.WEST
					mapgen[map.x][map.y].coordinate |= Room.Coordinates.EAST
			Vector2i(0, 1):
				if mapgen[map.x][map.y - 1].exist:
					mapgen[map.x][map.y - 1].coordinate |= Room.Coordinates.NORTH
					mapgen[map.x][map.y].coordinate |= Room.Coordinates.SOUTH
			Vector2i(0, -1):
				if mapgen[map.x][map.y + 1].exist:
					mapgen[map.x][map.y + 1].coordinate |= Room.Coordinates.SOUTH
					mapgen[map.x][map.y].coordinate |= Room.Coordinates.NORTH
			
		if infinite_gen:
			if map.x == to.x && map.y == to.y && map.x == zone_size - 1:
				mapgen[map.x][map.y].coordinate |= Room.Coordinates.EAST
			elif map.x == to.x && map.y == to.y && map.x == 0:
				mapgen[map.x][map.y].coordinate |= Room.Coordinates.WEST
			if map.x == to.x && map.y == to.y && map.y == zone_size - 1:
				mapgen[map.x][map.y].coordinate |= Room.Coordinates.NORTH
			elif map.x == to.x && map.y == to.y && map.y == 0:
				mapgen[map.x][map.y].coordinate |= Room.Coordinates.SOUTH
	endroom_amount += 1
## Places information about rooms
func place_room_positions() -> void:
	if debug_print:
		print("Map generated:")
		for j in range(size_x):
			var debug_string: String = ""
			for k in range(size_y):
				debug_string += str(int(mapgen[j][k].exist))
			print(debug_string)
		print("Connecting rooms...")
	var rooms_amount: Dictionary[String, PackedInt32Array] = {
	# single rooms
		"room1_amount": PackedInt32Array([0]),
		"room2_amount": PackedInt32Array([0]),
		"room2c_amount": PackedInt32Array([0]),
		"room3_amount": PackedInt32Array([0]),
		"room4_amount": PackedInt32Array([0]),
	# large rooms
		"room1l_amount": PackedInt32Array([0]),
		"room2l_amount": PackedInt32Array([0]),
		"room2cl_amount": PackedInt32Array([0]),
		"room3l_amount": PackedInt32Array([0]),
	# double rooms
		"room2d_amount": PackedInt32Array([0]),
		"room4d_amount": PackedInt32Array([0]),
		"room2cd_amount": PackedInt32Array([0]),
		"room3d_amount": PackedInt32Array([0])
	}
	
	var north: bool
	var east: bool
	var south: bool
	var west: bool
	
	var zone_counter: Vector2i = Vector2i.ZERO
	var room_index: int = 0
	var room_index_default: int = 0
	
	for l in range(size_x):
		#append zone horizontal
		if l >= size_x / (map_size_x + 1) * (zone_counter.x + 1):
			zone_counter.x += 1
			for key in rooms_amount:
				rooms_amount[key].append(0)
			room_index_default += 1
		for m in range(size_y):
			#append zone vertical
			if m >= size_y / (map_size_y + 1) * (zone_counter.y + 1):
				zone_counter.y += 1
				for key in rooms_amount:
					rooms_amount[key].append(0)
				room_index += 1
			
			if mapgen[l][m].exist:
				west = mapgen[l][m].coordinate & Room.Coordinates.WEST
				east = mapgen[l][m].coordinate & Room.Coordinates.EAST
				north = mapgen[l][m].coordinate & Room.Coordinates.NORTH
				south = mapgen[l][m].coordinate & Room.Coordinates.SOUTH
				if north && south:
					if east && west:
						#room4
						var room_angle: Array[float] = [0, 90, 180, 270]
						mapgen[l][m].room_type = RoomTypes.ROOM4
						mapgen[l][m].angle = room_angle[rng.randi_range(0, 3)]
						rooms_amount["room4_amount"][room_index] += 1
					elif east && !west:
						#room3, pointing east
						mapgen[l][m].room_type = RoomTypes.ROOM3
						mapgen[l][m].angle = 90
						if large_rooms:
							if check_room_dimensions(l, m, 3) && rooms_amount["room3l_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room3l_amount"][room_index] += 1
						rooms_amount["room3_amount"][room_index] += 1
					elif !east && west:
						#room3, pointing west
						mapgen[l][m].room_type = RoomTypes.ROOM3
						mapgen[l][m].angle = 270
						if large_rooms:
							if check_room_dimensions(l, m, 3) && rooms_amount["room3l_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room3l_amount"][room_index] += 1
						rooms_amount["room3_amount"][room_index] += 1
					else: #room2
						if m < size_y - 1 && m > 0:
							#upper checkpoint room2
							if m == size_y / (map_size_y + 1) * zone_counter.y && mapgen[l][m-1].exist && checkpoints_enabled:
								mapgen[l][m].checkpoint = true
								mapgen[l][m].angle = 180
							#lower checkpoint room2
							elif m == size_y / (map_size_y + 1) * (zone_counter.y + 1) - 1 && mapgen[l][m+1].exist && checkpoints_enabled:
								mapgen[l][m].checkpoint = true
								mapgen[l][m].angle = 0
							else: #generic vertical room2
								var room_angle: Array[float] = [0, 180]
								mapgen[l][m].angle = room_angle[rng.randi_range(0, 1)]
						#upper checkpoint room2
						elif m == 0 && infinite_generation && checkpoints_enabled:
							mapgen[l][m].checkpoint = true
							mapgen[l][m].angle = 180
						#lower checkpoint room2
						elif m == zone_size - 1 && infinite_generation && checkpoints_enabled:
							mapgen[l][m].checkpoint = true
							mapgen[l][m].angle = 0
						else: #generic vertical room2
							var room_angle: Array[float] = [0, 180]
							mapgen[l][m].angle = room_angle[rng.randi_range(0, 1)]
						mapgen[l][m].room_type = RoomTypes.ROOM2
						if large_rooms:
							if check_room_dimensions(l, m, 1) && rooms_amount["room2l_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room2l_amount"][room_index] += 1
						rooms_amount["room2_amount"][room_index] += 1
				elif east && west:
					if north && !south:
						#room3, pointing north
						mapgen[l][m].room_type = RoomTypes.ROOM3
						mapgen[l][m].angle = 0
						if large_rooms:
							if check_room_dimensions(l, m, 3) && rooms_amount["room3l_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room3l_amount"][room_index] += 1
						rooms_amount["room3_amount"][room_index] += 1
					elif !north && south:
					#room3, pointing south
						mapgen[l][m].room_type = RoomTypes.ROOM3
						mapgen[l][m].angle = 180
						if large_rooms:
							if check_room_dimensions(l, m, 3) && rooms_amount["room3l_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room3l_amount"][room_index] += 1
						rooms_amount["room3_amount"][room_index] += 1
					else:#room2
						if l < size_x - 1 && l > 0:
							#right checkpoint room2
							if l == size_x / (map_size_x + 1) * zone_counter.x && mapgen[l-1][m].exist && checkpoints_enabled:
								mapgen[l][m].checkpoint = true
								mapgen[l][m].angle = 270
							#left checkpoint room2
							elif l == size_x / (map_size_x + 1) * (zone_counter.x + 1) - 1 && mapgen[l+1][m].exist && checkpoints_enabled:
								mapgen[l][m].checkpoint = true
								mapgen[l][m].angle = 90
							else: #generic horizontal room2
								var room_angle: Array[float] = [90, 270]
								mapgen[l][m].angle = room_angle[rng.randi_range(0, 1)]
						#right checkpoint room2
						elif l == 0 && infinite_generation && checkpoints_enabled:
							mapgen[l][m].checkpoint = true
							mapgen[l][m].angle = 270
						#left checkpoint room2
						elif l == zone_size - 1 && infinite_generation && checkpoints_enabled:
							mapgen[l][m].checkpoint = true
							mapgen[l][m].angle = 90
						else: #generic horizontal room2
							var room_angle: Array[float] = [90, 270]
							mapgen[l][m].angle = room_angle[rng.randi_range(0, 1)]
						
						mapgen[l][m].room_type = RoomTypes.ROOM2
						
						if large_rooms:
							if check_room_dimensions(l, m, 1) && rooms_amount["room2l_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room2l_amount"][room_index] += 1
						rooms_amount["room2_amount"][room_index] += 1
				elif north:
					if east:
					#room2c, north-east
						mapgen[l][m].room_type = RoomTypes.ROOM2C
						mapgen[l][m].angle = 0
						if large_rooms:
							if check_room_dimensions(l, m, 2) && rooms_amount["room2cl_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room2cl_amount"][room_index] += 1
						rooms_amount["room2c_amount"][room_index] += 1
					elif west:
					#room2c, north-west
						mapgen[l][m].room_type = RoomTypes.ROOM2C
						mapgen[l][m].angle = 270
						if large_rooms:
							if check_room_dimensions(l, m, 2) && rooms_amount["room2cl_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room2cl_amount"][room_index] += 1
						rooms_amount["room2c_amount"][room_index] += 1
					else:
					#room1, north
						mapgen[l][m].room_type = RoomTypes.ROOM1
						mapgen[l][m].angle = 0
						rooms_amount["room1_amount"][room_index] += 1
				elif south:
					if east:
					#room2c, south-east
						mapgen[l][m].room_type = RoomTypes.ROOM2C
						mapgen[l][m].angle = 90
						if large_rooms:
							if check_room_dimensions(l, m, 2) && rooms_amount["room2cl_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room2cl_amount"][room_index] += 1
						rooms_amount["room2c_amount"][room_index] += 1
					elif west:
					#room2c, south-west
						mapgen[l][m].room_type = RoomTypes.ROOM2C
						mapgen[l][m].angle = 180
						if large_rooms:
							if check_room_dimensions(l, m, 2) && rooms_amount["room2cl_amount"][room_index] < zone_size / 6:
								mapgen[l][m].large = true
								rooms_amount["room2cl_amount"][room_index] += 1
						rooms_amount["room2c_amount"][room_index] += 1
					else:
					#room1, south
						mapgen[l][m].room_type = RoomTypes.ROOM1
						mapgen[l][m].angle = 180
						rooms_amount["room1_amount"][room_index] += 1
				elif east:
					#room1, east
					mapgen[l][m].room_type = RoomTypes.ROOM1
					mapgen[l][m].angle = 90
					rooms_amount["room1_amount"][room_index] += 1
				else:
					#room1, west
					mapgen[l][m].room_type = RoomTypes.ROOM1
					mapgen[l][m].angle = 270
					rooms_amount["room1_amount"][room_index] += 1
			if double_room_support:
				# If both rooms exist and not double - then they can be double
				if l > 0:
					detect_double_room(Vector2i(l, m), Vector2i(l-1, m), room_index, true)
				if l < size_x - 1:
					detect_double_room(Vector2i(l+1, m), Vector2i(l, m), room_index, true)
				if m > 0:
					detect_double_room(Vector2i(l, m), Vector2i(l, m-1), room_index, false)
				if m < size_y - 1:
					detect_double_room(Vector2i(l, m+1), Vector2i(l, m), room_index, false)
		zone_counter.y = 0
		room_index = room_index_default


## Detects double room (if Double room support is enabled)
func detect_double_room(first: Vector2i, second: Vector2i, zone: int, east_west: bool) -> void:
	# First check - if room exists, is not a double room, is in right coordinate and not a checkpoint - proceed.
	if mapgen[first.x][first.y].exist && mapgen[second.x][second.y].exist &&\
	  mapgen[first.x][first.y].double_room == DoubleRoomTypes.NONE && mapgen[second.x][second.y].double_room == DoubleRoomTypes.NONE &&\
	  !mapgen[first.x][first.y].checkpoint && !mapgen[second.x][second.y].checkpoint && \
	  
 	  (mapgen[first.x][first.y].coordinate & Room.Coordinates.EAST) && (mapgen[second.x][second.y].coordinate & Room.Coordinates.WEST) \
	   if east_west else \
	  (mapgen[first.x][first.y].coordinate & Room.Coordinates.NORTH) && (mapgen[second.x][second.y].coordinate & Room.Coordinates.SOUTH):
		for shape in rooms[zone].double_rooms:
			# If it is ROOM2D
			if mapgen[first.x][first.y].room_type == mapgen[second.x][second.y].room_type && \
			  shape[0].double_room_shape == shape[1].double_room_shape && \
			  mapgen[first.x][first.y].room_type == RoomTypes.ROOM2 && shape[0].double_room_shape == DoubleRoomTypes.ROOM2D:
				mapgen[first.x][first.y].resource = shape[0]
				mapgen[first.x][first.y].double_room = DoubleRoomTypes.ROOM2D
				match mapgen[first.x][first.y].angle:
					0.0:
						mapgen[first.x][first.y].angle = 180.0
						mapgen[second.x][second.y].angle = 180.0
					90.0:
						mapgen[first.x][first.y].angle = 270.0
						mapgen[second.x][second.y].angle = 270.0
					180.0:
						mapgen[first.x][first.y].angle = 180.0
						mapgen[second.x][second.y].angle = 180.0
					270.0:
						mapgen[first.x][first.y].angle = 270.0
						mapgen[second.x][second.y].angle = 270.0
				mapgen[second.x][second.y].double_room = DoubleRoomTypes.ROOM2D
				mapgen[second.x][second.y].resource = shape[1]
				rooms[zone].double_rooms.erase(shape)
			# Other cases.
			elif mapgen[first.x][first.y].room_type == shape[0].double_room_shape && \
			  is_equal_approx(abs(mapgen[first.x][first.y].angle - mapgen[second.x][second.y].angle), abs(DOUBLE_ROOM_ROTATIONS[shape[0].double_room_rotation] - DOUBLE_ROOM_ROTATIONS[shape[1].double_room_rotation])) && \
			  mapgen[second.x][second.y].room_type == shape[1].double_room_shape:
				mapgen[first.x][first.y].resource = shape[0]
				mapgen[first.x][first.y].double_room = shape[0].double_room_shape
				mapgen[second.x][second.y].resource = shape[1]
				mapgen[second.x][second.y].double_room = shape[1].double_room_shape
				rooms[zone].double_rooms.erase(shape)
