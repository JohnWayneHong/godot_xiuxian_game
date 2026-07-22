extends Node

enum GameMode { SINGLE, DUO }

@export var mob_scene: PackedScene
var score: int
var game_mode: GameMode

# 复活圈脚本
const ReviveZoneScript = preload("res://revive_zone.gd")

# 玩家
@onready var player1: Area2D = $Player1
var player2: Area2D = null        # 双人模式才创建

# 复活状态 (仅双人模式)
var _revive_zone: Area2D = null
var _dead_player_id: int = 0
var _revive_position: Vector2


# ═══════════════════════════════════════════
#  初始化
# ═══════════════════════════════════════════

func _ready() -> void:
	if $Music and $Music.stream:
		$Music.stream.loop = true
	player1.hit.connect(_on_player1_hit)


func _process(_delta: float) -> void:
	pass


# ═══════════════════════════════════════════
#  游戏开始 (由 HUD 信号触发)
# ═══════════════════════════════════════════

func new_game(mode: StringName = &"single") -> void:
	print("[Main] new_game(mode=%s)" % mode)
	_clear_revive_zone()
	score = 0
	_dead_player_id = 0

	if mode == &"duo":
		game_mode = GameMode.DUO
		_setup_duo_mode()
	else:
		game_mode = GameMode.SINGLE
		_setup_single_mode()


func _setup_single_mode() -> void:
	print("[Main] _setup_single_mode — p1_character=%d, speed=%d" % [Characters.p1_character, Characters.get_character(Characters.p1_character).stats.speed])
	player1.character_id = Characters.p1_character
	player1.speed = Characters.get_character(Characters.p1_character).stats.speed
	player1.start($StartPosition1.position)

	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("单人模式")
	$Music.play()


func _setup_duo_mode() -> void:
	if player2 == null:
		_create_player2()

	print("[Main] _setup_duo_mode — p1=%d, p2=%d" % [Characters.p1_character, Characters.p2_character])
	player1.character_id = Characters.p1_character
	player1.speed = Characters.get_character(Characters.p1_character).stats.speed
	player2.character_id = Characters.p2_character
	player2.speed = Characters.get_character(Characters.p2_character).stats.speed
	player1.start($StartPosition1.position)
	player2.start($StartPosition2.position)

	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("双人模式")
	$Music.play()


func _create_player2() -> void:
	var player_scene := preload("res://player.tscn")
	player2 = player_scene.instantiate()
	player2.name = "Player2"
	player2.player_id = 2
	add_child(player2)
	player2.hit.connect(_on_player2_hit)


# ═══════════════════════════════════════════
#  游戏结束
# ═══════════════════════════════════════════

func game_over() -> void:
	$ScoreTimer.stop()
	$MobTimer.stop()
	$HUD.show_game_over(score)
	$Music.stop()
	$DeathSound.play()
	_clear_revive_zone()


# ═══════════════════════════════════════════
#  计时器
# ═══════════════════════════════════════════

func _on_score_timer_timeout() -> void:
	score += 1
	$HUD.update_score(score)


func _on_start_timer_timeout() -> void:
	$MobTimer.start()
	$ScoreTimer.start()


func _on_mob_timer_timeout() -> void:
	var mob = mob_scene.instantiate()
	var mob_spawn_location = $MobPath/MobSpawnLocation
	mob_spawn_location.progress_ratio = randf()
	mob.position = mob_spawn_location.position
	var direction = mob_spawn_location.rotation + PI / 2
	direction += randf_range(-PI / 4, PI / 4)
	mob.rotation = direction
	var velocity = Vector2(randf_range(150.0, 250.0), 0.0)
	mob.linear_velocity = velocity.rotated(direction)
	add_child(mob)


# ═══════════════════════════════════════════
#  单人模式 — 玩家阵亡
# ═══════════════════════════════════════════

func _on_player1_hit() -> void:
	match game_mode:
		GameMode.SINGLE:
			game_over()
		GameMode.DUO:
			player1.die()
			_handle_duo_death(1)


func _on_player2_hit() -> void:
	player2.die()
	_handle_duo_death(2)


# ═══════════════════════════════════════════
#  双人模式 — 死亡 / 复活
# ═══════════════════════════════════════════

func _handle_duo_death(which_id: int) -> void:
	# 两人全死 → 游戏结束（必须先检查，否则 revive_zone 会短路）
	if not _is_player_alive(1) and not _is_player_alive(2):
		game_over()
		return

	# 已有复活圈则忽略
	if _revive_zone != null:
		return

	var dead_player: Area2D = player1 if which_id == 1 else player2
	_dead_player_id = which_id
	_revive_position = dead_player.position
	_spawn_revive_zone(_revive_position)


func _is_player_alive(which_id: int) -> bool:
	if which_id == 1:
		return player1.get_is_alive()
	return player2 != null and player2.get_is_alive()


func _spawn_revive_zone(pos: Vector2) -> void:
	_clear_revive_zone()
	var zone := Area2D.new()
	zone.set_script(ReviveZoneScript)
	zone.position = pos
	zone.revive_complete.connect(_on_revive_complete)
	add_child(zone)
	_revive_zone = zone


func _clear_revive_zone() -> void:
	if _revive_zone:
		_revive_zone.queue_free()
		_revive_zone = null


func _on_revive_complete() -> void:
	var player: Area2D = player1 if _dead_player_id == 1 else player2
	player.revive(_revive_position)
	_dead_player_id = 0
	_clear_revive_zone()
