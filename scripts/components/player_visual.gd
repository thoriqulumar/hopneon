extends Node2D

var glow_color: Color = Color("16f4ff")
var cosmetic: String = "cyan"
var effect_time: float = 0.0

func set_cosmetic(id: String, color: Color) -> void:
	cosmetic = id if id in ["cyan", "violet", "gold"] else "cyan"
	set_color(color)

func set_animation_paused(value: bool) -> void:
	set_process(not value)

func _process(delta: float) -> void:
	# Shared by the playable character and collection previews. Fixed geometry,
	# no extra particle nodes, no flashes, and no changes to collision shapes.
	effect_time = fmod(effect_time + delta, TAU * 10.0)
	if cosmetic != "cyan":
		queue_redraw()

func set_color(color: Color) -> void:
	glow_color = color
	queue_redraw()

func _draw() -> void:
	if cosmetic == "gold":
		_draw_solar_trail()
	draw_circle(Vector2.ZERO, 30.0, Color(glow_color, 0.09))
	draw_circle(Vector2.ZERO, 25.0, Color(glow_color, 0.16))
	draw_circle(Vector2.ZERO, 20.0, glow_color)
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color("bfffff"), 2.5, true)
	draw_circle(Vector2(-5.0, -5.0), 9.0, Color("dfffff"))
	draw_circle(Vector2(7.0, 3.0), 4.0, Color("071128"))
	draw_line(Vector2(-16.0, 15.0), Vector2(-29.0, 25.0), Color("ff35e8"), 5.0, true)
	if cosmetic in ["violet", "gold"]:
		_draw_orbit()
	if cosmetic == "gold":
		_draw_corona()

func _draw_orbit() -> void:
	var angle := effect_time * 1.5
	for index in 2:
		var start := angle + float(index) * PI
		draw_arc(Vector2.ZERO, 28.0, start, start + 1.1, 12, Color(glow_color, 0.65), 1.7, true)
		var satellite := Vector2.RIGHT.rotated(start + 1.1) * 28.0
		draw_circle(satellite, 5.0, Color(glow_color, 0.13))
		draw_circle(satellite, 2.4, glow_color.lightened(0.4))

func _draw_corona() -> void:
	# A slow sun-shaped outline gives Gold a distinct silhouette.
	var points := PackedVector2Array()
	for index in 24:
		var angle := float(index) * TAU / 24.0 + effect_time * 0.24
		var radius := 36.0 if index % 2 == 0 else 32.0
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	points.append(points[0])
	draw_polyline(points, Color(glow_color, 0.4), 1.2, true)
	for index in 3:
		var angle := float(index) * TAU / 3.0 - effect_time * 0.7
		_draw_spark(Vector2.RIGHT.rotated(angle) * 35.0, 3.2, Color("fff4cb"))

func _draw_solar_trail() -> void:
	for index in 2:
		var points := PackedVector2Array()
		for point in 12:
			var progress := float(point) / 11.0
			var wave := sin(progress * 4.0 - effect_time * 3.0 + float(index) * 1.7)
			points.append(Vector2(-18.0 - progress * 31.0, wave * 5.0 + float(index) * 6.0))
		draw_polyline(points, Color(glow_color, 0.18), 3.0, true)
	for index in 5:
		var progress := fmod(effect_time * 0.65 + float(index) / 5.0, 1.0)
		var alpha := sin(progress * PI) * 0.75
		var spark_position := Vector2(-24.0 - progress * 29.0, sin(progress * 5.0 + float(index)) * 10.0)
		_draw_spark(spark_position, 1.5 + (1.0 - progress) * 1.2, Color(glow_color, alpha))

func _draw_spark(at: Vector2, radius: float, color: Color) -> void:
	var diamond := PackedVector2Array([at + Vector2(0.0, -radius), at + Vector2(radius * 0.6, 0.0), at + Vector2(0.0, radius), at + Vector2(-radius * 0.6, 0.0)])
	draw_colored_polygon(diamond, color)
