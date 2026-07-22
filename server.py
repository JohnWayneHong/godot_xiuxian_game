#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dodge the Creeps — 全球排行榜服务端
纯 Python 标准库，无需 pip install
启动: python3 server.py
"""

import http.server
import json
import sqlite3
import hashlib
import time
import os
import urllib.parse

PORT = int(os.environ.get("PORT", 4399))
DB_PATH = os.environ.get("DB_PATH", "leaderboard.db")
SECRET = os.environ.get("SECRET_KEY", "change-me-to-something-random")

# ── 初始化数据库 ──
def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""CREATE TABLE IF NOT EXISTS scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        score INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    conn.commit()
    conn.close()

# ── Token 生成 ──
def make_token(name, score):
    raw = f"{name}:{score}:{SECRET}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]

# ── 数据库操作 ──
def db_query(sql, params=()):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.execute(sql, params)
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows

def db_execute(sql, params=()):
    conn = sqlite3.connect(DB_PATH)
    conn.execute(sql, params)
    conn.commit()
    conn.close()

# ── 速率限制 ──
RATE_LIMIT = {}  # ip -> timestamp

def check_rate(ip):
    now = time.time()
    if ip in RATE_LIMIT and now - RATE_LIMIT[ip] < 30:
        return False
    RATE_LIMIT[ip] = now
    return True

# ── HTTP Handler ──
class APIHandler(http.server.BaseHTTPRequestHandler):

    def _send_json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length)) if length > 0 else {}

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        if path == "/api/leaderboard":
            rows = db_query("SELECT name, score FROM scores ORDER BY score DESC LIMIT 5")
            self._send_json({"leaderboard": rows})

        elif path == "/api/leaderboard/check":
            score = int(params.get("score", [0])[0])
            count = db_query("SELECT COUNT(*) as c FROM scores")[0]["c"]
            if count < 5:
                self._send_json({"will_rank": True})
                return
            lowest = db_query(
                "SELECT MIN(score) as m FROM (SELECT score FROM scores ORDER BY score DESC LIMIT 5)"
            )[0]["m"]
            self._send_json({"will_rank": score > lowest, "cutoff": lowest})

        else:
            self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        if self.path == "/api/leaderboard":
            body = self._read_body()
            name = (body.get("name") or "无名").strip()[:8] or "无名"
            score = int(body.get("score", 0))
            token = body.get("token", "")

            # 1. Token 校验
            if token != make_token(name, score):
                return self._send_json({"error": "Bad token"}, 403)

            # 2. 分数合理性
            if score < 0 or score > 999999:
                return self._send_json({"error": "Bad score"}, 400)

            # 3. 速率限制
            ip = self.client_address[0]
            if not check_rate(ip):
                return self._send_json({"error": "Too fast, wait 30s"}, 429)

            # 4. 写入 & 清理
            db_execute("INSERT INTO scores (name, score) VALUES (?, ?)", [name, score])
            db_execute("""
                DELETE FROM scores WHERE id NOT IN (
                    SELECT id FROM scores ORDER BY score DESC LIMIT 5
                )
            """)
            self._send_json({"status": "ok", "name": name})
        else:
            self._send_json({"error": "Not found"}, 404)

    def log_message(self, format, *args):
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {self.client_address[0]} {args[0]}")

if __name__ == "__main__":
    init_db()
    print(f"Leaderboard API running on :{PORT}")
    server = http.server.HTTPServer(("0.0.0.0", PORT), APIHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.server_close()
