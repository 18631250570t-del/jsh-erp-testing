# -*- coding: utf-8 -*-
"""测试辅助服务：把 jshERP 存在 Redis 里的图形验证码暴露成一个 HTTP 接口

用途：Postman / Newman 无法直接读 Redis，通过这个本地服务即可全自动登录。

启动：python captcha_helper.py
接口：GET http://127.0.0.1:8899/captcha?uuid=xxx  ->  {"code":"ab12","uuid":"xxx"}
      GET http://127.0.0.1:8899/ping               ->  {"status":"ok"}
"""
import json
import subprocess
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REDIS_CLI = r"D:\deepseek test' work\env\redis\redis-cli.exe"
REDIS_HOST, REDIS_PORT, REDIS_PWD = "127.0.0.1", "6380", "1234abcd"
PORT = 8899


def redis_get(key):
    out = subprocess.run(
        [REDIS_CLI, "-h", REDIS_HOST, "-p", REDIS_PORT, "-a", REDIS_PWD,
         "--no-auth-warning", "GET", key],
        capture_output=True, text=True, timeout=10)
    return (out.stdout or "").strip()


class Handler(BaseHTTPRequestHandler):
    def _json(self, obj, status=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/ping":
            return self._json({"status": "ok"})

        if parsed.path == "/captcha":
            uuid = (qs.get("uuid") or [""])[0]
            if not uuid:
                return self._json({"error": "missing uuid"}, 400)
            code = redis_get("captcha_codes:" + uuid)
            if not code:
                return self._json({"error": "captcha not found or expired", "uuid": uuid}, 404)
            return self._json({"code": code, "uuid": uuid})

        return self._json({"error": "not found"}, 404)

    def log_message(self, fmt, *args):
        print(f"[helper] {self.address_string()} {fmt % args}", flush=True)


if __name__ == "__main__":
    print(f"captcha helper 启动: http://127.0.0.1:{PORT}", flush=True)
    print("  GET /ping", flush=True)
    print("  GET /captcha?uuid=<uuid>", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
