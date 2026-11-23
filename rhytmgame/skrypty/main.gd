extends Node2D

@export var ring_travel_beats: float = 5.0
@export var frame_radius: float = 260.0
@export var depth_curve: float = 1.8
@export var points: int = 8
@export var max_hp: int = 5
@export var must_move_every_beat: bool = true
@export var missed_beat_costs_hp: bool = true

@onready var clock: BeatClock = $BeatClock

var rings: Array[Dictionary] = []
var player_ring_id: int = -1
var player_radius: float = 0.0
var player_angle: float = PI / 2.0
var view_angle: float = PI / 2.0
var hp: int = 0
var iframes: float = 0.0
var score: int = 0
var combo: int = 0
var feedback: String = ""
var feedback_t: float = 0.0
var hit_flash: float = 0.0
var game_over: bool = false


func _ready() -> void:
	clock.beat_passed.connect(_on_beat_passed)
	clock.beat_missed.connect(_on_beat_missed)
	_generate_rings()
	_reset_game()


func _generate_rings() -> void:
	rings.clear()
	var beat := clock.beat_length()
	var last_b := -1
	var id := 0
	for b in range(0, clock.song_beats):
		if randf() < 0.3 and b - last_b < 2 and b > 4:
			continue
		rings.append({"id": id, "spawn": b * beat})
		id += 1
		last_b = b


func _reset_game() -> void:
	clock.reset()
	player_ring_id = -1
	player_radius = 0.0
	player_angle = PI / 2.0
	view_angle = PI / 2.0
	hp = max_hp
	iframes = 0.0
	score = 0
	combo = 0
	feedback = ""
	feedback_t = 0.0
	hit_flash = 0.0
	game_over = false


func _travel_time() -> float:
	return ring_travel_beats * clock.beat_length()


func _ring_t(r: Dictionary) -> float:
	return (clock.song_time - r.spawn) / _travel_time()


func _ring_radius(r: Dictionary) -> float:
	return frame_radius * pow(clampf(_ring_t(r), 0.0, 1.0), depth_curve)


func _find_ring(id: int) -> Variant:
	for r in rings:
		if r.id == id:
			return r
	return null


func _alive(r: Dictionary) -> bool:
	var t := _ring_t(r)
	return t >= 0.0 and t < 1.0


func _process(delta: float) -> void:
	if game_over:
		queue_redraw()
		return

	clock.update_clock(delta)
	iframes = maxf(0.0, iframes - delta)
	hit_flash = maxf(0.0, hit_flash - delta * 2.5)
	feedback_t = maxf(0.0, feedback_t - delta)

	view_angle = lerp_angle(view_angle, player_angle, 1.0 - exp(-18.0 * delta))

	var cur = _find_ring(player_ring_id)
	if cur == null or _ring_t(cur) >= 1.0:
		if cur != null:
			_take_hit("oops")
		_attach_to_youngest()
		cur = _find_ring(player_ring_id)

	var target := 0.0
	if cur != null:
		target = _ring_radius(cur)
	player_radius = lerpf(player_radius, target, 1.0 - exp(-30.0 * delta))
	queue_redraw()


func _attach_to_youngest() -> void:
	var best = null
	for r in rings:
		if _alive(r) and (best == null or r.spawn > best.spawn):
			best = r
	player_ring_id = best.id if best != null else -1


func _take_hit(msg: String) -> void:
	if iframes > 0.0 or clock.song_time < 0.0:
		return
	hp -= 1
	combo = 0
	iframes = 1.0
	hit_flash = 1.0
	_say(msg)
	if hp <= 0:
		game_over = true


func _on_beat_passed(_beat_index: int) -> void:
	combo += 1
	score += 100 * (1 + combo / 5)
	_say("good")


func _on_beat_missed(_beat_index: int) -> void:
	if not must_move_every_beat:
		return
	combo = 0
	_say("move")
	if missed_beat_costs_hp:
		_take_hit("faster")


