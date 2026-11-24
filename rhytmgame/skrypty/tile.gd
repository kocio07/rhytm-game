extends Node2D

var lane = 0
var target_time = 0.0
var hit_lane: float = 500
var approach_time = 3.0 # how many secs before hit tile will spawn
var spawn_y: float = -100
var is_hit = false

@onready var visual = $ColorRect

func setup(p_lane: int, p_target_time: float, p_x: float, p_hit_lane: float, p_approach_time: float, p_width: float) -> void:
	lane = p_lane
	target_time = p_target_time
	hit_lane = p_hit_lane
	approach_time = p_approach_time
	position = Vector2(p_x, spawn_y)
	
	visual.size = Vector2(p_width - 8.0, 110.0)
	visual.position = Vector2(p_x, spawn_y)
	
	
func update_position(song_time: float) -> void:
	var time_remaining: float = target_time - song_time
	# progress = 0.0 na starcie (spawn_y) 1.0 wtedy kiedy trafiam (hit_lane)
	var progress: float = 1.0 - (time_remaining / approach_time)
	position.y = lerp(spawn_y, hit_lane, progress)
