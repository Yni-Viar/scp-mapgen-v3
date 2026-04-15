@icon("res://MapGen/icons/MapGenNode.svg")
extends MapGenCore
## Layout map generator backend
class_name MapGenLayout

## Works only if there are large endrooms, to prevent endless loop if cannot spawn
const NUMBER_OF_TRIES_TO_SPAWN: int = 4
## For performance reasons. Correct the code to increase the limit
const MAX_ROOMS_SPAWN: int = 512

## Layout images (format: Array[Array[Texture2D]])
@export var layout_images: Array[Array] = []

## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#pass
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

func start_generation() -> void:
	clear()
	#prepare_generation()
	layout_generator()

## Basic layout generator
func layout_generator():
	var image_dimension: int = 8
	var rand_images: Array[Image] = []
	rand_images.resize(map_size_y + 1)
	var zone_edges: Array[Rect2i] = []
	zone_edges.resize(map_size_y + 1)
	size_x = image_dimension
	size_y = image_dimension * (map_size_y + 1)
	for h in range(map_size_y + 1):
		var rand_image: Image = layout_images[h][rng.randi_range(0, layout_images[h].size() - 1)].get_image()
		var image_size: Vector2i = rand_image.get_size()
		if image_size != Vector2i(image_dimension, image_dimension):
			printerr("Mismatching size of images. Cannot generate. Make sure, that all layouts size is equal.")
			return
		rand_images[h] = rand_image
		# We calculate top left point of the image
		zone_edges[h] = Rect2i(Vector2i(size_x * h, 0), image_size)
	
	if debug_print:
		print("Preparing generation...")
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
	var position_y: Vector2i = Vector2i(0, image_dimension)
	for k in range(map_size_y + 1):
		for i in range(0, image_dimension):
			for j in range(position_y.x, position_y.y):
				match rand_images[k].get_pixel(i, j % 8).to_html(false):
					"004000": #Green zone, endrooms
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM1
						mapgen[i][j].angle = 0
					"008000":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM1
						mapgen[i][j].angle = 90
					"00c000":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM1
						mapgen[i][j].angle = 180
					"00ff00":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM1
						mapgen[i][j].angle = 270
					"808000": #Yellow zone, hallways
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM2
						var test = j % image_dimension
						#upper checkpoint room2
						if j % image_dimension == 0 && checkpoints_enabled:
							mapgen[i][j].checkpoint = true
							mapgen[i][j].angle = 180
						#lower checkpoint room2
						elif j % image_dimension == image_dimension - 1 && checkpoints_enabled:
							mapgen[i][j].checkpoint = true
							mapgen[i][j].angle = 0
						else: #generic vertical room2
							mapgen[i][j].angle = 0 if randi_range(0, 1) != 1 else 180
					"ffff00":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM2
						mapgen[i][j].angle = 90 if randi_range(0, 1) != 1 else 270
					"ff0000": #Red zone, curves
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM2C
						mapgen[i][j].angle = 0
					"800000":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM2C
						mapgen[i][j].angle = 90
					"c00000":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM2C
						mapgen[i][j].angle = 180
					"400000":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM2C
						mapgen[i][j].angle = 270
					"8000ff": # Purple zone, intersections
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM3
						mapgen[i][j].angle = 0
					"800080":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM3
						mapgen[i][j].angle = 90
					"ff00ff":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM3
						mapgen[i][j].angle = 180
					"ff0080":
						mapgen[i][j].exist = true
						mapgen[i][j].room_type = RoomTypes.ROOM3
						mapgen[i][j].angle = 270
					"00ffff": # cyan zone, crossrooms
						mapgen[i][j].exist = true
						var possible_angles: PackedFloat32Array = [0, 90, 180, 270]
						mapgen[i][j].room_type = RoomTypes.ROOM4
						mapgen[i][j].angle = possible_angles[rng.randf_range(0, possible_angles.size() - 1)]
		position_y += Vector2i(image_dimension, image_dimension)
	if debug_print:
		print("Map generated:")
		for j in range(size_x):
			var debug_string: String = ""
			for k in range(size_y):
				debug_string += str(int(mapgen[j][k].exist))
			print(debug_string)
		print("Connecting rooms...")
