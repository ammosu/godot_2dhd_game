extends Node
## Subtle body language for a standing billboard: idle breathing, a nod while
## the character's dialogue line types, and a short acknowledgement dip.
## Owns only the parent sprite's scale.y. Billboards are anchored at their
## feet (SpriteGrounding), so scaling Y keeps the feet planted.
const BREATH_AMPLITUDE: float = 0.010
const BREATH_RATE: float = 2.2 # rad/s, one breath about every 2.9 s
const NOD_AMPLITUDE: float = 0.006 # about 1-2 px on a 1.45 m body
const NOD_HZ: float = 2.5
const ACKNOWLEDGE_SECONDS: float = 0.2
const ACKNOWLEDGE_AMPLITUDE: float = 0.02

## Set false for sprites whose idle motion is owned elsewhere (the player).
var breathing: bool = true
## True while this character's line types. A nod always completes its cycle
## (at least one), so even a very short line reads as spoken.
var speaking: bool = false:
	set(value):
		if value == speaking:
			return
		if value and not _nodding():
			_nod_clock = 0.0
		speaking = value
		if not value:
			var period: float = 1.0 / NOD_HZ
			_nod_until = maxf(period, ceilf(_nod_clock / period) * period)
var _sprite: SpriteBase3D
var _phase: float = randf() * TAU
var _clock: float = 0.0
var _nod_clock: float = 0.0
var _nod_until: float = 0.0
var _acknowledge: float = 0.0
## True while this component wrote scale.y last frame. When a nod or dip ends
## on a non-breathing sprite, scale.y is restored once and then left to its
## owner (player.gd drives the hero's own idle breathing).
var _driving: bool = false


func _init() -> void:
	name = "BodyLife"


func _ready() -> void:
	_sprite = get_parent() as SpriteBase3D


func acknowledge() -> void:
	_acknowledge = ACKNOWLEDGE_SECONDS


func vertical_scale() -> float:
	var value: float = 1.0
	if breathing:
		value += BREATH_AMPLITUDE * sin(_clock * BREATH_RATE + _phase)
	if _nodding():
		value -= NOD_AMPLITUDE * (0.5 - 0.5 * cos(_nod_clock * TAU * NOD_HZ))
	if _acknowledge > 0.0:
		value -= ACKNOWLEDGE_AMPLITUDE * sin(PI * (1.0 - _acknowledge / ACKNOWLEDGE_SECONDS))
	return value


func _nodding() -> bool:
	return speaking or _nod_clock < _nod_until


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_clock += delta
	if _nodding():
		_nod_clock += delta
	_acknowledge = maxf(0.0, _acknowledge - delta)
	if not breathing and not _nodding() and _acknowledge <= 0.0:
		# Hand the sprite back exactly at rest, once, then leave it alone.
		if _driving:
			_sprite.scale.y = 1.0
			_driving = false
		return
	_driving = true
	_sprite.scale.y = vertical_scale()


static func find(sprite: Node) -> Node:
	return sprite.get_node_or_null("BodyLife") if sprite != null else null
