class_name HitInterceptor
extends RefCounted
## One step of a [HitPipeline]: something that changes a hit as it goes through, or stops it.
## Interceptors on the attacker's side run first (e.g. a relic doubling a shot), then the
## target's (plating, a relic softening hits). Within a side, higher [member priority] runs
## first. Keep interceptors free of state and side effects while [member HitPipeline.Hit.preview]
## is set.
## Adapted from Slay-The-Robot's BaseActionInterceptor (MIT, DesirePathGames).

enum Side { ATTACKER, TARGET }
## CONTINUE: go on to the next interceptor. STOPPED: skip the rest of this side's interceptors.
## REJECTED: the hit doesn't land at all.
enum Result { CONTINUE, STOPPED, REJECTED }

## Plating comes off at 9000 and relics soften hits at 8000; leave room around them.
var priority := 0
var side := Side.TARGET
## The kinds of hit this interceptor sees; empty for every kind.
var kinds: Array[HitPipeline.Kind] = []


## Whether this interceptor sees a hit of [param kind].
func handles(kind: HitPipeline.Kind) -> bool:
	return kinds.is_empty() or kind in kinds


## Changes [param hit] and returns how the pipeline goes on.
func intercept(_hit: HitPipeline.Hit) -> Result:
	return Result.CONTINUE