func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event.is_action_pressed("ui_accept"):
			_reset_game()
		return

	if event.is_action_pressed("ui_left"):
		player_angle += TAU / points
		_register_move()
	elif event.is_action_pressed("ui_right"):
		player_angle -= TAU / points
		_register_move()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept"):
		if _hop_deeper():
			_register_move()


func _hop_deeper() -> bool:
	var cur = _find_ring(player_ring_id)
	if cur == null:
		return false
	var next = null
	for r in rings:
		if r.spawn > cur.spawn and _alive(r) and (next == null or r.spawn < next.spawn):
			next = r
	if next == null:
		_say("theres no ring yet")
		combo = 0
		return false
	player_ring_id = next.id
	return true


func _register_move() -> void:
	if clock.try_register_on_beat():
		return
	if clock.song_time >= 0.0:
		combo = 0
		_say("oops")


func _say(t: String) -> void:
	feedback = t
	feedback_t = 0.6


func _draw() -> void:
	var c := get_viewport_rect().size / 2.0
	var font := ThemeDB.fallback_font

	draw_set_transform(c, PI / 2.0 - view_angle, Vector2.ONE)
	var o := Vector2.ZERO
	draw_line(Vector2(-frame_radius, 0), Vector2(frame_radius, 0), Color(0.8, 0.2, 0.9, 0.25), 1.5)
	draw_line(Vector2(0, -frame_radius), Vector2(0, frame_radius), Color(0.8, 0.2, 0.9, 0.25), 1.5)
	draw_circle(o, 6.0 + clock.pulse * 3.0, Color(0.8, 0.2, 0.9, 0.6))

	for r in rings:
		if not _alive(r):
			continue
		var t := _ring_t(r)
		var rad := _ring_radius(r)
		var is_player: bool = r.id == player_ring_id
		var danger := clampf((t - 0.7) / 0.3, 0.0, 1.0)
		var col := Color(1, 1, 1, 0.25 + 0.6 * t)
		if is_player:
			col = Color(0.85, 0.5, 1.0, 1.0)
		col = col.lerp(Color(1, 0.2, 0.3, 1.0), danger)
		var width := 2.0 + 4.0 * t
		draw_arc(o, rad, 0.0, TAU, 128, col, width)
		for k in points:
			draw_circle(Vector2.from_angle(k * TAU / points) * rad, 2.0 + 3.0 * t, col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var half := frame_radius
	var rect := Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	var fcol := Color(1, 1, 1, 0.9).lerp(Color(1, 0.1, 0.2, 1.0), hit_flash)
	draw_rect(rect, fcol, false, 4.0 + clock.pulse * 4.0)

	var blink := iframes > 0.0 and int(iframes * 12.0) % 2 == 0
	if not blink:
		_draw_heart(c + Vector2(0, player_radius), 10.0 + clock.pulse * 1.5, Color(0.7, 0.2, 1.0))

	draw_string(font, Vector2(20, 40), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string(font, Vector2(20, 76), "Combo: %d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	for i in hp:
		_draw_heart(Vector2(30 + i * 30, 110), 8.0, Color(1, 0.3, 0.4))
	if feedback_t > 0.0:
		draw_string(font, c + Vector2(-100, -half - 20), feedback,
			HORIZONTAL_ALIGNMENT_CENTER, 200, 28, Color(1, 1, 1, feedback_t * 2.0))
	if clock.song_time < 0.0:
		draw_string(font, c + Vector2(-100, 0), "prepare",
			HORIZONTAL_ALIGNMENT_CENTER, 200, 24)
	if game_over:
		draw_string(font, c + Vector2(-170, 0), "GAME OVER - Enter = restart",
			HORIZONTAL_ALIGNMENT_CENTER, 340, 28, Color.WHITE)


func _draw_heart(p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(p + Vector2(x, y) * (s / 16.0))
	draw_colored_polygon(pts, col)
