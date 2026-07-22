extends CanvasLayer

# mode = "single" | "duo"
signal start_game(mode: StringName)

var _rainbow_hue: float = 0.0
var _rainbow_active: bool = true

# ── 菜单背景动画 ──
var _menu_fx_time: float = 0.0
var _clouds: Array = []       # [{x, y, w, h, speed, alpha}, ...]
var _particles: Array = []    # [{x, y, base_x, base_y, phase, speed, size, alpha}, ...]
const _MENU_W: float = 428.0
const _MENU_H: float = 720.0

# ── 角色展示精灵 ──
const CHAR_SPRITES: Dictionary = {
	0: {"walk": ["res://art/chars/0_jianxiu_walk1.png", "res://art/chars/0_jianxiu_walk2.png"]},
	1: {"walk": ["res://art/chars/1_fushi_walk1.png", "res://art/chars/1_fushi_walk2.png"]},
	2: {"walk": ["res://art/chars/2_danxiu_walk1.png", "res://art/chars/2_danxiu_walk2.png"]},
	3: {"walk": ["res://art/chars/3_tixiu_walk1.png", "res://art/chars/3_tixiu_walk2.png"]},
	4: {"walk": ["res://art/chars/4_lingshou_walk1.png", "res://art/chars/4_lingshou_walk2.png"]},
}
var _showcase_sprite: AnimatedSprite2D = null
var _showcase_tween: Tween = null


# ═══════════════════════════════════════════
#  Initialization
# ═══════════════════════════════════════════

func _ready() -> void:
	$GameOverPanel.hide()
	$LeaderboardPanel.hide()
	$SettingsPanel.hide()
	$GameOverPanel.modulate.a = 0
	$LeaderboardPanel.modulate.a = 0
	$SettingsPanel.modulate.a = 0

	# 古风按钮 hover 配色：金/紫/青/蓝
	_animate_button($SingleButton, Color(1.3, 1.15, 0.6), 1.08, 0.94)
	_animate_button($DuoButton, Color(1.15, 0.85, 1.3), 1.08, 0.94)
	_animate_button($SettingsButton, Color(0.7, 1.2, 1.25), 1.06, 0.95)
	_animate_button($LeaderboardButton, Color(0.7, 0.95, 1.4), 1.06, 0.95)
	_animate_button($GameOverPanel/VBoxContainer/SubmitButton, Color(1.25, 1.1, 0.6), 1.06, 0.95)
	_animate_button($GameOverPanel/VBoxContainer/ButtonRow/MenuButton, Color(1.2, 1.2, 1.2), 1.05, 0.96)
	_animate_button($GameOverPanel/VBoxContainer/ButtonRow/ViewLeaderboardButton, Color(0.7, 0.95, 1.4), 1.05, 0.96)
	_animate_button($LeaderboardPanel/VBoxContainer/BackButton, Color(1.2, 1.2, 1.2), 1.05, 0.96)
	_animate_button($SettingsPanel/VBoxContainer/SettingsBackButton, Color(1.2, 1.2, 1.2), 1.05, 0.96)

	# Sync color pickers with saved settings
	$SettingsPanel/VBoxContainer/P1Row/P1ColorPicker.color = Settings.p1_color
	$SettingsPanel/VBoxContainer/P2Row/P2ColorPicker.color = Settings.p2_color

	# 初始化主菜单 UI 并显示
	_setup_menu_style()
	$RainbowTimer.start()
	# 延迟一帧显示主菜单，确保所有节点就绪
	await get_tree().process_frame
	_show_main_menu()


# ═══════════════════════════════════════════
#  Rainbow title effect
# ═══════════════════════════════════════════

func _on_rainbow_timer_timeout() -> void:
	if not _rainbow_active:
		return
	_rainbow_hue += 0.008
	if _rainbow_hue > 1.0:
		_rainbow_hue -= 1.0
	var color := Color.from_hsv(_rainbow_hue, 0.7, 1.0)
	$Message.add_theme_color_override("font_color", color)
	$MessageGlow.add_theme_color_override("font_color", Color(color, 0.28))


