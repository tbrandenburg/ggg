extends CanvasLayer

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var inventory: Node = player.get_node("Inventory")

var inventory_label: Label
var notification_label: Label
var notification_time := 0.0


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 570)
	panel.custom_minimum_size = Vector2(330, 120)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var title := Label.new()
	title.text = "FIELD INVENTORY"
	title.add_theme_font_size_override("font_size", 17)
	content.add_child(title)
	inventory_label = Label.new()
	content.add_child(inventory_label)
	var controls := Label.new()
	controls.text = "Aim at ground · Left click: dig · C: craft Stone Pick (3 stone) · Esc: cursor"
	controls.add_theme_font_size_override("font_size", 13)
	content.add_child(controls)
	add_child(panel)
	var reticle := Label.new()
	reticle.text = "+"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.anchor_left = 0.5
	reticle.anchor_right = 0.5
	reticle.anchor_top = 0.5
	reticle.anchor_bottom = 0.5
	reticle.offset_left = -7.0
	reticle.offset_right = 7.0
	reticle.offset_top = -34.0
	reticle.offset_bottom = -20.0
	reticle.add_theme_color_override("font_color", Color(0.98, 0.94, 0.68))
	reticle.add_theme_font_size_override("font_size", 18)
	add_child(reticle)
	notification_label = Label.new()
	notification_label.position = Vector2(18, 520)
	notification_label.add_theme_font_size_override("font_size", 20)
	notification_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.55))
	add_child(notification_label)
	inventory.changed.connect(_refresh_inventory)
	_refresh_inventory()


func _process(delta: float) -> void:
	if notification_time > 0.0:
		notification_time -= delta
		if notification_time <= 0.0:
			notification_label.text = ""


func show_notification(message: String) -> void:
	notification_label.text = message
	notification_time = 2.5


func _refresh_inventory() -> void:
	inventory_label.text = inventory.formatted_contents()
