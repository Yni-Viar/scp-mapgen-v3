@icon("res://MapGen/icons/MapGenInfinite3D.svg")
extends Node3D
## Infinite map generator frontend
class_name FacilityGeneratorInfinite3D

signal generated
signal generated_first_time
signal unloaded
signal parameter_changed

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var mapgen_core: MapGenAStar = MapGenAStar.new()

enum RoomTypes {EMPTY, ROOM1, ROOM2, ROOM2C, ROOM3, ROOM4}

@export var rng_seed: int = -1:
	set(val):
		rng_seed = val
		parameter_changed.emit()
## Rooms that will be used
@export var rooms: Array[MapGenZone]
## Zone size
@export_range(8, 256, 2) var zone_size: int = 8:
	set(val):
		zone_size = val
		parameter_changed.emit()
## Room in grid size
@export var grid_size: float = 20.48
## How much the map will be filled with rooms
@export_range(0.25, 1) var room_amount: float = 0.75:
	set(val):
		room_amount = val
		parameter_changed.emit()
## Sets the door generation. Not recommended to disable, if your map uses SCP:SL 14.0-like door frames!
#@export var enable_door_generation: bool = true
## Better zone generation.
## Sometimes, the generation will return "dull" path(e.g where there are only 3 ways to go)
## This fixes these generations, at a little cost of generation time
@export var better_zone_generation: bool = true:
	set(val):
		better_zone_generation = val
		parameter_changed.emit()
## How many additional rooms should spawn map generator
## /!\ WARNING! Higher value may hang the game.
@export_range(0, 5) var better_zone_generation_min_amount: int = 4:
	set(val):
		better_zone_generation_min_amount = val
		parameter_changed.emit()
## Enable checkpoint rooms.
## /!\ WARNING! The checkpoint room behaves differently, than SCP - Cont. Breach checkpoints,
## they behave like SCP: Secret Lab. HCZ-EZ checkpoints, with two rooms.
@export var checkpoints_enabled: bool = false:
	set(val):
		checkpoints_enabled = val
		parameter_changed.emit()
## Prints map seed
@export var debug_print: bool = false:
	set(val):
		debug_print = val
		parameter_changed.emit()
## Enable double rooms support (single rooms only). Available since mapgen v9.
@export var double_room_support: bool = false:
	set(val):
		double_room_support = val
		parameter_changed.emit()
@export_group("External loading settings")
## Setting to optimize GLTF loading. Is not necessary for map generation
@export var use_gltf_optimizator = false

var mapgen: Array[Array] = []

var chunk: Vector2i = Vector2i(0, 0)

var size_x: int
var size_y: int

var first_time: bool = true

var rooms_are_generated: bool = false

## First array is actually a container, second is zone, third is type container.
## Structure is like: [[[DoubleRoomTypes, DoubleRoomTypes]]] (since enum is actually named int)
var double_room_shapes: Array[Array]

var room_count: Dictionary[String, PackedInt32Array] = {
# single rooms
	"room1_count": PackedInt32Array([0]),
	"room2_count": PackedInt32Array([0]),
	"room2c_count": PackedInt32Array([0]),
	"room3_count": PackedInt32Array([0]),
	"room4_count": PackedInt32Array([0]),
# large rooms
	"room1l_count": PackedInt32Array([0]),
	"room2l_count": PackedInt32Array([0]),
	"room2cl_count": PackedInt32Array([0]),
	"room3l_count": PackedInt32Array([0]),
# double rooms
	"room2d_count": PackedInt32Array([0]),
	"room4d_count": PackedInt32Array([0]),
	"room2cd_count": PackedInt32Array([0]),
	"room3d_count": PackedInt32Array([0])
}

var unused_rooms: Array[MapGenZone]

var cached_scenes: Dictionary[String, PackedScene]