# ═══════════════════════════════════════════
#  主菜单古风样式初始化
# ═══════════════════════════════════════════

func _setup_menu_style() -> void:
	# 主菜单标题改为仙侠主题
	$Message.text = "修仙奇缘"
	$MessageGlow.text = "修仙奇缘"
	$Message.add_theme_color_override("font_color", Color(1, 0.88, 0.45))
	$MessageGlow.add_theme_color_override("font_color", Color(1, 0.88, 0.45, 0.2))

	# 按钮文字改为古风
	$SingleButton.text = "单人修行"
	$DuoButton.text = "双人论道"
	$SettingsButton.text = "洞府设置"
	$LeaderboardButton.text = "天机榜"


func _refresh_char_showcase() -> void:
	var char_id := Characters.p1_character
	var data := Characters.get_character(char_id)
	$CharShowcase/ShowcaseFrame/VBox/CharName.text = data.name
	$CharShowcase/ShowcaseFrame/VBox/CharTitle.text = data.title

	var holder: CenterContainer = $CharShowcase/ShowcaseFrame/VBox/SpriteHolder
	
	# 停止旧的动画
	if _showcase_tween and _showcase_tween.is_valid():
		_showcase_tween.kill()
		_showcase_tween = null
	
	# 获取或创建 TextureRect
	var tex_rect: TextureRect
	if holder.get_child_count() > 0 and holder.get_child(0) is TextureRect:
		tex_rect = holder.get_child(0) as TextureRect
	else:
		# 清除旧子节点
		for child in holder.get_children():
			child.queue_free()
		tex_rect = TextureRect.new()
		tex_rect.name = "CharTexture"
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(0, 90)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tex_rect)

	# 加载该角色的 walk 精灵帧
	var sprite_data = CHAR_SPRITES.get(char_id, CHAR_SPRITES[0])
	var frames: Array[Texture2D] = []
	for path in sprite_data["walk"]:
		var tex: Texture2D = load(path)
		if tex:
			frames.append(tex)
		else:
			push_warning("[Showcase] 无法加载: %s" % path)
	
	if frames.size() == 0:
		push_error("[Showcase] 没有加载到任何精灵帧")
		return
	
	# 创建循环 Tween 播放走路动画
	_showcase_tween = create_tween().set_loops()
	var frame_time := 0.18  # 每帧持续时间（约5.5fps，走路动画速度自然）
	for frame_tex in frames:
		# 注意：需要用闭包正确捕获当前帧纹理
		_showcase_tween.tween_callback(func(tf = frame_tex): tex_rect.texture = tf)
		_showcase_tween.tween_interval(frame_time)


func _show_menu_ui() -> void:
	$MenuBG.show()
	$MenuFX.show()
	$CharShowcase.show()
	_init_menu_fx()
	_refresh_char_showcase()
	$MenuFXTimer.start()


func _hide_menu_ui() -> void:
	$MenuBG.hide()
	$MenuFX.hide()
	$CharShowcase.hide()
	$MenuFXTimer.stop()


