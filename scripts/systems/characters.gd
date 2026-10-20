extends RefCounted

## Night Harvest — playable characters and villager looks.
##
## Every sheet shares Ken's 32x32 layout (Assets/Player/character.png), so one set of
## animations in Scenes/ken.tscn works for all of them: at runtime the AtlasTextures
## are re-pointed at the chosen sheet.
##
## Perks are small, readable bonuses so the choice matters without breaking balance:
##   growth  -> crops grow faster
##   brawler -> more max HP and weapon damage
##   none    -> Ken: balanced, cheaper defenses in the shop

const KEN_SHEET := "res://Assets/Player/character.png"

const PLAYABLE := [
	{
		"id": "ken", "name": "KEN", "sheet": KEN_SHEET,
		"title": "THE ALL-ROUNDER",
		"bio": "RAISED ON THIS FARM. KNOWS EVERY POST.",
		"perk": "HANDYMAN: DEFENSES COST 15% LESS.",
		"perk_id": "handyman", "portrait": Rect2(8, 1, 16, 16),
	},
	{
		"id": "mira", "name": "MIRA", "sheet": "res://Assets/Characters/mira.png",
		"title": "THE GREEN THUMB",
		"bio": "CITY BOTANIST CHASING A QUIET LIFE.",
		"perk": "GREEN THUMB: CROPS GROW 25% FASTER.",
		"perk_id": "growth", "portrait": Rect2(8, 1, 16, 16),
	},
	{
		"id": "rico", "name": "RICO", "sheet": "res://Assets/Characters/rico.png",
		"title": "THE BRAWLER",
		"bio": "EX-RANCH HAND. SLEEPS WITH ONE EYE OPEN.",
		"perk": "BRAWLER: +25 MAX HP, +20% WEAPON DAMAGE.",
		"perk_id": "brawler", "portrait": Rect2(8, 0, 16, 16),
	},
]

const VILLAGER_SHEETS := {
	"rosa": "res://Assets/Characters/rosa.png",
	"ben": "res://Assets/Characters/ben.png",
	"pedro": "res://Assets/Characters/pedro.png",
	"lina": "res://Assets/Characters/lina.png",
}


static func get_character(id: String) -> Dictionary:
	for c in PLAYABLE:
		if c["id"] == id:
			return c
	return PLAYABLE[0]


static func index_of(id: String) -> int:
	for i in PLAYABLE.size():
		if PLAYABLE[i]["id"] == id:
			return i
	return 0


static func perk_of(id: String) -> String:
	return str(get_character(id)["perk_id"])


## A copy of `frames` whose atlas frames point at `sheet` instead of Ken's sheet.
static func retarget_frames(frames: SpriteFrames, sheet: Texture2D) -> SpriteFrames:
	var out := SpriteFrames.new()
	for anim in frames.get_animation_names():
		if not out.has_animation(anim):
			out.add_animation(anim)
		out.set_animation_loop(anim, frames.get_animation_loop(anim))
		out.set_animation_speed(anim, frames.get_animation_speed(anim))
		for i in frames.get_frame_count(anim):
			var tex := frames.get_frame_texture(anim, i)
			var dur := frames.get_frame_duration(anim, i)
			if tex is AtlasTexture and (tex as AtlasTexture).atlas and (tex as AtlasTexture).atlas.resource_path == KEN_SHEET:
				var a := AtlasTexture.new()
				a.atlas = sheet
				a.region = (tex as AtlasTexture).region
				a.margin = (tex as AtlasTexture).margin
				tex = a
			out.add_frame(anim, tex, dur)
	if out.has_animation(&"default") and out.get_frame_count(&"default") == 0 and frames.get_animation_names().find("default") == -1:
		out.remove_animation(&"default")
	return out


## Portrait (head) texture for menus, HUD and dialogue.
static func portrait(id: String) -> AtlasTexture:
	var c := get_character(id)
	var a := AtlasTexture.new()
	a.atlas = load(c["sheet"])
	a.region = c["portrait"]
	return a


static func villager_portrait(key: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(VILLAGER_SHEETS.get(key, KEN_SHEET))
	a.region = Rect2(8, 0 if key == "pedro" else 1, 16, 16)
	return a