# temporary variables
var selected_room: PackedScene
var room: Node3D
var zone_index: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# We'll create chunk loading/unloading via Area3D
	# It is for optimization
	var chunk_area: Area3D = Area3D.new()
	# customize detection types here
	add_child(chunk_area)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	var collider_size_x: float = zone_size * grid_size + float(zone_size) / 2 * grid_size
	var collider_size_y: float = zone_size * grid_size + float(zone_size) / 2 * grid_size
	collider.shape.size = Vector3(collider_size_x, zone_size * grid_size + float(zone_size) / 2 * grid_size, collider_size_y)
	chunk_area.add_child(collider)
	chunk_area.position = Vector3(float(zone_size) / 2 * grid_size, 0, float(zone_size) / 2 * grid_size)
	chunk_area.body_entered.connect(_on_optimizator_body_entered)
	chunk_area.body_exited.connect(_on_optimizator_body_exited)
	parameter_changed.connect(refresh_mapgen)
	refresh_mapgen()
	if get_parent() is MapGenInfinite3D:
		if !get_parent().loaded_chunks.has(chunk):
			get_parent().loaded_chunks[chunk] = rng.seed
		rng_seed = get_parent().loaded_chunks[chunk]

func refresh_mapgen():
	mapgen_core.rng = rng
	mapgen_core.zone_size = zone_size
	mapgen_core.map_size_x = 0
	mapgen_core.map_size_y = 0
	mapgen_core.large_rooms = false
	mapgen_core.room_amount = room_amount
	mapgen_core.better_zone_generation = better_zone_generation
	mapgen_core.better_zone_generation_min_amount = better_zone_generation_min_amount
	mapgen_core.checkpoints_enabled = checkpoints_enabled
	mapgen_core.debug_print = debug_print
	mapgen_core.double_room_support = double_room_support

func generate_rooms() -> void:
	clear()
	if rng_seed != -1:
		rng.seed = rng_seed
	if rooms == null || rooms.size() == 0:
		printerr("There are no zones, cannot spawn.")
		return
	size_x = zone_size
	size_y = zone_size
	# Initialize, what double room shapes are being used
	if double_room_support:
		for i in range(rooms.size()):
			double_room_shapes.append([])
			for double_rooms in rooms[i].double_rooms:
				if double_rooms[0] is MapGenRoom && double_rooms[1] is MapGenRoom:
					double_room_shapes[i].append([double_rooms[0], double_rooms[1]])
	mapgen_core.infinite_generation = true
	mapgen_core.double_room_shapes = double_room_shapes
	mapgen_core.start_generation()
	mapgen = mapgen_core.mapgen
	rng.seed = mapgen_core.rng.seed
	zone_index = rng.randi_range(0, rooms.size() - 1)
	spawn_rooms()