func _init_menu_fx() -> void:
	_menu_fx_time = 0.0
	_clouds.clear()
	_particles.clear()

	# 云雾条带 (y 坐标分布在山间区域) - 提高透明度让效果更明显
	_clouds = [
		{"base_y": 320, "w": 500, "h": 35, "speed": 12.0, "alpha": 0.18, "offset_x": 0.0},
		{"base_y": 380, "w": 450, "h": 28, "speed": -8.0, "alpha": 0.14, "offset_x": 0.0},
		{"base_y": 450, "w": 480, "h": 32, "speed": 15.0, "alpha": 0.16, "offset_x": 0.0},
		{"base_y": 270, "w": 200, "h": 22, "speed": -20.0, "alpha": 0.12, "offset_x": 60.0},
		{"base_y": 510, "w": 400, "h": 25, "speed": 10.0, "alpha": 0.10, "offset_x": -30.0},
	]

	# 灵气粒子 (在整个区域飘浮) - 增加数量和亮度
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(30):
		_particles.append({
			"base_x": rng.randf_range(20, _MENU_W - 20),
			"base_y": rng.randf_range(200, 580),
			"x": 0.0, "y": 0.0,
			"phase": rng.randf_range(0, TAU),
			"speed": rng.randf_range(0.4, 1.5),
			"drift": rng.randf_range(10, 30),
			"rise": rng.randf_range(12, 35),
			"size": rng.randf_range(2.0, 4.5),
			"alpha": rng.randf_range(0.4, 0.8),
		})


func _on_menu_fx_timer_timeout() -> void:
	_menu_fx_time += 0.033
	$MenuFX.queue_redraw()


func _on_menu_fx_draw() -> void:
	# ── 云雾流动 ──
	for cloud in _clouds:
		var offset: float = fmod(cloud.offset_x + cloud.speed * _menu_fx_time, cloud.w + 100) - 50
		_draw_cloud_band(cloud.base_y, cloud.w, cloud.h, offset, cloud.alpha)

	# ── 灵气粒子飘动 ──
	for p in _particles:
		var t: float = _menu_fx_time * p.speed + p.phase
		p.x = p.base_x + sin(t) * p.drift
		p.y = p.base_y - fmod(t * p.rise, _MENU_H)
		# 循环回到底部
		if p.y < 180:
			p.y += 420
		var pulse: float = 0.7 + 0.3 * sin(t * 2.0)
		# 淡金色/淡青色灵气粒子
		var col: Color = Color(0.7, 0.9, 1.0, p.alpha * pulse)
		$MenuFX.draw_circle(Vector2(p.x, p.y), p.size, col)
		# 外层光晕
		$MenuFX.draw_circle(Vector2(p.x, p.y), p.size * 3.0, Color(0.5, 0.85, 1.0, p.alpha * pulse * 0.25))
		# 最外层柔光
		$MenuFX.draw_circle(Vector2(p.x, p.y), p.size * 5.0, Color(0.6, 0.9, 1.0, p.alpha * pulse * 0.1))


func _draw_cloud_band(y: float, w: float, h: float, offset_x: float, alpha: float) -> void:
	# 云雾颜色：淡紫白色，更接近仙侠云雾感
	var color_mid := Color(0.85, 0.8, 0.95, alpha)
	var color_edge := Color(0.6, 0.55, 0.8, 0.0)
	var steps := int(h)
	for i in range(steps):
		var t: float = float(i) / float(max(steps - 1, 1))
		# 中间最亮，上下渐隐，使用平滑曲线
		var fade: float = 1.0 - abs(2.0 * t - 1.0)
		fade = fade * fade  # 更平滑的过渡
		var c := color_mid.lerp(color_edge, 1.0 - fade)
		$MenuFX.draw_line(Vector2(-50 + offset_x, y - h/2 + i), Vector2(-50 + w + offset_x, y - h/2 + i), c, 1.5)


# ═══════════════════════════════════════════
#  Button animation helpers
# ═══════════════════════════════════════════

func _animate_button(btn: Button, hover_color: Color, hover_scale: float, press_scale: float) -> void:
	btn.mouse_entered.connect(func():
		var t := create_tween().set_parallel(true)
		t.tween_property(btn, "modulate", hover_color, 0.12)
		t.tween_property(btn, "scale", Vector2(hover_scale, hover_scale), 0.12).set_ease(Tween.EASE_OUT)
	)

	btn.mouse_exited.connect(func():
		var t := create_tween().set_parallel(true)
		t.tween_property(btn, "modulate", Color.WHITE, 0.12)
		t.tween_property(btn, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)
	)

	btn.button_down.connect(func():
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(press_scale, press_scale), 0.06).set_ease(Tween.EASE_IN)
	)

	btn.button_up.connect(func():
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(hover_scale, hover_scale), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	)


