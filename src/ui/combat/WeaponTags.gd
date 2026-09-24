class_name WeaponTags
extends VBoxContainer
## A mech's weapon tags, stacked beside it on the stage in placement order: one
## [WeaponTag] per weapon it fights with.

var mech: BattleMech
## Seconds each tag's bar takes to fill up to a new charge.
var smoothing := 0.1:
	set(p_smoothing):
		smoothing = p_smoothing
		for tag: WeaponTag in _tags.values():
			tag.smoothing = smoothing

# Each tag's weapon.
var _tags := {}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)


## Makes a tag for each of [param p_mech]'s weapons, in the side's [param accent], aligned
## right for the right side.
func bind(p_mech: BattleMech, accent: Color, align_right: bool) -> void:
	mech = p_mech
	for tag: WeaponTag in _tags.values():
		remove_child(tag)
		tag.queue_free()
	_tags.clear()
	for active in mech.active_parts:
		if active.part.type != MechPart.PartType.WEAPON:
			continue
		var tag := WeaponTag.new()
		tag.slot_name = active.hardpoint.hardpoint_name if active.hardpoint else ""
		tag.weapon_name = active.part.get_display_name()
		tag.accent = accent
		tag.align_right = align_right
		tag.smoothing = smoothing
		tag.size_flags_horizontal = SIZE_SHRINK_END if align_right else SIZE_SHRINK_BEGIN
		add_child(tag)
		_tags[active] = tag
	refresh()


## Shows each weapon's charge and state as they are now.
func refresh() -> void:
	for active: ActivePart in _tags:
		_tags[active].show_state(active.get_charge(), WeaponTag.state_of(mech, active))


## Returns [param active]'s tag, or null if it isn't one of this mech's weapons.
func get_tag(active: ActivePart) -> WeaponTag:
	return _tags.get(active)


func get_tags() -> Array[WeaponTag]:
	var tags: Array[WeaponTag] = []
	tags.assign(get_children().filter(func(child: Node) -> bool: return child is WeaponTag))
	return tags
