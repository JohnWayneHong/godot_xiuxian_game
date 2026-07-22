extends Node
## 角色数据管理 — 自动加载单例
## 管理5个仙侠角色的定义、选择和配置

# 角色选择状态
var p1_character: int = 0  # 玩家1选择的角色ID
var p2_character: int = 1  # 玩家2选择的角色ID

const SAVE_PATH := "user://characters.json"

## 角色定义数据
const ROSTER: Array[Dictionary] = [
	{
		"id": 0,
		"name": "剑修·凌霄",
		"title": "御剑乘风",
		"desc": "白衣剑客，以气驭剑。剑光所至，万邪辟易。",
		"icon": "⚔️",
		"color_hex": "#c8ddf8",
		"color_name": "霜白",
		"stats": {"speed": 420, "desc": "移速 +5%"},
		"weapon": "青霜剑",
	},
	{
		"id": 1,
		"name": "符师·玄机",
		"title": "符箓通神",
		"desc": "黄袍符师，挥手成阵。一张符纸定乾坤。",
		"icon": "📜",
		"color_hex": "#f5e6a3",
		"color_name": "符金",
		"stats": {"speed": 380, "desc": "受击后有短暂无敌"},
		"weapon": "镇魂符",
	},
	{
		"id": 2,
		"name": "丹修·青囊",
		"title": "丹心济世",
		"desc": "绿衣丹师，炉火纯青。一枚灵丹可回春。",
		"icon": "🧪",
		"color_hex": "#a8e6c8",
		"color_name": "翠微",
		"stats": {"speed": 390, "desc": "复活时间 -20%"},
		"weapon": "回春炉",
	},
	{
		"id": 3,
		"name": "体修·金刚",
		"title": "不坏金身",
		"desc": "赤膊体修，拳碎山河。肉身成圣我为峰。",
		"icon": "👊",
		"color_hex": "#f0c8a0",
		"color_name": "赤铜",
		"stats": {"speed": 360, "desc": "碰撞判定 -15%"},
		"weapon": "金刚拳",
	},
	{
		"id": 4,
		"name": "灵兽师·瑶光",
		"title": "万灵归一",
		"desc": "紫衣灵师，百兽随行。灵狐相伴闯天涯。",
		"icon": "🦊",
		"color_hex": "#d8b8f0",
		"color_name": "紫霞",
		"stats": {"speed": 400, "desc": "身边环绕护体灵兽"},
		"weapon": "唤灵笛",
	},
]


func _ready() -> void:
	load_selection()


## 获取角色数据
func get_character(id: int) -> Dictionary:
	if id >= 0 and id < ROSTER.size():
		return ROSTER[id]
	return ROSTER[0]


## 保存角色选择
func save_selection() -> void:
	var data := {
		"p1": p1_character,
		"p2": p2_character,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


## 加载角色选择
func load_selection() -> void:
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
			p1_character = int(data["p1"])
		if data.has("p2"):
			p2_character = int(data["p2"])