## Spawns room prefab on the grid
func spawn_rooms() -> void:
	if debug_print:
		print("Spawning rooms...")
	unused_rooms.resize(rooms.size())
	for i in range(unused_rooms.size()):
		for key in room_count:
			room_count[key].append(0)
		unused_rooms[i] = rooms[i].duplicate(true)
	# Checks the zone
	var zone_counter: Vector2i = Vector2i.ZERO
	#spawn a room
	for n in range(size_x):
		for o in range(size_y):
			match mapgen[n][o].room_type:
				RoomTypes.ROOM1:
					room_select(RoomTypes.ROOM1, zone_index, n, o)
					
					add_room_to_the_map(n, o)
				RoomTypes.ROOM2:
					if checkpoints_enabled && mapgen[n][o].checkpoint:
						# Checkpoint room spawn
						mapgen[n][o].resource = rooms[zone_index].checkpoint_hallway[rng.randi_range(0, rooms[zone_index].checkpoint_hallway.size() - 1)]
						selected_room = rooms[zone_index].checkpoint_hallway[rng.randi_range(0, rooms[zone_index].checkpoint_hallway.size() - 1)].prefab
						room_count["room2_count"][zone_index] += 1
					elif mapgen[n][o].double_room == MapGenCore.DoubleRoomTypes.ROOM2D && double_room_support:
						var coincidence: bool = false
						# Double room.
						# At first, we spawn mirror room, next we spawn original room.
						for shape in double_room_shapes[zone_index]:
							if shape[0].double_room_shape == MapGenCore.DoubleRoomTypes.ROOM2D:
								mapgen[n][o].resource = shape[0].duplicate()
								#var double_2d: bool = false
								#var opposite_angle: float = 0.0
								if n < size_x - 1 && mapgen[n+1][o].double_room == shape[1].double_room_shape && \
								mapgen[n][o].west && mapgen[n+1][o].east:
									mapgen[n+1][o].resource = shape[1].duplicate()
									selected_room = mapgen[n+1][o].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3((n + 1) * grid_size, 0, o * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n+1][o].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n+1][o].room_name = mapgen[n+1][o].resource.name
									
									coincidence = true
								if o < size_y - 1 && mapgen[n][o+1].double_room == shape[1].double_room_shape && \
								mapgen[n][o].north && mapgen[n][o+1].south:
									mapgen[n][o+1].resource = shape[1].duplicate()
									selected_room = mapgen[n][o+1].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3(n * grid_size, 0, (o + 1) * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n][o+1].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n][o+1].room_name = room.name
									
									coincidence = true
								if coincidence:
									selected_room = mapgen[n][o].resource.prefab
									
									add_room_to_the_map(n, o)
									
									room_count["room2d_count"][zone_index] += 1
									double_room_shapes[zone_index].erase(shape)
									break
						if !coincidence:
							room_select(RoomTypes.ROOM2, zone_index, n, o)
						else:
							continue
					else:
						room_select(RoomTypes.ROOM2, zone_index, n, o)
					
					add_room_to_the_map(n, o)
				RoomTypes.ROOM2C:
					if mapgen[n][o].double_room == MapGenCore.DoubleRoomTypes.ROOM2CD && double_room_support:
						var coincidence: bool = false
						# Double room.
						# At first, we spawn mirror room, next we spawn original room.
						for shape in double_room_shapes[zone_index]:
							if shape[0].double_room_shape == MapGenCore.DoubleRoomTypes.ROOM2CD:
								mapgen[n][o].resource = shape[0].duplicate()
								if n < size_x - 1 && mapgen[n+1][o].double_room == shape[1].double_room_shape && \
								  mapgen[n+1][o].angle in [90.0, 180.0]:
									mapgen[n+1][o].resource = shape[1].duplicate()
									selected_room = mapgen[n+1][o].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3((n + 1) * grid_size, 0, o * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n+1][o].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n+1][o].room_name = mapgen[n+1][o].resource.name
									
									coincidence = true
								if o < size_y - 1 && mapgen[n][o+1].double_room == shape[1].double_room_shape && \
								  mapgen[n][o+1].angle in [90.0, 180.0]:
									mapgen[n][o+1].resource = shape[1].duplicate()
									selected_room = mapgen[n][o+1].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3(n * grid_size, 0, (o + 1) * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n][o+1].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n][o+1].room_name = mapgen[n][o+1].resource.name
									coincidence = true
								if coincidence:
									selected_room = mapgen[n][o].resource.prefab
									
									add_room_to_the_map(n, o)
									room_count["room2cd_count"][zone_index] += 1
									double_room_shapes[zone_index].erase(shape)
									
									break
						if !coincidence:
							room_select(RoomTypes.ROOM2C, zone_index, n, o)
						else:
							continue
					else:
						room_select(RoomTypes.ROOM2C, zone_index, n, o)
					
					add_room_to_the_map(n, o)
				RoomTypes.ROOM3:
					if mapgen[n][o].double_room == MapGenCore.DoubleRoomTypes.ROOM3D && double_room_support:
						var coincidence: bool = false
						# Double room.
						# At first, we spawn mirror room, next we spawn original room.
						for shape in double_room_shapes[zone_index]:
							if shape[0].double_room_shape == MapGenCore.DoubleRoomTypes.ROOM3D:
								mapgen[n][o].resource = shape[0].duplicate()
								if n < size_x - 1 && mapgen[n+1][o].double_room == shape[1].double_room_shape && \
								  mapgen[n+1][o].angle == mapgen[n][o].angle:
									mapgen[n+1][o].resource = shape[1].duplicate()
									selected_room = mapgen[n+1][o].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3((n + 1) * grid_size, 0, o * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n+1][o].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n+1][o].room_name = mapgen[n+1][o].resource.name
									coincidence = true
								if o < size_y - 1 && mapgen[n][o+1].double_room == shape[1].double_room_shape && \
								  abs(mapgen[n][o+1].angle - mapgen[n][o].angle) == 90.0:
									mapgen[n][o+1].resource = shape[1].duplicate()
									selected_room = mapgen[n][o+1].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3(n * grid_size, 0, (o + 1) * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n][o+1].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n][o+1].room_name = mapgen[n][o+1].resource.name
									coincidence = true
								if coincidence:
									selected_room = mapgen[n][o].resource.prefab
									
									add_room_to_the_map(n, o)
									room_count["room3d_count"][zone_index] += 1
									double_room_shapes[zone_index].erase(shape)
									break
						if !coincidence:
							room_select(RoomTypes.ROOM3, zone_index, n, o)
						else:
							continue
					else:
						room_select(RoomTypes.ROOM3, zone_index, n, o)
					
					add_room_to_the_map(n, o)
				RoomTypes.ROOM4:
					if mapgen[n][o].double_room == MapGenCore.DoubleRoomTypes.ROOM4D && double_room_support:
						var coincidence: bool = false
						# Double room.
						# At first, we spawn mirror room, next we spawn original room.
						for shape in double_room_shapes[zone_index]:
							if shape[0].double_room_shape == MapGenCore.DoubleRoomTypes.ROOM4D:
								mapgen[n][o].resource = shape[0].duplicate()
								#var double_4d: bool = false
								#var opposite_angle: float = 0.0
								if n < size_x - 1 && mapgen[n+1][o].double_room == shape[1].double_room_shape:
									mapgen[n+1][o].resource = shape[1].duplicate()
									selected_room = mapgen[n+1][o].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3((n + 1) * grid_size, 0, o * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n+1][o].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n+1][o].room_name = mapgen[n+1][o].resource.name
									coincidence = true
								if o < size_y - 1 && mapgen[n][o+1].double_room == shape[1].double_room_shape:
									mapgen[n][o+1].resource = shape[1].duplicate()
									selected_room = mapgen[n][o+1].resource.prefab
									
									if selected_room != null:
										room = selected_room.instantiate()
									elif selected_room == null && (mapgen[n][o].resource.gltf_path != null || !mapgen[n][o].resource.gltf_path.is_empty()):
										room = load_gltf(mapgen[n][o].resource.gltf_path)
									else:
										printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
										return
									
									room.position = Vector3(n * grid_size, 0, (o + 1) * grid_size)
									room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[n][o+1].angle, room.rotation_degrees.z)
									add_child(room)
									mapgen[n][o+1].room_name = mapgen[n][o+1].resource.name
									coincidence = true
								if coincidence:
									selected_room = mapgen[n][o].resource.prefab
									
									add_room_to_the_map(n, o)
									room_count["room4d_count"][zone_index] += 1
									double_room_shapes[zone_index].erase(shape)
									break
						
						if !coincidence:
							room_select(RoomTypes.ROOM4,  zone_index, n, o)
						else:
							continue
					else:
						room_select(RoomTypes.ROOM4, zone_index, n, o)
					
					add_room_to_the_map(n, o)
	#if enable_door_generation:
		#spawn_doors()
	if first_time:
		generated_first_time.emit()
		first_time = false
	unused_rooms.clear()
	cached_scenes.clear()
	generated.emit()
	rooms_are_generated = true