# ═══════════════════════════════════════════
#  Panel transition helpers
# ═══════════════════════════════════════════

func _show_panel_animated(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2
	panel.modulate.a = 0
	panel.scale = Vector2(0.6, 0.6)
	panel.show()
	var t := create_tween().set_parallel(true)
	t.tween_property(panel, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "scale", Vector2.ONE, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _hide_panel_animated(panel: Control) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(panel, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_IN)
	t.tween_property(panel, "scale", Vector2(0.6, 0.6), 0.20).set_ease(Tween.EASE_IN)
	t.finished.connect(func(): panel.hide())


# ═══════════════════════════════════════════
#  Score flash effect
# ═══════════════════════════════════════════

func _flash_score() -> void:
	var label := $ScoreLabel
	var t := create_tween()
	t.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.08)
	t.tween_property(label, "modulate", Color(1, 0.85, 0.2, 1), 0.15)


# ═══════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════

func show_message(text: String) -> void:
	$MessageGlow.text = text
	$Message.text = text
	$Message.show()
	$MessageGlow.show()
	$MessageTimer.start()


func show_game_over(final_score: int) -> void:
	_rainbow_active = false
	show_message("游戏结束!")
	$Message.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	$MessageGlow.add_theme_color_override("font_color", Color(1, 0.1, 0.1, 0.3))
	await $MessageTimer.timeout

	# 立即显示结算面板，确保始终有可交互的按钮
	$GameOverPanel/VBoxContainer/ScoreDisplay.text = "得分: " + str(final_score)
	$GameOverPanel/VBoxContainer/StatusLabel.text = "查询排行榜中..."
	$GameOverPanel/VBoxContainer/StatusLabel.show()
	$GameOverPanel/VBoxContainer/NameInput.text = ""
	$GameOverPanel/VBoxContainer/NameInput.hide()
	$GameOverPanel/VBoxContainer/SubmitButton.hide()
	_show_panel_animated($GameOverPanel)

	# 异步查询服务器能否上榜
	Leaderboard.check_would_rank(final_score, func(will_rank: bool):
		if will_rank:
			$GameOverPanel/VBoxContainer/StatusLabel.hide()
			$GameOverPanel/VBoxContainer/NameInput.show()
			$GameOverPanel/VBoxContainer/SubmitButton.show()
			$GameOverPanel/VBoxContainer/NameInput.grab_focus()
		else:
			$GameOverPanel/VBoxContainer/StatusLabel.text = "未入排行"
	)


func update_score(score: int) -> void:
	$ScoreLabel.text = str(score)
	_flash_score()


# ═══════════════════════════════════════════
#  Mode selection
# ═══════════════════════════════════════════

var _selecting_for_player: int = 0   # 1 = P1, 2 = P2
var _pending_mode: StringName = &""  # "single" | "duo"
var _char_select_panel: Control = null
var _char_cards: Array = []           # 卡片引用列表
var _char_badges: Array = []          # 每张卡片的选中标识 Label
var _selected_card_index: int = -1    # 当前选中的卡片索引
var _confirm_button: Button = null    # "选择当前角色" 按钮引用

func _hide_all_buttons() -> void:
	$SingleButton.hide()
	$DuoButton.hide()
	$SettingsButton.hide()
	$LeaderboardButton.hide()
	_hide_menu_ui()


# ═══════════════════════════════════════════
#  角色选择面板（动态创建）
# ═══════════════════════════════════════════

func _show_character_select(for_player: int, mode: StringName = &"") -> void:
	_hide_character_select()  # 清理旧面板（会重置 _selecting_for_player = 0）
	_selecting_for_player = for_player  # 必须在 _hide_character_select 之后赋值

	_rainbow_active = false
	var player_label := "玩家 %d" % for_player
	if mode != &"":
		_pending_mode = mode
	elif _pending_mode == &"":
		_pending_mode = &"single" if for_player == 1 else &"duo"

	var panel := PanelContainer.new()
	panel.name = "CharSelectPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -280)
	panel.size = Vector2(380, 560)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.18, 0.97)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.5, 0.35, 0.9, 1)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.shadow_size = 20
	style.shadow_color = Color(0.3, 0.15, 0.6, 0.5)
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 标题
	var title := Label.new()
	title.text = "%s — 选择你的角色" % player_label
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	# 角色卡片列表
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var card_list := VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 8)
	card_list.custom_minimum_size = Vector2(346, 0)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for i in Characters.ROSTER.size():
		var card := _create_character_card(Characters.ROSTER[i], i)
		_char_cards.append(card)
		card_list.add_child(card)

	# 恢复上次选择的高亮
	var prev_id := Characters.p1_character if for_player == 1 else Characters.p2_character
	if prev_id >= 0 and prev_id < _char_cards.size():
		_selected_card_index = prev_id
		_apply_card_selection_style()
		# 同步确认按钮文字
		if _confirm_button:
			var char_data := Characters.get_character(prev_id)
			_confirm_button.text = "✦ %s — 确认" % char_data.name

	scroll.add_child(card_list)
	vbox.add_child(scroll)

	# 底部按钮行
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.add_theme_font_size_override("font_size", 28)
	back_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	back_btn.custom_minimum_size = Vector2(110, 52)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.2, 0.15, 0.35, 1)
	back_style.border_width_left = 2
	back_style.border_width_top = 2
	back_style.border_width_right = 2
	back_style.border_width_bottom = 2
	back_style.border_color = Color(0.4, 0.3, 0.6, 1)
	back_style.corner_radius_top_left = 14
	back_style.corner_radius_top_right = 14
	back_style.corner_radius_bottom_right = 14
	back_style.corner_radius_bottom_left = 14
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.pressed.connect(func():
		_hide_character_select()
		_show_main_menu()
	)
	btn_row.add_child(back_btn)

	# "选好了" 按钮
	var confirm_btn := Button.new()
	confirm_btn.text = "选择当前角色"
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size = Vector2(0, 52)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.6, 0.25, 0.8, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.8, 0.45, 1, 1)
	btn_style.corner_radius_top_left = 14
	btn_style.corner_radius_top_right = 14
	btn_style.corner_radius_bottom_right = 14
	btn_style.corner_radius_bottom_left = 14
	btn_style.shadow_size = 8
	btn_style.shadow_color = Color(0.3, 0.1, 0.5, 0.5)
	btn_style.shadow_offset = Vector2(0, 3)
	confirm_btn.add_theme_stylebox_override("normal", btn_style)
	confirm_btn.pressed.connect(_on_character_confirmed)
	_confirm_button = confirm_btn
	btn_row.add_child(confirm_btn)

	vbox.add_child(btn_row)

	panel.add_child(vbox)
	add_child(panel)
	_char_select_panel = panel

	_show_panel_animated(panel)


