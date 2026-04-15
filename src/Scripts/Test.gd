extends Control

var file_access_web: FileAccessWeb = null
var forward_pressed: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if DisplayServer.is_touchscreen_available():
		$CameraForward.show()
	else:
		$CameraForward.hide()
	if OS.get_name() == "Web":
		file_access_web = FileAccessWeb.new()
		file_access_web.load_started.connect(_on_web_file_load_started)
		file_access_web.progress.connect(_on_web_file_progress)
		file_access_web.loaded.connect(_on_web_file_loaded)
		file_access_web.error.connect(_on_web_upload_error)
		$ScrollContainer/VBoxContainer/GenerateAndSave.hide()
	if OS.get_name() == "Android":
		$ScrollContainer/VBoxContainer/GenerateAndSave.hide()
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



func _on_seed_text_changed(new_text):
	if new_text != "":
		get_parent().get_node("FacilityGenerator").rng_seed = hash(new_text)
		get_parent().get_node("FacilityGeneratorRender").rng_seed = hash(new_text)
	else:
		get_parent().get_node("FacilityGenerator").rng_seed = -1
		get_parent().get_node("FacilityGeneratorRender").rng_seed = -1


func _on_generate_pressed():
	get_parent().get_node("FacilityGenerator").generate_rooms()
	$ScrollContainer/VBoxContainer/CurrentSeed.text = "Current seed: " + str(get_parent().get_node("FacilityGenerator").rng.seed)


func _on_double_room_toggled(toggled_on: bool) -> void:
	get_parent().get_node("FacilityGenerator").double_room_support = toggled_on


func _on_room_pack_button_pressed() -> void:
	if OS.get_name() == "Web":
		file_access_web.open(".zip, application/zip, application/x-zip-compressed")
	else:
		if OS.get_name() == "Android":
			OS.request_permission("android.permissions.MANAGE_EXTERNAL_STORAGE")
		get_parent().get_node("SetRoomPack/FileDialog").show()


func _on_room_scale_edit_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		get_parent().get_node("FacilityGenerator").grid_size = float(new_text)
		if get_parent().get_node_or_null("FacilityGeneratorRender") != null:
			get_parent().get_node("FacilityGeneratorRender").grid_size = float(new_text)


func _on_save_result_pressed() -> void:
	if OS.get_name() == "Android":
		OS.request_permission("android.permissions.WRITE_EXTERNAL_STORAGE")
	get_parent().get_node("RoomSaver/FileDialog").show()


func _on_zone_size_edit_text_changed(new_text: String) -> void:
	if new_text.is_valid_int():
		get_parent().get_node("FacilityGenerator").zone_size = int(new_text)
		if get_parent().get_node_or_null("FacilityGeneratorRender") != null:
			get_parent().get_node("FacilityGeneratorRender").zone_size = int(new_text)


func _on_door_toggled(toggled_on: bool) -> void:
	get_parent().get_node("FacilityGenerator").enable_door_generation = toggled_on




func _on_enable_lighting_toggled(toggled_on: bool) -> void:
	if toggled_on:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	else:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED


func _on_enable_checkpoints_toggled(toggled_on: bool) -> void:
	get_parent().get_node("FacilityGenerator").checkpoints_enabled = toggled_on
	if get_parent().get_node_or_null("FacilityGeneratorRender") != null:
		get_parent().get_node("FacilityGeneratorRender").checkpoints_enabled = toggled_on


func _on_hints_toggled(toggled_on: bool) -> void:
	$Label.visible = toggled_on


func _on_camera_forward_button_down() -> void:
	get_parent().get_node("Camera3D")._w = true


func _on_camera_forward_button_up() -> void:
	get_parent().get_node("Camera3D")._w = false


func _on_test_semi_infinite_mapgen_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/InfinityGen.tscn")


func _on_hide_testing_functions_toggled(toggled_on: bool) -> void:
	$ScrollContainer/VBoxContainer/TestSemiInfiniteMapgen.visible = !toggled_on
	$ScrollContainer/VBoxContainer/DoubleRoom.visible = !toggled_on
	$ScrollContainer/VBoxContainer/Door.visible = !toggled_on

func _on_web_file_loaded(file_name: String, data: PackedByteArray) -> void:
	$LoadingPanel/LoadingLabel.text = "Saving zip to temporary location...\nPlease, wait."
	await get_tree().create_timer(0.375).timeout
	var file: FileAccess = FileAccess.open("user://preview.zip", FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
	get_parent().get_node("SetRoomPack").load_pack("user://preview.zip")

func _on_web_upload_error() -> void:
	OS.alert("Upload failed!")
	$LoadingPanel.hide()

func _on_web_file_progress(current_bytes: int, total_bytes: int) -> void:
	var percentage: float = float(current_bytes) / float(total_bytes) * 100
	$LoadingPanel/LoadingLabel.text = "Uploading your zip file (" + str(percentage) + "%)...\nPlease, wait."

func _on_web_file_load_started(file_name: String):
	$LoadingPanel.show()

func _on_set_room_pack_pack_loading_finished() -> void:
	$LoadingPanel.hide()
	$LoadingPanel/LoadingLabel.text = "Loading rooms...\nPlease, wait."


func _on_set_room_pack_pack_loading_start() -> void:
	$LoadingPanel.show()
	$LoadingPanel/LoadingLabel.text = "Loading rooms...\nPlease, wait."


func _on_generate_and_save_pressed() -> void:
	get_parent().get_node("FacilityGenerator").clear()
	if OS.get_name() == "Android":
		OS.request_permission("android.permissions.WRITE_EXTERNAL_STORAGE")
	get_parent().get_node("RoomQuickSaver/FileDialog").show()


func _on_tonemapper_item_selected(index: int) -> void:
	get_parent().get_node("WorldEnvironment").environment.tonemap_mode = index as Environment.ToneMapper
	if index > 0 && index < 4:
		get_parent().get_node("WorldEnvironment").environment.tonemap_white = 2.0
	else:
		get_parent().get_node("WorldEnvironment").environment.tonemap_white = 1.0
