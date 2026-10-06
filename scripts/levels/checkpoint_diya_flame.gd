extends Sprite2D
## A checkpoint diya's flame. Levels light a diya by making this node visible. The flame sprite sits
## on the wick with a stepped pixel flicker, and it pops once when a diya is first lit in play
## (lamps restored as lit on load skip the pop).

const STEP: float = 0.11
const ART_SCALE: float = 0.5  # 1 game unit = 2 art px
const STRETCH: Array[float] = [1.0, 30.0 / 28.0, 1.0, 26.0 / 28.0, 1.0, 31.0 / 28.0]

var _time: float = 0.0
var _step: int = 0
var _pop: float = 0.0
var _armed: bool = false
var _shown: bool = false


func _ready() -> void:
	_shown = visible
	_step = randi() % STRETCH.size()  # neighbouring diyas never flicker in lockstep
	_time = randf() * STEP
	_arm.call_deferred()  # levels apply the saved lit state in their own _ready, after ours


func _arm() -> void:
	_shown = visible
	_armed = true


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or not is_node_ready():
		return
	if visible and not _shown and _armed:
		_pop = 0.24
	_shown = visible


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_pop = maxf(_pop - delta, 0.0)
	if _time >= STEP:
		_time = 0.0
		_step = (_step + 1) % STRETCH.size()
		flip_h = _step % 2 == 1
	var burst: float = 1.5 if _pop > 0.12 else (1.25 if _pop > 0.0 else 1.0)
	scale = Vector2(burst, STRETCH[_step] * burst) * ART_SCALE
