extends Node
## 设置管理 — 自动加载单例，保存玩家颜色偏好

const SAVE_PATH := "user://settings.json"

## 默认颜色 (P1 蓝, P2 红)
var p1_color: Color = Color(0.4, 0.7, 1.0)
var p2_color: Color = Color(1.0, 0.35, 0.3)


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if data is Dictionary:
		if data.has("p1"):
			p1_color = Color.html(data["p1"])
		if data.has("p2"):
			p2_color = Color.html(data["p2"])


func save() -> void:
	var data := {
		"p1": p1_color.to_html(false),
		"p2": p2_color.to_html(false),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
