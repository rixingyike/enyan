#!/usr/bin/env python3
"""
资源包下载服务器 - 开发者临时测试用
直接运行: python scripts/pack_server.py
按 Ctrl+C 停止
"""

import http.server
import socketserver
import os
import json
import signal
import sys

PORT = 8080
PACKS_DIR = os.path.join(os.path.dirname(__file__), 'packs')

if not os.path.exists(PACKS_DIR):
    os.makedirs(PACKS_DIR)

def get_host_ip():
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return '127.0.0.1'

class PackHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PACKS_DIR, **kwargs)
    
    def do_GET(self):
        # Support both old and new paths for compatibility
        if self.path == '/api/packs' or self.path == '/api/packs.json':
            # Use packs.json as the source of truth
            mock_file = os.path.join(os.path.dirname(__file__), 'api', 'packs.json')
            if os.path.exists(mock_file):
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                # Read as text to ensure correct content length/encoding if needed, 
                # but binary read is fine for simple serving
                with open(mock_file, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_error(404, f"Mock packs file not found: {mock_file}")
            return
        
        # 其他请求作为静态文件处理
        super().do_GET()
    
    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {args[0]}")

def signal_handler(sig, frame):
    print("\n👋 服务器已停止")
    sys.exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    
    host_ip = get_host_ip()
    print(f"🚀 资源包服务器启动")
    print(f"📂 包目录: {PACKS_DIR}")
    print(f"🌐 本地访问: http://localhost:{PORT}/api/packs")
    print(f"🌐 局域网访问: http://{host_ip}:{PORT}/api/packs")
    print(f"按 Ctrl+C 停止服务器\n")
    
    with socketserver.TCPServer(("", PORT), PackHandler) as httpd:
        httpd.serve_forever()
