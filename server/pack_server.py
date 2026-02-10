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
        if self.path == '/api/packs':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            # host_ip = get_host_ip()
            host_ip = '127.0.0.1' # 强制使用 127.0.0.1 以适应本地环境
            base_url = f"http://{host_ip}:{PORT}"
            
            # 计算实际文件大小
            def get_size(filename):
                path = os.path.join(PACKS_DIR, filename)
                if os.path.exists(path):
                    size = os.path.getsize(path) / 1024 / 1024
                    return f"{size:.1f}MB"
                return "N/A"
            
            packs = {
                "packs": [
                    {
                        "id": "lang_cht", 
                        "name": "繁体中文语言包", 
                        "size": get_size("lang_cht.zip"), 
                        "type": "language",
                        "url": f"{base_url}/lang_cht.zip"
                    },
                    {
                        "id": "voice_6k", 
                        "name": "6K语音包 (极致压缩)", 
                        "size": get_size("voice_6k.zip"), 
                        "type": "voice",
                        "url": f"{base_url}/voice_6k.zip"
                    },
                    {
                        "id": "voice_8k", 
                        "name": "8K语音包 (高清)", 
                        "size": get_size("voice_8k.zip"), 
                        "type": "voice",
                        "url": f"{base_url}/voice_8k.zip"
                    },
                    {
                        "id": "piper-zh_CN-huayan-medium", 
                        "name": "Piper语音模型 (Huayan)", 
                        "size": get_size("piper_model.zip"), 
                        "type": "model",
                        "url": f"{base_url}/piper_model.zip"
                    }
                ]
            }
            self.wfile.write(json.dumps(packs, ensure_ascii=False).encode('utf-8'))
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