## 递归将所有 Control 子节点设为 MOUSE_FILTER_IGNORE，让鼠标事件穿透到父级
func _recursive_ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_recursive_ignore_mouse(child)


func _create_character_card(char_data: Dictionary, index: int) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(346, 0)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.08, 0.25, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.3, 0.2, 0.5, 1)
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.content_margin_left = 10
	card_style.content_margin_top = 10
	card_style.content_margin_right = 10
	card_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", card_style)

	# 主布局：外层 VBox [顶部行: icon + 名称, 底部: 属性条]
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ── 顶部行：图标 + 名称/描述 ──
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)

	# 图标
	var icon_label := Label.new()
	icon_label.text = char_data.icon
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.custom_minimum_size = Vector2(40, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(icon_label)

	# 信息区（名称 + 描述，全宽自动换行）
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 3)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = "%s · %s" % [char_data.title, char_data.name]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = char_data.desc
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.75))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(desc_label)

	top_row.add_child(info_vbox)
	main_vbox.add_child(top_row)

	# ── 底部属性条：全宽独立行 ──
	var stat_label := Label.new()
	stat_label.text = "⚡ " + char_data.stats.desc + "　｜　🗡 " + char_data.weapon
	stat_label.add_theme_font_size_override("font_size", 13)
	stat_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(stat_label)

	# ── 选中标识（默认隐藏） ──
	var badge := Label.new()
	badge.name = "SelectionBadge"
	badge.text = "✦ 已选择"
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.hide()
	main_vbox.add_child(badge)
	_char_badges.append(badge)

	card.add_child(main_vbox)

	# ⚡ 关键：让子节点不拦截鼠标事件，确保 gui_input 到达 PanelContainer
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_recursive_ignore_mouse(main_vbox)

	# 点击选择
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_character_picked(index)
	)

	# Hover 效果 — 只在卡片非选中时生效
	card.mouse_entered.connect(func():
		if _selected_card_index == index:
			return
		card_style.bg_color = Color(0.2, 0.12, 0.4, 1)
		card_style.border_color = Color(0.6, 0.4, 0.9, 1)
		card.add_theme_stylebox_override("panel", card_style)
	)
	card.mouse_exited.connect(func():
		if _selected_card_index == index:
			return
		card_style.bg_color = Color(0.12, 0.08, 0.25, 1)
		card_style.border_color = Color(0.3, 0.2, 0.5, 1)
		card.add_theme_stylebox_override("panel", card_style)
	)

	return card


