extends Area2D
## 复活区域 — 玩家进入后持续3秒即可复活队友
## 绘制绿色圆环 + 进度弧 + 倒计时文字

@export var duration: float = 3.0
var progress: float = 0.0
var revived: bool = false

signal revive_complete


func _ready() -> void:
	# 碰撞体
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 80.0
	collision.shape = circle
	add_child(collision)

	# 倒计时标签
	var label := Label.new()
	label.name = "CountdownLabel"
	label.position = Vector2(-50, -20)
	label.size = Vector2(100, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	add_child(label)


func _process(delta: float) -> void:
	if revived:
		return

	# 检查是否有存活玩家在圈内
	var alive_inside := false
	for area in get_overlapping_areas():
		if area.is_in_group("player") and area.has_method("get_is_alive") and area.get_is_alive():
			alive_inside = true
			break

	if alive_inside:
		progress += delta / duration
		if progress >= 1.0:
			progress = 1.0
			revived = true
			revive_complete.emit()
	else:
		# 离开后快速衰减（但不重置到0，给一点容错）
		progress = max(0.0, progress - delta * 1.5)

	var label: Label = $CountdownLabel
	if progress > 0 and not revived:
		var remaining := duration * (1.0 - progress)
		label.text = "%.1fs" % remaining
		label.visible = true
	elif revived:
		label.text = "✓"
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		label.visible = false

	queue_redraw()


func _draw() -> void:
	var r: float = 80.0
	if revived:
		# 完成 — 青色实心圆
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.3, 0.9, 1.0, 0.5), 6.0)
		draw_circle(Vector2.ZERO, 6, Color(0.3, 0.9, 1.0, 0.8))
		# 外层光晕
		draw_arc(Vector2.ZERO, r + 8, 0, TAU, 64, Color(0.3, 0.9, 1.0, 0.2), 3.0)
		return

	# 外圈虚线效果 — 青色
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.3, 0.85, 1.0, 0.25), 3.0, true)

	if progress > 0:
		# 进度弧（顺时针从顶部开始） — 青蓝渐变
		var angle := TAU * progress
		draw_arc(Vector2.ZERO, r, -PI / 2, -PI / 2 + angle, 64, Color(0.3, 0.85, 1.0, 0.8), 5.0)
		# 外发光
		draw_arc(Vector2.ZERO, r + 3, -PI / 2, -PI / 2 + angle, 64, Color(0.3, 0.85, 1.0, 0.3), 2.0)

	# 中心点 — 发光粒子
	draw_circle(Vector2.ZERO, 5, Color(0.3, 0.85, 1.0, 0.5))
	draw_circle(Vector2.ZERO, 3, Color(0.5, 0.95, 1.0, 0.7))