func add_room_to_the_map(x: int, y: int) -> void:
	if !mapgen[x][y].room_name.is_empty():
		return
	if selected_room != null:
		room = selected_room.instantiate()
	elif selected_room == null && (mapgen[x][y].resource.gltf_path != null || !mapgen[x][y].resource.gltf_path.is_empty()):
		room = load_gltf(mapgen[x][y].resource.gltf_path)
	else:
		printerr("No PackedScene or GLTF path are valid. Stopping map generator.")
		return
	
	room.position = Vector3(x * grid_size, 0, y * grid_size)
	room.rotation_degrees = Vector3(room.rotation_degrees.x, mapgen[x][y].angle, room.rotation_degrees.z)
	add_child(room)
	mapgen[x][y].room_name = mapgen[x][y].resource.name

func room_select(type: RoomTypes, zone_index: int, n: int, o: int) -> void:
	match type:
		RoomTypes.ROOM1:
			var room_data: MapGenRoom = random_room_with_chance(unused_rooms[zone_index].endrooms)
			# Generic room spawn
			mapgen[n][o].resource = room_data
			selected_room = room_data.prefab
		RoomTypes.ROOM2:
			var room_data: MapGenRoom = random_room_with_chance(unused_rooms[zone_index].hallways)
			# Generic room spawn
			mapgen[n][o].resource = room_data
			selected_room = mapgen[n][o].resource.prefab
		RoomTypes.ROOM2C:
			var room_data: MapGenRoom = random_room_with_chance(unused_rooms[zone_index].corners)
			# Generic room spawn
			mapgen[n][o].resource = room_data
			selected_room = mapgen[n][o].resource.prefab
		RoomTypes.ROOM3:
			var room_data: MapGenRoom = random_room_with_chance(unused_rooms[zone_index].trooms)
			# Generic room spawn
			mapgen[n][o].resource = room_data
			selected_room = mapgen[n][o].resource.prefab
		RoomTypes.ROOM4:
			var room_data: MapGenRoom = random_room_with_chance(unused_rooms[zone_index].crossrooms)
			# Generic room spawn
			mapgen[n][o].resource = room_data
			selected_room = mapgen[n][o].resource.prefab

