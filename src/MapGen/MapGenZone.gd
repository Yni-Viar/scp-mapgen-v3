@icon("res://MapGen/icons/MapGenResource.svg")
extends Resource
## Zone resource - a set of rooms
class_name MapGenZone


## Rooms with one exit
@export var endrooms: Array[MapGenRoom] = []
## Single rooms with one exit
@export var endrooms_single: Array[MapGenRoom] = []
## Single large rooms with one exit
@export var endrooms_single_large: Array[MapGenRoom] = []
## Rooms with two exits, straight
@export var hallways: Array[MapGenRoom] = []
## Single rooms with two exits, straight
@export var hallways_single: Array[MapGenRoom] = []
## Checkpoint rooms (MapGen v8 new feature)
@export var checkpoint_hallway: Array[MapGenRoom] = []
## Single large rooms with two exits, straight
@export var hallways_single_large: Array[MapGenRoom] = []
## Rooms with two exits, corner
@export var corners: Array[MapGenRoom] = []
## Single rooms with two exits, corner
@export var corners_single: Array[MapGenRoom] = []
## Single large rooms with two exits, corner
@export var corners_single_large: Array[MapGenRoom] = []
## Rooms with three exits
@export var trooms: Array[MapGenRoom] = []
## Single rooms with three exits
@export var trooms_single: Array[MapGenRoom] = []
## Single large rooms with three exits
@export var trooms_single_large: Array[MapGenRoom] = []
## Rooms with four exits
@export var crossrooms: Array[MapGenRoom] = []
## Single rooms with four exits
@export var crossrooms_single: Array[MapGenRoom] = []
## Requires "Enable door generation" to be enabled
@export_group("Door frames")
## Door hallways
@export var door_frames: Array[PackedScene] = []
## Checkpoint doors (MapGen v8 new feature)
@export var checkpoint_door_frames: Array[PackedScene] = []
## Added in mapgen v9. Requires "Double room support" to be enabled.
@export_group("Double rooms")
## Double rooms. Their structure: [[MapGenRoom, MapGenRoom], [MapGenRoom, MapGenRoom], ...]
@export var double_rooms: Array[Array] = []
## Single version of double hallway
#@export var hallways_double_single: Array[MapGenRoom] = []
## Single version of double crossrooms
#@export var crossrooms_double_single: Array[MapGenRoom] = []