func _on_character_picked(char_id: int) -> void:
	_selected_card_index = char_id
	_apply_card_selection_style()

	# 选中动画：短促弹跳
	if char_id >= 0 and char_id < _char_cards.size():
		var card := _char_cards[char_id] as Control
		var t := create_tween()
		t.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# 更新确认按钮文字
	if _confirm_button:
		var char_data := Characters.get_character(char_id)
		var label_text := "✦ %s — 确认" % char_data.name
		_confirm_button.text = label_text

	if _selecting_for_player == 1:
		Characters.p1_character = char_id
		print("[HUD] P1 选择了角色 %d (%s)" % [char_id, Characters.get_character(char_id).name])
		show_message("P1: " + Characters.get_character(char_id).name)
		# 刷新主菜单的角色展示
		_refresh_char_showcase()
	elif _selecting_for_player == 2:
		Characters.p2_character = char_id
		print("[HUD] P2 选择了角色 %d (%s)" % [char_id, Characters.get_character(char_id).name])
		show_message("P2: " + Characters.get_character(char_id).name)


## 将所有卡片的样式更新为选中/未选中状态，同时控制选中标识的显隐
func _apply_card_selection_style() -> void:
	for i in _char_cards.size():
		var card := _char_cards[i] as PanelContainer
		var style := card.get_theme_stylebox("panel", "PanelContainer")
		if not style is StyleBoxFlat:
			continue

		# 控制选中标识
		if i < _char_badges.size():
			var badge := _char_badges[i] as Label
			if badge:
				badge.visible = (i == _selected_card_index)

		if i == _selected_card_index:
			# 选中态：亮紫光晕边框 + 高亮背景 + 发光阴影
			style.bg_color = Color(0.22, 0.12, 0.42, 1)
			style.border_color = Color(0.85, 0.45, 1, 1)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.shadow_size = 16
			style.shadow_color = Color(0.6, 0.25, 1, 0.7)
			style.shadow_offset = Vector2(0, 2)
			# 内容 margin 稍增大，抵消加粗边框的挤压
			style.content_margin_left = 10
			style.content_margin_top = 10
			style.content_margin_right = 10
			style.content_margin_bottom = 10
		else:
			# 未选中态：暗色背景 + 细边框
			style.bg_color = Color(0.12, 0.08, 0.25, 1)
			style.border_color = Color(0.3, 0.2, 0.5, 1)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.shadow_size = 0
			style.shadow_color = Color(0, 0, 0, 0)
			style.content_margin_left = 10
			style.content_margin_top = 10
			style.content_margin_right = 10
			style.content_margin_bottom = 10

		card.add_theme_stylebox_override("panel", style)


