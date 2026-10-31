extends RefCounted
## Sixteen original families, endlessly remixed into higher reaches.
## Add a family here to extend the expedition without changing the game loop.

const FLOORS_PER_BIOME := 20
const PREFIXES := [
	"Luminous", "Whispering", "Shattered", "Moonlit", "Ancient", "Prismatic", "Drifting", "Skybound"
]
const FAMILIES := [
	["Glacier Gate", "142d46", "b5e8f2", "79d7f0", "crystal", "snow", 0.55, 0.0, 0.0],
	["Mosswood", "153e36", "84c49d", "e1d884", "forest", "leaves", 1.0, 0.0, 0.0],
	["Dune Sea", "503b39", "e1b781", "f5d99e", "dunes", "sand", 1.15, 15.0, 0.0],
	["Coral Grotto", "143b52", "8bcac4", "f5a4ad", "reef", "bubbles", 0.9, 0.0, 40.0],
	["Ember Forge", "412b3c", "c68e83", "ffb56d", "volcano", "embers", 1.1, 0.0, 20.0],
	["Stormspire", "29374e", "afbdd6", "d8d4fa", "clouds", "rain", 0.8, 25.0, 0.0],
	["Mycelium Hollow", "352b4b", "c4a9de", "edbdcf", "mushroom", "spores", 0.9, 0.0, 30.0],
	["Clockwork Loft", "3d3633", "c8b394", "edcf83", "gears", "sparks", 1.1, 0.0, 0.0],
	["Crystal Archive", "273451", "a2bfe6", "cec4f5", "crystal", "sparks", 0.7, 0.0, 0.0],
	["Cloud Garden", "39536b", "d7e3e6", "e8ccde", "clouds", "petals", 0.9, 12.0, 65.0],
	["Bamboo Moon", "243d43", "99c4ae", "e3e7c2", "bamboo", "leaves", 1.0, 0.0, 0.0],
	["Candy Orbit", "45344c", "e4b2cd", "a6dfe0", "planets", "petals", 1.0, 0.0, 40.0],
	["Aurora Reach", "183c4e", "a0d3d1", "a8efc8", "aurora", "snow", 0.65, 16.0, 0.0],
	["Sunken Ruins", "2b4851", "b3c7b5", "e5d9ab", "ruins", "bubbles", 1.1, 0.0, 35.0],
	["Starfall Observatory", "242b48", "aaaed5", "f0dc9c", "stars", "stars", 0.85, 0.0, 30.0],
	["Void Bloom", "352d4c", "bea5d7", "b4e2d7", "orbits", "spores", 0.8, 10.0, 50.0],
]


static func at_floor(floor_id: int) -> Dictionary:
	var region := maxi(0, floor_id) / FLOORS_PER_BIOME
	var family_id := region % FAMILIES.size()
	var cycle := region / FAMILIES.size()
	var base: Array = FAMILIES[family_id]
	var title: String = base[0]
	if cycle > 0:
		title = "%s %s · Reach %d" % [PREFIXES[(cycle - 1) % PREFIXES.size()], title, cycle + 1]
	return {
		"name": title,
		"family": base[0],
		"family_id": family_id,
		"region": region,
		"background": _remix(Color(base[1]), cycle),
		"platform": _remix(Color(base[2]), cycle),
		"accent": _remix(Color(base[3]), cycle),
		"motif": base[4],
		"weather": base[5],
		"friction": base[6],
		"wind": base[7],
		"jump_bonus": base[8],
		"cycle": cycle,
	}


static func _remix(color: Color, cycle: int) -> Color:
	return Color.from_hsv(fposmod(color.h + cycle * 0.037, 1.0), color.s, color.v)
