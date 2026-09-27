extends RefCounted
## STYLE / momentum: chain moves (jump, slide, dash, air dash, wall run,
## grapple, slam, grind, trick, close call, smash, land ...) inside a short
## window to build style points. Variety pays: repeating the same move in a
## chain is worth much less than switching things up. Style points set the
## score multiplier  x1 -> x2 -> x3 -> x5 -> x10. Getting hit resets it; doing
## nothing lets it drain.

const TIERS := [0.0, 60.0, 170.0, 360.0, 650.0]
const MULTS := [1, 2, 3, 5, 10]
const NAMES := ["", "STYLISH", "SLICK", "SAVAGE", "LEGENDARY"]
const CAP := 800.0
const MOVE_PTS := {
	"jump": 8.0, "double": 10.0, "slide": 9.0, "dash": 10.0, "airdash": 14.0, "wall": 18.0, "walljump": 16.0,
	"grapple": 20.0, "release": 12.0, "slam": 16.0, "grind": 14.0, "trick": 22.0, "qpipe": 26.0, "close": 12.0,
	"smash": 10.0, "land": 5.0, "sky": 14.0, "kicker": 14.0, "boost": 6.0, "dodge": 18.0, "route": 20.0,
}
const LABEL := {
	"jump": "JUMP", "double": "DOUBLE", "slide": "SLIDE", "dash": "DASH", "airdash": "AIR DASH", "wall": "WALL RUN",
	"walljump": "WALL JUMP", "grapple": "GRAPPLE", "release": "SWING", "slam": "SLAM", "grind": "GRIND", "trick": "TRICK",
	"qpipe": "360 AIR", "close": "CLOSE CALL", "smash": "SMASH", "land": "LAND", "sky": "SKY JUMP", "kicker": "KICKER",
	"boost": "BOOST", "dodge": "DODGE", "route": "ROUTE",
}

var points := 0.0
var tier := 0
var chain: Array[String] = []
var idle := 0.0
var window := 2.2
var best_tier := 0


func reset() -> void:
	points = 0.0
	tier = 0
	chain.clear()
	idle = 0.0


## Registers a move. Returns the new tier if it went up, else -1.
func move(kind: String) -> int:
	var base: float = MOVE_PTS.get(kind, 6.0)
	# variety: a move already in the last 3 of the chain is worth 35%
	var recent := chain.slice(maxi(0, chain.size() - 3))
	var fresh := not kind in recent
	var chain_bonus := 1.0 + minf(chain.size(), 12) * 0.08
	points = minf(CAP, points + base * (1.0 if fresh else 0.35) * chain_bonus)
	chain.append(kind)
	if chain.size() > 8:
		chain.remove_at(0)
	idle = 0.0
	return _update_tier()


## A crash / stumble / hit: the chain is broken and style resets.
func broken() -> void:
	points = 0.0
	chain.clear()
	tier = 0


func tick(delta: float) -> void:
	idle += delta
	if idle > window:
		# chain over: drain towards the floor of the current tier, then below
		chain.clear()
		points = maxf(0.0, points - (40.0 + points * 0.35) * delta)
		_update_tier()


func _update_tier() -> int:
	var t := 0
	for i in TIERS.size():
		if points >= TIERS[i]:
			t = i
	var up := t > tier
	tier = t
	best_tier = maxi(best_tier, tier)
	return tier if up else -1


func mult() -> int:
	return MULTS[tier]


## 0..1 progress towards the next tier (1 at max).
func progress() -> float:
	if tier >= TIERS.size() - 1:
		return clampf((points - TIERS[tier]) / (CAP - TIERS[tier]), 0.0, 1.0)
	return clampf((points - TIERS[tier]) / (TIERS[tier + 1] - TIERS[tier]), 0.0, 1.0)


func chain_text() -> String:
	var out := []
	for k in chain.slice(maxi(0, chain.size() - 4)):
		out.append(LABEL.get(k, k.to_upper()))
	return " › ".join(out)
