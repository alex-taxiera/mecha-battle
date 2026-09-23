class_name EventPool
extends RefCounted
## The events a run can still come across. The first draw shuffles them; each draw then takes the
## first one that can happen, and when every one has been seen, the pool fills and shuffles
## again. An event that can't happen yet is handled by its [enum GameEvent.FailedStrategy]. When
## nothing can happen, the fallback event comes up.
## Adapted from Slay-The-Robot (MIT, DesirePathGames): data/prototype/PlayerData.gd
## (get_next_event_object_id_from_pool) and its EventPoolData. See THIRD_PARTY_NOTICES.md.

## The event shown when no other can come up, if the events include one.
var fallback: GameEvent

var _events: Array[GameEvent] = []
var _queue: Array[GameEvent] = []
var _rng: RandomNumberGenerator


## Holds [param events], setting aside the one marked [member GameEvent.fallback].
func _init(events: Array[GameEvent], rng: RandomNumberGenerator) -> void:
	_rng = rng
	for event in events:
		if event.fallback:
			fallback = event
		else:
			_events.append(event)


## Returns the events left before the pool refills, in the order they'll be tried.
func get_queue() -> Array[GameEvent]:
	return _queue.duplicate()


## Takes the next event that can happen in [param run], or the fallback when none can (null if
## there's no fallback).
func next(run: RunState) -> GameEvent:
	if _queue.is_empty():
		_queue.assign(_events)
		RunRng.shuffle(_rng, _queue)
	var chosen: GameEvent = null
	# Slay-The-Robot never records the events that fail here, so its strategies never run.
	var failed: Array[GameEvent] = []
	for event in _queue:
		if event.can_happen(run):
			chosen = event
			break
		failed.append(event)
	if chosen:
		_queue.erase(chosen)
	for event in failed:
		match event.failed_strategy:
			GameEvent.FailedStrategy.REMOVE:
				_queue.erase(event)
				_events.erase(event)
			GameEvent.FailedStrategy.APPEND:
				_queue.erase(event)
				_queue.append(event)
			GameEvent.FailedStrategy.REINSERT:
				_queue.erase(event)
				_queue.insert(_rng.randi_range(0, _queue.size()), event)
	return chosen if chosen else fallback
