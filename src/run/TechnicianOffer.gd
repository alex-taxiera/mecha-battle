class_name TechnicianOffer
extends RefCounted
## The boons the Mech Technician offers at the start of a run: [constant PAIRS] upsides each
## paired with a downside, and [constant COMPLETE] whole boons, none used twice.
## Adapted from Slay-The-Robot (MIT, DesirePathGames): scripts/ui/RunStartOptions.gd
## (populate_run_start_options). It shuffled the downsides twice and the complete options never,
## so the same complete option always came up; each list is shuffled once here. See
## THIRD_PARTY_NOTICES.md.

const PAIRS := 2
const COMPLETE := 1


## One boon on offer: its text and what it does.
class Boon:
	var text := ""
	## The effects in the order they apply: a downside's before its upside's, so e.g. losing all
	## gold happens before gaining some.
	var effects: Array[EventEffect] = []


## Returns the boons offered from [param options], rolled with [param rng]: the pairs, then the
## whole ones. Fewer when the options run short.
static func roll(options: Array[RunStartOption], rng: RandomNumberGenerator) -> Array[Boon]:
	var upsides := _of_kind(options, RunStartOption.Kind.UPSIDE)
	var downsides := _of_kind(options, RunStartOption.Kind.DOWNSIDE)
	var wholes := _of_kind(options, RunStartOption.Kind.COMPLETE)
	RunRng.shuffle(rng, upsides)
	RunRng.shuffle(rng, downsides)
	RunRng.shuffle(rng, wholes)
	var boons: Array[Boon] = []
	for i in mini(PAIRS, mini(upsides.size(), downsides.size())):
		var upside: RunStartOption = upsides.pop_back()
		var downside: RunStartOption = downsides.pop_back()
		var boon := Boon.new()
		boon.text = "%s, but %s" % [_sentence(upside.text), downside.text]
		boon.effects.append_array(downside.effects)
		boon.effects.append_array(upside.effects)
		boons.append(boon)
	for i in mini(COMPLETE, wholes.size()):
		var whole: RunStartOption = wholes.pop_back()
		var boon := Boon.new()
		boon.text = _sentence(whole.text)
		boon.effects.append_array(whole.effects)
		boons.append(boon)
	return boons


## Applies [param boon] to [param run] and returns what it did.
static func apply(boon: Boon, run: RunState) -> EventResult:
	var result := EventResult.new()
	for effect in boon.effects:
		effect.apply(run, result)
	return result


static func _of_kind(options: Array[RunStartOption], kind: RunStartOption.Kind) -> Array:
	return options.filter(func(option: RunStartOption) -> bool: return option.kind == kind)


static func _sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)
