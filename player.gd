extends Area2D
## 玩家 — 支持双人控制、阵亡/复活、无敌闪烁、角色选择

signal hit

@export var speed: float = 400          # 移动速度 (像素/秒)
@export var player_id: int = 1          # 1 = WASD, 2 = 方向键
@export var character_id: int = 0       # 角色ID (0=剑修 1=符师 2=丹修 3=体修 4=灵兽师)
@export var base_color: Color = Color.WHITE  # 保留兼容性，不再用于着色

var screen_size: Vector2
var is_alive: bool = true
var is_invincible: bool = false

var _invincible_time: float = 0.0
var _flash_timer: float = 0.0
var _flash_visible: bool = true

# 按键映射（根据 player_id 设置）
var _input_right: String
var _input_left: String
var _input_up: String
var _input_down: String

## 角色精灵路径表
const CHAR_SPRITES: Dictionary = {
	0: { # 剑修
		"walk": ["res://art/chars/0_jianxiu_walk1.png", "res://art/chars/0_jianxiu_walk2.png"],
		"up":   ["res://art/chars/0_jianxiu_up1.png",   "res://art/chars/0_jianxiu_up2.png"],
	},
	1: { # 符师
		"walk": ["res://art/chars/1_fushi_walk1.png", "res://art/chars/1_fushi_walk2.png"],
		"up":   ["res://art/chars/1_fushi_up1.png",   "res://art/chars/1_fushi_up2.png"],
	},
	2: { # 丹修
		"walk": ["res://art/chars/2_danxiu_walk1.png", "res://art/chars/2_danxiu_walk2.png"],
		"up":   ["res://art/chars/2_danxiu_up1.png",   "res://art/chars/2_danxiu_up2.png"],
	},
	3: { # 体修
		"walk": ["res://art/chars/3_tixiu_walk1.png", "res://art/chars/3_tixiu_walk2.png"],
		"up":   ["res://art/chars/3_tixiu_up1.png",   "res://art/chars/3_tixiu_up2.png"],
	},
	4: { # 灵兽师
		"walk": ["res://art/chars/4_lingshou_walk1.png", "res://art/chars/4_lingshou_walk2.png"],
		"up":   ["res://art/chars/4_lingshou_up1.png",   "res://art/chars/4_lingshou_up2.png"],
	},
}


func _ready() -> void:
	screen_size = get_viewport_rect().size
	add_to_group("player")
	_set_inputs()
	$AnimatedSprite2D.modulate = Color.WHITE  # 无颜色遮罩
	hide()


## 根据 character_id 加载对应的精灵帧
func _setup_character_sprites() -> void:
	print("[Player %d] _setup_character_sprites() — 加载角色ID=%d" % [player_id, character_id])
	var data = CHAR_SPRITES.get(character_id)
	if data == null:
		push_warning("[Player] 未知角色ID: %d，回退到剑修" % character_id)
		data = CHAR_SPRITES.get(0)
		if data == null:
			return

	var sf := SpriteFrames.new()

	# walk 动画
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", 5.0)
	for path in data["walk"]:
		var tex: Texture2D = load(path)
		if tex:
			sf.add_frame("walk", tex, 1.0)
			print("[Player %d]   ✓ 加载: %s" % [player_id, path])
		else:
			push_warning("[Player] 无法加载纹理: %s" % path)

	# up 动画
	sf.add_animation("up")
	sf.set_animation_loop("up", true)
	sf.set_animation_speed("up", 5.0)
	for path in data["up"]:
		var tex: Texture2D = load(path)
		if tex:
			sf.add_frame("up", tex, 1.0)
			print("[Player %d]   ✓ 加载: %s" % [player_id, path])
		else:
			push_warning("[Player] 无法加载纹理: %s" % path)

	# 替换精灵帧并强制重启动画
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.stop()
	sprite.sprite_frames = sf
	sprite.animation = &"walk"
	print("[Player %d]   精灵帧已替换，当前动画: %s" % [player_id, sprite.animation])


func _set_inputs() -> void:
	if player_id == 1:
		_input_right = "move_right"
		_input_left  = "move_left"
		_input_up    = "move_up"
		_input_down  = "move_down"
	else:
		_input_right = "p2_right"
		_input_left  = "p2_left"
		_input_up    = "p2_up"
		_input_down  = "p2_down"


# ── 存活查询（供复活圈调用） ──

func get_is_alive() -> bool:
	return is_alive


# ── 每帧 ──

func _process(delta: float) -> void:
	if not is_alive:
		return

	# 无敌闪烁（仅透明度变化，无颜色遮罩）
	if is_invincible:
		_invincible_time -= delta
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = 0.08
			_flash_visible = not _flash_visible
			$AnimatedSprite2D.modulate.a = 1.0 if _flash_visible else 0.2
		if _invincible_time <= 0.0:
			is_invincible = false
			$AnimatedSprite2D.modulate = Color.WHITE

	# 移动
	var velocity := Vector2.ZERO
	if Input.is_action_pressed(_input_right):  velocity.x += 1
	if Input.is_action_pressed(_input_left):   velocity.x -= 1
	if Input.is_action_pressed(_input_down):   velocity.y += 1
	if Input.is_action_pressed(_input_up):     velocity.y -= 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.stop()

	if velocity.x != 0:
		$AnimatedSprite2D.animation = "walk"
		$AnimatedSprite2D.flip_v = false
		$AnimatedSprite2D.flip_h = velocity.x < 0
	elif velocity.y != 0:
		$AnimatedSprite2D.animation = "up"
		$AnimatedSprite2D.flip_v = velocity.y > 0

	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)


# ── 碰撞 ──

func _on_body_entered(_body: Node2D) -> void:
	if is_invincible or not is_alive:
		return
	is_alive = false
	hide()
	hit.emit()
	$CollisionShape2D.set_deferred("disabled", true)


# ── 开局 / 阵亡 / 复活 ──

func start(pos: Vector2) -> void:
	print("[Player %d] start() — character_id=%d, speed=%d" % [player_id, character_id, speed])
	position = pos
	is_alive = true
	is_invincible = false
	_setup_character_sprites()  # 在 start 中加载，确保 character_id 已被 main.gd 设置
	$AnimatedSprite2D.modulate = Color.WHITE  # 无颜色遮罩
	show()
	$CollisionShape2D.disabled = false


func die() -> void:
	is_alive = false
	is_invincible = false
	hide()
	$CollisionShape2D.set_deferred("disabled", true)


func revive(pos: Vector2) -> void:
	position = pos
	is_alive = true
	is_invincible = true
	_invincible_time = 2.0
	_flash_timer = 0.08
	_flash_visible = true
	show()
	$CollisionShape2D.disabled = false