## Returns random room, depending on chance
func random_room_with_chance(rooms_pack: Array[MapGenRoom]) -> MapGenRoom:
	var counter: float = 0.0
	var prev_counter: float = 0.0
	var room_res: MapGenRoom
	var all_spawn_chances: Array[float] = []
	var spawn_chances: float = 0
	for j in range(rooms_pack.size()):
		if j >= rooms_pack.size():
			break
		#if single && rooms_pack[j].guaranteed_spawn:
			#room = rooms_pack[j]
			#break
		all_spawn_chances.append(rooms_pack[j].spawn_chance)
		spawn_chances += rooms_pack[j].spawn_chance
	var random_room: float = rng.randf_range(0.0, spawn_chances)
	for i in range(all_spawn_chances.size()):
		counter += all_spawn_chances[i]
		if (random_room < counter && random_room >= prev_counter) || i == all_spawn_chances.size() - 1:
			room_res = rooms_pack[i]
			break
		prev_counter = counter
	all_spawn_chances.clear()
	counter = 0
	prev_counter = 0
	#if single:
		#rooms_pack.erase(room_res)
	return room_res

## Spawn doors
#func spawn_doors() -> void:
	#if debug_print:
		#print("Spawning doors...")
	## Checks the zone
	#const zone_index: int = 0
	#var zone_counter: Vector2i = Vector2i.ZERO
	#var zone_index_default: int = 0
	#var startup_node: Node = Node.new()
	#startup_node.name = "DoorFrames"
	#add_child(startup_node)
	#for i in range(size_x):
		#if i >= size_x / (map_size_x + 1) * (zone_counter.x + 1) - 1:
			#if checkpoints_enabled && rooms[zone_index].door_frames.size() > 0:
				#for k in range(size_y):
					#if mapgen[i][k].east:
						#var door: Node3D = rooms[zone_index].checkpoint_door_frames[rng.randi_range(0, rooms[zone_index].checkpoint_door_frames.size() - 1)].instantiate()
						#door.position = global_position + Vector3(i * grid_size + grid_size / 2, 0, k * grid_size)
						#door.rotation_degrees = Vector3(0, 0, 0)
						#startup_node.add_child(door, true)
			#zone_counter.x += 1
			#zone_index_default += map_size_y + 1
		#for j in range(size_y):
			#if j >= size_y / (map_size_y + 1) * (zone_counter.y + 1) - 1:
				#if checkpoints_enabled && rooms[zone_index].door_frames.size() > 0:
					#if mapgen[i][j].north:
						#var door: Node3D = rooms[zone_index].checkpoint_door_frames[rng.randi_range(0, rooms[zone_index].checkpoint_door_frames.size() - 1)].instantiate()
						#door.position = global_position + Vector3(i * grid_size, 0, j * grid_size + grid_size / 2)
						#door.rotation_degrees = Vector3(0, 0, 0)
						#startup_node.add_child(door, true)
				#zone_counter.y += 1
				#zone_index += 1
			#elif rooms[zone_index].door_frames.size() > 0:
				#var available_frames: Array[PackedScene] = rooms[zone_index].door_frames
				#if mapgen[i][j].east:
					#var door: Node3D
					#if mapgen[i+1][j].double_room && mapgen[i][j].double_room:
						#continue
					#if mapgen[i+1][j].resource.door_type >= 0: # Spawn specific door frame
						#door = available_frames[mapgen[i+1][j].resource.door_type].instantiate()
					#elif mapgen[i][j].resource.door_type >= 0:
						#door = available_frames[mapgen[i][j].resource.door_type].instantiate()
					#else: # Spawn random door frame
						#door = available_frames[rng.randi_range(0, available_frames.size() - 1)].instantiate()
					#if door != null:
						#door.position = global_position + Vector3(i * grid_size + grid_size / 2, 0, j * grid_size)
						#door.rotation_degrees = Vector3(0, 90, 0)
						#startup_node.add_child(door, true)
				#if mapgen[i][j].north:
					#var door: Node3D
					#if mapgen[i][j+1].double_room && mapgen[i][j].double_room:
						#continue
					#if mapgen[i][j+1].resource.door_type >= 0: # Spawn specific door frame
						#door = available_frames[mapgen[i][j+1].resource.door_type].instantiate()
					#elif mapgen[i][j].resource.door_type >= 0:
						#door = available_frames[mapgen[i][j].resource.door_type].instantiate()
					#else: # Spawn random door frame
						#door = available_frames[rng.randi_range(0, available_frames.size() - 1)].instantiate()
					#if door != null:
						#door.position = global_position + Vector3(i * grid_size, 0, j * grid_size + grid_size / 2)
						#door.rotation_degrees = Vector3(0, 0, 0)
						#startup_node.add_child(door, true)
		#zone_index = zone_index_default
		#zone_counter.y = 0