func _on_character_confirmed() -> void:
	# 保护：检查是否已选择角色
	if _selected_card_index < 0 or _selected_card_index >= Characters.ROSTER.size():
		show_message("⚠ 请先选择一个角色！")
		return

	if _selecting_for_player == 1 and _pending_mode == &"duo":
		# 双人模式：P1 选完后选 P2
		_hide_panel_animated(_char_select_panel)
		await get_tree().create_timer(0.25).timeout
		_show_character_select(2, &"duo")
		return

	# 保存 _pending_mode 再清理，否则 emit 时已经是空字符串
	var mode := _pending_mode
	print("[HUD] 角色确认 — 发射 start_game(%s)" % mode)
	_hide_character_select()
	_hide_menu_ui()
	Characters.save_selection()
	await get_tree().create_timer(0.2).timeout
	start_game.emit(mode)


func _hide_character_select() -> void:
	_char_cards.clear()
	_char_badges.clear()
	_confirm_button = null
	_selected_card_index = -1
	if _char_select_panel:
		_char_select_panel.queue_free()
		_char_select_panel = null
	_selecting_for_player = 0

func _on_single_button_pressed() -> void:
	_hide_all_buttons()
	$GameOverPanel.hide()
	$LeaderboardPanel.hide()
	$SettingsPanel.hide()
	_show_character_select(1, &"single")  # 单人模式：选P1角色

func _on_duo_button_pressed() -> void:
	_hide_all_buttons()
	$GameOverPanel.hide()
	$LeaderboardPanel.hide()
	$SettingsPanel.hide()
	_show_character_select(1, &"duo")  # 双人模式：先选P1角色


# ── Settings ──

func _on_settings_button_pressed() -> void:
	_hide_all_buttons()
	# Refresh picker values in case they were changed elsewhere
	$SettingsPanel/VBoxContainer/P1Row/P1ColorPicker.color = Settings.p1_color
	$SettingsPanel/VBoxContainer/P2Row/P2ColorPicker.color = Settings.p2_color
	_show_panel_animated($SettingsPanel)


func _on_settings_back_pressed() -> void:
	Settings.save()
	_hide_panel_animated($SettingsPanel)
	await get_tree().create_timer(0.2).timeout
	_show_main_menu()


func _on_p1_color_changed(color: Color) -> void:
	Settings.p1_color = color


func _on_p2_color_changed(color: Color) -> void:
	Settings.p2_color = color


# ═══════════════════════════════════════════
#  Other signal callbacks
# ═══════════════════════════════════════════

func _on_message_timer_timeout() -> void:
	$Message.hide()
	$MessageGlow.hide()


func _on_leaderboard_button_pressed() -> void:
	_hide_all_buttons()
	_show_leaderboard()


func _on_submit_button_pressed() -> void:
	var input_name: String = $GameOverPanel/VBoxContainer/NameInput.text.strip_edges()
	if input_name == "":
		input_name = "无名玩家"
	if input_name.length() > 8:
		input_name = input_name.substr(0, 8)

	var score_text: String = $GameOverPanel/VBoxContainer/ScoreDisplay.text
	var final_score: int = int(score_text.replace("得分: ", ""))

	Leaderboard.submit_score(input_name, final_score)
	_hide_panel_animated($GameOverPanel)
	await get_tree().create_timer(0.5).timeout   # 等服务器提交完成
	_show_leaderboard()


