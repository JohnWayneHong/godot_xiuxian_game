extends Node
## 全球排行榜 — HTTP 联网版 (兼容本地降级)

const API_URL := "http://114.132.56.13:4399/api/leaderboard"
const SECRET := "24401005c9a34efc94d59bcb44e9d15a"  # 必须和服务器相同！

var scores: Array = []  # 从服务器拉取的排行
var _local_cache: Array = []  # 本地缓存（服务器挂了也不丢）


# ═══════════════════════════════════════════
#  Initialization
# ═══════════════════════════════════════════

func _ready() -> void:
	# 先加载本地缓存
	_load_local_cache()
	# 异步拉服务器排行
	refresh_leaderboard()


# ═══════════════════════════════════════════
#  获取排行（异步 HTTP GET）
# ═══════════════════════════════════════════

func refresh_leaderboard() -> void:
	var http := _make_http()
	http.request_completed.connect(_on_leaderboard_response.bind(http))
	http.request(API_URL)


func _on_leaderboard_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.data
			if data is Dictionary:
				scores = data.get("leaderboard", [])
				_save_local_cache()
				http.queue_free()
				return
	# 服务器挂了 → 降级用本地缓存
	scores = _local_cache.duplicate()
	http.queue_free()


# ═══════════════════════════════════════════
#  检查能否上榜（异步 HTTP GET + callback）
# ═══════════════════════════════════════════

func check_would_rank(score: int, callback: Callable) -> void:
	var http := _make_http()
	http.timeout = 5  # 5 秒超时，防止服务器不可达时永久挂起
	var _handled := false

	var _respond := func(will_rank: bool) -> void:
		if _handled:
			return
		_handled = true
		callback.call(will_rank)
		http.queue_free()

	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var json := JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var data = json.data
				if data is Dictionary:
					_respond.call(data.get("will_rank", false))
					return
		# 服务器挂了 / 超时 → 本地判断
		_respond.call(_local_is_top5(score))
	)
	http.request(API_URL + "/check?score=" + str(score))


# ═══════════════════════════════════════════
#  提交分数（异步 HTTP POST）
# ═══════════════════════════════════════════

func submit_score(player_name: String, player_score: int) -> void:
	var clean_name := player_name.strip_edges().substr(0, 8)
	if clean_name == "": clean_name = "无名"

	var token := _make_token(clean_name, player_score)
	var body := JSON.stringify({"name": clean_name, "score": player_score, "token": token})

	var http := _make_http()
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
		# 提交后刷新排行
		refresh_leaderboard()
	)
	http.request(API_URL, [], HTTPClient.METHOD_POST, body)

	# 同时存本地缓存
	_local_submit(clean_name, player_score)


# ═══════════════════════════════════════════
#  同步 getter（给 HUD 用 — 返回当前已缓存数据）
# ═══════════════════════════════════════════

func get_leaderboard() -> Array:
	if scores.is_empty():
		return _local_cache
	return scores


# ═══════════════════════════════════════════
#  Helpers
# ═══════════════════════════════════════════

func _make_http() -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	return http


func _make_token(clean_name: String, score: int) -> String:
	var raw := clean_name + ":" + str(score) + ":" + SECRET
	return raw.sha256_text().substr(0, 16)


# ═══════════════════════════════════════════
#  本地缓存（降级方案）
# ═══════════════════════════════════════════

const LOCAL_SAVE_PATH := "user://leaderboard.json"

func _local_is_top5(score: int) -> bool:
	if _local_cache.size() < 5:
		return true
	return score > _local_cache[-1].score


func _local_submit(clean_name: String, score: int) -> void:
	_local_cache.append({"name": clean_name, "score": score})
	_local_cache.sort_custom(func(a, b): return a.score > b.score)
	if _local_cache.size() > 5:
		_local_cache = _local_cache.slice(0, 5)
	_save_local_cache()


func _save_local_cache() -> void:
	var file := FileAccess.open(LOCAL_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_local_cache))
		file.close()


func _load_local_cache() -> void:
	if FileAccess.file_exists(LOCAL_SAVE_PATH):
		var file := FileAccess.open(LOCAL_SAVE_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.data
				if data is Array:
					_local_cache = data
			file.close()