## Clears the map generation
func clear():
	mapgen.clear()
	size_x = 0
	size_y = 0
	for key in room_count:
		room_count[key] = PackedInt32Array([0])
	for node in get_children():
		if node is Area3D:
			continue
		node.queue_free()
	unloaded.emit()
	rooms_are_generated = false

func _on_optimizator_body_entered(body: Node3D):
	if body is CharacterBody3D:
		if !rooms_are_generated:
			generate_rooms()
			var new_chunks: Array[Vector2i] = [Vector2i(chunk.x - 1, chunk.y - 1), Vector2i(chunk.x - 1, chunk.y), Vector2i(chunk.x - 1, chunk.y + 1), \
				Vector2i(chunk.x, chunk.y - 1), Vector2i(chunk.x, chunk.y + 1), \
				Vector2i(chunk.x + 1, chunk.y - 1), Vector2i(chunk.x + 1, chunk.y), Vector2i(chunk.x + 1, chunk.y + 1)
			]
			if get_parent() is MapGenInfinite3D:
				for chunk_pos in new_chunks:
					if get_parent().loaded_chunks.has(chunk_pos):
						#get_parent().loaded_chunks[chunk_pos] = rng.seed + int(sin(deg_to_rad(chunk_pos.x)) * 100) + int(cos(deg_to_rad(chunk_pos.y)) * 100)
					#else:
						continue
					var facility_generator: FacilityGeneratorInfinite3D = FacilityGeneratorInfinite3D.new()
					facility_generator.chunk = chunk_pos
					facility_generator.rooms = rooms
					facility_generator.zone_size = zone_size
					facility_generator.grid_size = grid_size
					facility_generator.position = Vector3(zone_size * grid_size * chunk_pos.x, 0, zone_size * grid_size * chunk_pos.y)
					facility_generator.room_amount = room_amount
					#facility_generator.enable_door_generation = false
					facility_generator.better_zone_generation = better_zone_generation
					facility_generator.better_zone_generation_min_amount = better_zone_generation_min_amount
					facility_generator.checkpoints_enabled = checkpoints_enabled
					facility_generator.debug_print = debug_print
					facility_generator.double_room_support = double_room_support
					facility_generator.double_room_shapes = double_room_shapes
					facility_generator.mapgen = mapgen
					get_parent().add_child(facility_generator)

func _on_optimizator_body_exited(body: Node3D):
	if body is CharacterBody3D:
		if rooms_are_generated:
			clear()

func load_gltf(path: String) -> Node3D:
	if cached_scenes.has(path):
		return cached_scenes[path].instantiate()
	var gltf_document_load = GLTFDocument.new()
	var gltf_state_load = GLTFState.new()
	var error = gltf_document_load.append_from_file(path, gltf_state_load)
	if error == OK:
		var gltf_scene_root_node = gltf_document_load.generate_scene(gltf_state_load)
		var packed_scene:PackedScene = PackedScene.new()
		packed_scene.pack(gltf_scene_root_node)
		#if !DirAccess.dir_exists_absolute("user://temporary_scenes/"):
			#DirAccess.make_dir_absolute("user://temporary_scenes/")
		#ResourceSaver.save(packed_scene, "user://temporary_scenes/" + path.get_file().split(".")[0] + ".tscn")
		cached_scenes[path] = packed_scene
		return gltf_scene_root_node
	else:
		return null

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			for key in cached_scenes:
				cached_scenes.clear()