func _on_game_over_menu_pressed() -> void:
	_hide_panel_animated($GameOverPanel)
	await get_tree().create_timer(0.2).timeout
	_show_main_menu()


func _on_game_over_leaderboard_pressed() -> void:
	_hide_panel_animated($GameOverPanel)
	await get_tree().create_timer(0.2).timeout
	_show_leaderboard()


func _on_back_button_pressed() -> void:
	_hide_panel_animated($LeaderboardPanel)
	await get_tree().create_timer(0.2).timeout
	_show_main_menu()


# ═══════════════════════════════════════════
#  Leaderboard display
# ═══════════════════════════════════════════

func _show_leaderboard() -> void:
	var lb := Leaderboard.get_leaderboard()
	var entries_node := $LeaderboardPanel/VBoxContainer/Entries

	for child in entries_node.get_children():
		child.queue_free()

	if lb.is_empty():
		var label := Label.new()
		label.text = "暂无记录"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		entries_node.add_child(label)
	else:
		for i in range(lb.size()):
			var entry = lb[i]
			entries_node.add_child(_make_rank_row(i, entry.name, entry.score))

	_show_panel_animated($LeaderboardPanel)


func _make_rank_row(rank: int, player_name: String, score: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ── 排名徽章 ──
	var rank_data := _rank_style(rank)
	var badge := Label.new()
	badge.text = rank_data.icon
	badge.add_theme_font_size_override("font_size", rank_data.font_size)
	badge.add_theme_color_override("font_color", rank_data.color)
	badge.custom_minimum_size = Vector2(48, 0)
	row.add_child(badge)

	# ── 玩家名（左对齐，自动撑满） ──
	var name_label := Label.new()
	name_label.text = player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", rank_data.font_size)
	name_label.add_theme_color_override("font_color", rank_data.color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	# ── 分数（右对齐） ──
	var score_label := Label.new()
	score_label.text = "%d 分" % score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", rank_data.font_size)
	score_label.add_theme_color_override("font_color", rank_data.color)
	score_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(score_label)

	return row


func _rank_style(rank: int) -> Dictionary:
	match rank:
		0: return {
			"icon": "👑",
			"font_size": 34,
			"color": Color(1, 0.85, 0.1),       # 鎏金
		}
		1: return {
			"icon": "🥈",
			"font_size": 30,
			"color": Color(0.85, 0.88, 0.92),   # 银白
		}
		2: return {
			"icon": "🥉",
			"font_size": 28,
			"color": Color(0.92, 0.55, 0.35),   # 铜色
		}
		_: return {
			"icon": "  %d" % (rank + 1),
			"font_size": 24,
			"color": Color(0.6, 0.65, 0.72),    # 灰色
		}


# ═══════════════════════════════════════════
#  Main menu
# ═══════════════════════════════════════════

func _show_main_menu() -> void:
	$GameOverPanel.hide()
	_hide_character_select()  # 清理角色选择面板
	_selecting_for_player = 0
	_pending_mode = &""
	# 重置分数显示
	$ScoreLabel.text = "0"
	# 主菜单使用固定古风金配色，不使用彩虹效果
	$Message.add_theme_color_override("font_color", Color(1, 0.88, 0.45))
	$MessageGlow.add_theme_color_override("font_color", Color(1, 0.88, 0.45, 0.2))
	_rainbow_active = false
	$RainbowTimer.stop()
	$Message.text = "修仙奇缘"
	$MessageGlow.text = "修仙奇缘"
	$Message.show()
	$MessageGlow.show()
	_show_menu_ui()
	$SingleButton.show()
	$DuoButton.show()
	$SettingsButton.show()
	$LeaderboardButton.show()
	for btn in [$SingleButton, $DuoButton, $SettingsButton, $LeaderboardButton]:
		btn.scale = Vector2(0.5, 0.5)
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
