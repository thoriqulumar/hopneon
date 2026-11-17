class_name NeonParticles
extends Node2D

const MAX_PARTICLES: int = 64
var particles: Array[Dictionary] = []
var paused: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 90210

func _process(delta: float) -> void:
	if paused or particles.is_empty():
		return
	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		particle.life = float(particle.life) - delta
		if float(particle.life) <= 0.0:
			particles.remove_at(index)
			continue
		particle.velocity = Vector2(particle.velocity) + Vector2(0.0, float(particle.gravity) * delta)
		particle.position = Vector2(particle.position) + Vector2(particle.velocity) * delta
		particles[index] = particle
	queue_redraw()

func emit_jump(world_position: Vector2, tint: Color = Color("16f4ff"), cosmetic: String = "cyan") -> void:
	var count := 13 if cosmetic == "gold" else 9
	for index in count:
		_add_particle(world_position + Vector2(rng.randf_range(-12.0, 8.0), 18.0), Vector2(rng.randf_range(-150.0, -35.0), rng.randf_range(45.0, 150.0)), tint, rng.randf_range(0.24, 0.42), rng.randf_range(2.0, 4.5), 180.0)

func emit_collision(world_position: Vector2) -> void:
	for index in 26:
		var angle := rng.randf_range(0.0, TAU)
		var velocity := Vector2.RIGHT.rotated(angle) * rng.randf_range(100.0, 360.0)
		var color := Color("ff2bd6") if index % 2 == 0 else Color("16f4ff")
		_add_particle(world_position, velocity, color, rng.randf_range(0.35, 0.72), rng.randf_range(3.0, 7.0), 240.0)

func clear() -> void:
	particles.clear()
	queue_redraw()

func set_paused(value: bool) -> void:
	paused = value

func _add_particle(spawn_position: Vector2, velocity: Vector2, color: Color, life: float, radius: float, gravity: float) -> void:
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front()
	particles.append({"position": spawn_position, "velocity": velocity, "color": color, "life": life, "max_life": life, "radius": radius, "gravity": gravity})

func _draw() -> void:
	for particle in particles:
		var alpha: float = float(particle.life) / float(particle.max_life)
		var color: Color = particle.color
		color.a = alpha * 0.9
		var particle_position: Vector2 = particle.position
		var radius_value: float = float(particle.radius)
		draw_circle(particle_position, radius_value * 2.2, Color(color.r, color.g, color.b, color.a * 0.13))
		draw_circle(particle_position, radius_value, color)
