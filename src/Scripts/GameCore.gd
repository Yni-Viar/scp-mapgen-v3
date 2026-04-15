extends Node3D

#var player: Node3D
@export var infinite_gen: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	reset_settings()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


#func _on_facility_generator_generated() -> void:
	#$StaticPlayer.global_position = Vector3(($FacilityGenerator.zone_size * ($FacilityGenerator.map_size_x + 1)) / 2 * $FacilityGenerator.grid_size, 0, ($FacilityGenerator.zone_size * ($FacilityGenerator.map_size_y + 1)) / 2 * $FacilityGenerator.grid_size)


func reset_settings():
	if infinite_gen:
		if ResourceLoader.exists("res://ResearchZoneLite/RZLite.tres"):
			var zones: Array[MapGenZone] = [load("res://ResearchZoneLite/RZLite.tres"), load("res://Assets/Rooms/SimpleTest.tres")]
			$InfiniteGenerator/FacilityGenInfinite.rooms = zones
		else:
			var zones: Array[MapGenZone] = [load("res://Assets/Rooms/SimpleTest.tres")]
			$InfiniteGenerator/FacilityGenInfinite.rooms = zones
	else:
		if ResourceLoader.exists("res://ResearchZoneLite/RZLite.tres"):
			var zones: Array[MapGenZone] = [load("res://ResearchZoneLite/RZLite.tres")]
			$FacilityGenerator.rooms = zones
			if get_node_or_null("FacilityGeneratorRender") != null:
				$FacilityGeneratorRender.rooms = zones
		else:
			var zones: Array[MapGenZone] = [load("res://Assets/Rooms/SimpleTest.tres")]
			$FacilityGenerator.rooms = zones
			if get_node_or_null("FacilityGeneratorRender") != null:
				$FacilityGeneratorRender.rooms = zones
