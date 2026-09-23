class_name RunRng
extends RefCounted
## A run's randomness: one seed, split into named streams (e.g. "map", "loot", "shop"), so
## rolling one kind of thing never shifts another. The same seed gives the same run.
## Adapted from Slay-The-Robot (MIT, DesirePathGames): data/prototype/PlayerData.gd
## (get_player_rng) and autoload/Random.gd (shuffle_array, shuffle_slice_array,
## get_weighted_selection). See THIRD_PARTY_NOTICES.md.

var run_seed: int

var _streams: Dictionary[String, RandomNumberGenerator] = {}


## Pass no [param p_seed] for a random run.
func _init(p_seed: int = randi()) -> void:
	run_seed = p_seed


## Returns the stream called [param stream_name], making it on first use. Each stream is seeded
## from the run's seed and its own name, so two streams never roll the same numbers.
func stream(stream_name: String) -> RandomNumberGenerator:
	if _streams.has(stream_name):
		return _streams[stream_name]
	var rng := RandomNumberGenerator.new()
	# Slay-The-Robot seeds every stream with the run seed alone, so all its streams roll the
	# same sequence. Mixing in the name keeps them apart.
	rng.seed = hash([run_seed, stream_name])
	_streams[stream_name] = rng
	return rng


## Returns where each stream has got to, to pick the run up again with [method restore].
func get_state() -> Dictionary[String, int]:
	var states: Dictionary[String, int] = {}
	for stream_name in _streams:
		states[stream_name] = _streams[stream_name].state
	return states


## Puts each stream in [param states] back where [method get_state] found it.
func restore(states: Dictionary[String, int]) -> void:
	for stream_name in states:
		stream(stream_name).state = states[stream_name]


## Shuffles [param array] in place with [param rng] and returns it. Unlike
## [method Array.shuffle], the order depends only on the rng, so a seeded run repeats it.
static func shuffle(rng: RandomNumberGenerator, array: Array) -> Array:
	# Fisher-Yates. Slay-The-Robot swaps each item with any index, which makes some orders
	# likelier than others.
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swapped: Variant = array[i]
		array[i] = array[j]
		array[j] = swapped
	return array


## Shuffles [param array] in place and returns its first [param count] items (all of them if
## there are fewer, or if [param count] is negative).
static func shuffle_slice(rng: RandomNumberGenerator, array: Array, count: int) -> Array:
	shuffle(rng, array)
	if count < 0:
		return array
	return array.slice(0, mini(count, array.size()))


## Returns a key of [param weights] picked at random, each as likely as its weight: {a: 1, b: 3}
## picks b three times as often as a. Keys weighted 0 or less never come up. Returns
## [code]null[/code] when nothing has any weight.
static func weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var total := 0
	for key: Variant in weights:
		total += maxi(0, weights[key])
	if total <= 0:
		return null
	# Buckets laid end to end: weights [1, 2, 1] fill [0, 1), [1, 3), and [3, 4).
	var roll := rng.randi_range(0, total - 1)
	for key: Variant in weights:
		var weight: int = maxi(0, weights[key])
		if roll < weight:
			return key
		roll -= weight
	return null
