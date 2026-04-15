@icon("res://MapGen/icons/MapGenNode.svg")
extends RefCounted
## Base of map generator backends
class_name MapGenCore

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

enum RoomTypes {EMPTY, ROOM1, ROOM2, ROOM2C, ROOM3, ROOM4}

enum DoubleRoomTypes {NONE, ROOM2D = 2, ROOM2CD = 3, ROOM3D = 4, ROOM4D = 5}


@export var rng_seed: int = -1:
	set(val):
		if rng_seed != -1:
			rng.seed = rng_seed
## Rooms that will be used
@export var rooms: Array[MapGenZone]
## Zone size (values before 8 NOT recommended, may lead to unexpected behavior)
@export_range(8, 256, 2) var zone_size: int = 8
## Amount of zones by X coordinate
@export_range(0, 3) var map_size_x: int = 0
## Amount of zones by Y coordinate
@export_range(0, 3) var map_size_y: int = 0
## Large rooms support
@export var large_rooms: bool = false
## How much the map will be filled with rooms
@export_range(0.25, 1) var room_amount: float = 0.75
# Sets the door generation. Not recommended to disable, if your map uses SCP:SL 14.0-like door frames!
#@export var enable_door_generation: bool = true
## Better zone generation.
## Sometimes, the generation will return "dull" path(e.g where there are only 3 ways to go)
## This fixes these generations, at a little cost of generation time
## If infinite generator is used, this option also
## places random "disabled points", so Room2C can spawn
@export var better_zone_generation: bool = true
## How many additional rooms should spawn map generator
## /!\ WARNING! Higher value may hang the game.
@export_range(0, 5) var better_zone_generation_min_amount: int = 4
## Enable checkpoint rooms.
## /!\ WARNING! The checkpoint room behaves differently, than SCP-CB checkpoints,
## the "checkpoint" have 2 rooms, not one (as in SCP-CB).
@export var checkpoints_enabled: bool = false
## Prints map seed
@export var debug_print: bool = false
## Enable double rooms support (single rooms only). Available since mapgen v9.
@export var double_room_support: bool = false
## Amount of single large endrooms in all zones
@export var endrooms_single_large_amount: PackedInt32Array = PackedInt32Array()
## Infinite generation is actually limited only by Godot's floating point errors
## DO NOT SET THIS PROPERTY MANUALLY, IT IS AUTOMATIC.
var infinite_generation: bool = false

var mapgen: Array[Array] = []
## Cells, where a room will never spawn due to large room overriden
var disabled_points: Array[Vector2i] = []

class Room:
	
	enum Coordinates {
		NORTH = 1 << 0,
		SOUTH = 1 << 1,
		EAST = 1 << 2,
		WEST = 1 << 3
	}
	
	# north, east, west and south check the connection between rooms.
	var exist: bool
	var coordinate: int
	#var north: bool
	#var south: bool
	#var east: bool
	#var west: bool
	var room_type: RoomTypes
	var angle: float
	var large: bool
	var resource: MapGenRoom
	var room_name: String
	var checkpoint: bool
	var double_room: DoubleRoomTypes
	
	func _init() -> void:
		exist = false
		coordinate = 0
		#north = false
		#south = false
		#east = false
		#west = false
		room_type = RoomTypes.EMPTY
		angle = -1
		large = false
		checkpoint = false
		double_room = DoubleRoomTypes.NONE

var size_x: int
var size_y: int

var endroom_amount: int = 0

## First array is actually a container, second is zone, third is type container.
## Structure is like: [[[DoubleRoomTypes, DoubleRoomTypes]]] (since enum is actually named int)
var double_room_shapes: Array[Array]

## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#pass
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

func start_generation() -> void:
	pass

## Clears the map generation
func clear() -> void:
	if debug_print:
		print("Clearing the map...")
	disabled_points.clear()
	mapgen.clear()
	size_x = 0
	size_y = 0
