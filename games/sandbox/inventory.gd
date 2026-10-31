extends Node

signal changed

const MATERIAL_CATALOG = preload("res://material_catalog.gd")

var items: Dictionary = {}


func add_item(material_id: String, amount: int = 1) -> void:
	if amount <= 0 or not MATERIAL_CATALOG.MATERIALS.has(material_id):
		return
	items[material_id] = int(items.get(material_id, 0)) + amount
	changed.emit()


func count(material_id: String) -> int:
	return int(items.get(material_id, 0))


func remove_item(material_id: String, amount: int = 1) -> bool:
	if amount <= 0 or count(material_id) < amount:
		return false
	var remaining := count(material_id) - amount
	if remaining == 0:
		items.erase(material_id)
	else:
		items[material_id] = remaining
	changed.emit()
	return true


func set_items(saved_items: Dictionary) -> void:
	items.clear()
	for material_id in saved_items:
		if MATERIAL_CATALOG.MATERIALS.has(material_id):
			var amount := int(saved_items[material_id])
			if amount > 0:
				items[material_id] = amount
	changed.emit()


func formatted_contents() -> String:
	if items.is_empty():
		return "Empty"
	var rows: Array[String] = []
	for material_id in items:
		rows.append("%s  × %d" % [MATERIAL_CATALOG.display_name(material_id), items[material_id]])
	rows.sort()
	return "\n".join(rows)
