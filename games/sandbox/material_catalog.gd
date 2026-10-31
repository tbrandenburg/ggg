extends RefCounted

const MATERIALS := {
	"soil":
	{
		"name": "Soil",
		"category": "Geological",
		"classification": "mixture",
		"description": "Loose mineral and organic surface material.",
		"naturally_occurring": true,
	},
	"sand":
	{
		"name": "Sand",
		"category": "Geological",
		"classification": "mixture",
		"description": "Loose grains from the desert surface.",
		"naturally_occurring": true,
	},
	"stone":
	{
		"name": "Stone",
		"category": "Geological",
		"classification": "mixture",
		"description": "Common compact rock from shallow ground.",
		"naturally_occurring": true,
	},
	"clay":
	{
		"name": "Clay",
		"category": "Geological",
		"classification": "mixture",
		"description": "Fine-grained mineral deposit in shallow layers.",
		"naturally_occurring": true,
	},
	"copper_ore":
	{
		"name": "Copper Ore",
		"category": "Ore",
		"classification": "mixture",
		"description": "Copper-bearing mineral from a seeded underground vein.",
		"naturally_occurring": true,
	},
	"iron_ore":
	{
		"name": "Iron Ore",
		"category": "Ore",
		"classification": "mixture",
		"description": "Iron-bearing mineral from a seeded underground vein.",
		"naturally_occurring": true,
	},
	"stone_pick":
	{
		"name": "Stone Pick",
		"category": "Tool",
		"classification": "manufactured",
		"description": "A crude hand-shaped stone tool that speeds up digging.",
		"naturally_occurring": false,
	},
}


static func display_name(material_id: String) -> String:
	if not MATERIALS.has(material_id):
		return material_id.capitalize()
	return MATERIALS[material_id]["name"]
