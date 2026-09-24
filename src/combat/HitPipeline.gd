class_name HitPipeline
extends RefCounted
## Everything that happens to a hit between its source and the target's hull. A [Hit] goes
## through the attacker's [HitInterceptor]s, then the target's, each side in priority order; then
## the target's shield takes what it can and the hull the rest. Which interceptors see a hit
## depends on its [enum Kind]: armor that answers shots doesn't answer its own reflected damage, so
## two reflecting mechs can't bounce a hit back and forth.
## Adapted from Slay-The-Robot's ActionInterceptorProcessor (MIT, DesirePathGames), as a
## RefCounted rather than a Node that was never freed.

## SHOT: a weapon's. MELTDOWN, STORM, and REFLECT as named. OTHER: anything else.
enum Kind { SHOT, MELTDOWN, STORM, REFLECT, OTHER }


## One hit on its way to [member target].
class Hit:
	extends RefCounted
	var kind: Kind
	## Where it came from, if anywhere: the other mech, and the weapon for a shot.
	var attacker: BattleMech
	var weapon: ActivePart
	var target: BattleMech
	## The damage as it stands: the interceptors change it as the hit goes through.
	var damage: int
	## The damage after the attacker's side, before the target's.
	var outgoing := 0
	## What the target's side took off, e.g. plating.
	var blocked := 0
	## Of the damage that landed, what the shield took. [member taken] is shield and hull together.
	var absorbed := 0
	var taken := 0
	## Skip the target's plating, or its shield.
	var pierce_plating := false
	var pierce_shield := false
	## Only work out what would happen: interceptors change nothing else, and nothing lands.
	var preview := false
	var rejected := false

	func _init(p_kind: Kind, p_target: BattleMech, p_damage: int, p_attacker: BattleMech = null,
			p_weapon: ActivePart = null) -> void:
		kind = p_kind
		target = p_target
		damage = p_damage
		attacker = p_attacker
		weapon = p_weapon


## Runs [param hit] through both sides' interceptors and lands it on the target, unless it's a
## preview or an interceptor rejected it. Returns the damage taken, shield and hull together.
static func resolve(hit: Hit) -> int:
	outgoing(hit)
	if hit.rejected:
		return 0
	if not _run(hit, hit.target.get_interceptors(HitInterceptor.Side.TARGET)):
		return 0
	hit.damage = maxi(0, hit.damage)
	hit.blocked = maxi(0, hit.outgoing - hit.damage)
	if hit.preview:
		return hit.damage
	var target := hit.target
	var shield_before := target.shield
	hit.absorbed = 0 if hit.pierce_shield else mini(target.shield, hit.damage)
	target.shield -= hit.absorbed
	target.current_health = maxi(0, target.current_health - (hit.damage - hit.absorbed))
	hit.taken = hit.damage
	target.last_taken = hit.taken
	target.last_absorbed = hit.absorbed
	target.on_hit_landed(hit, shield_before)
	return hit.taken


## Runs [param hit] through its attacker's interceptors only (none without an attacker) and
## returns the damage it leaves with, also kept as [member Hit.outgoing]; 0 if rejected.
static func outgoing(hit: Hit) -> int:
	if hit.attacker and not _run(hit, hit.attacker.get_interceptors(HitInterceptor.Side.ATTACKER)):
		return 0
	hit.damage = maxi(0, hit.damage)
	hit.outgoing = hit.damage
	return hit.outgoing


# Runs the interceptors that see [param hit], highest priority first (ties in the order given).
# Returns false if one rejected it.
static func _run(hit: Hit, interceptors: Array[HitInterceptor]) -> bool:
	var chain: Array = []
	for i in interceptors.size():
		if interceptors[i].handles(hit.kind):
			chain.append([interceptors[i], i])
	chain.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0].priority > b[0].priority or (a[0].priority == b[0].priority and a[1] < b[1]))
	for entry in chain:
		match (entry[0] as HitInterceptor).intercept(hit):
			HitInterceptor.Result.STOPPED:
				break
			HitInterceptor.Result.REJECTED:
				hit.rejected = true
				hit.damage = 0
				return false
	return true
