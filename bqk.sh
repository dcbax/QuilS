#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 安装7z（如果没有安装）
if ! command -v 7z &> /dev/null; then
    echo -e "${YELLOW}7z 未安装，正在安装...${NC}"
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y p7zip-full
        echo -e "${GREEN}7z 安装成功${NC}"
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install epel-release -y
        sudo yum install -y p7zip
        echo -e "${GREEN}7z 安装成功${NC}"
    else
        echo -e "${RED}不支持的操作系统${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}7z 已安装${NC}"
fi

# 检查并创建备份目录（如果不存在）
BACKUP_DIR="/root/bak"
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${YELLOW}创建备份目录 $BACKUP_DIR...${NC}"
    mkdir -p "$BACKUP_DIR"
    echo -e "${GREEN}备份目录创建成功${NC}"
else
    echo -e "${GREEN}备份目录已存在${NC}"
fi

# 获取当前日期和时间
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 获取本机IP地址的最后一段数字
IP_ADDRESS=$(hostname -I | awk '{print $1}')
LAST_IP_SEGMENT=$(echo $IP_ADDRESS | awk -F. '{print $4}')

# 检查并删除旧的备份文件（如果存在）
BACKUP_FILE="$BACKUP_DIR/config_backup_*.7z"
if ls $BACKUP_FILE 1> /dev/null 2>&1; then
    echo -e "${YELLOW}删除旧的备份文件...${NC}"
    rm $BACKUP_FILE
    echo -e "${GREEN}旧的备份文件已删除${NC}"
fi

# 压缩文件并包含日期和IP地址的最后一段，显示进度条
SOURCE_DIR="/root/ceremonyclient/node/.config"
DEST_FILE="$BACKUP_DIR/config_backup_${TIMESTAMP}_${LAST_IP_SEGMENT}.7z"
echo -e "${YELLOW}正在压缩文件 $SOURCE_DIR...${NC}"
7z a $DEST_FILE $SOURCE_DIR | while IFS= read -r line; do
    echo -ne "${YELLOW}${line}\r${NC}"
done
echo -e "${GREEN}文件压缩完成${NC}"

# 自定义 Python HTTP 服务器脚本
cat << 'EOF' > /root/custom_http_server.py
import os
import http.server
import socketserver
import time

LOG_FILE = "/root/log.txt"

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        with open(LOG_FILE, "a") as log:
            log.write("%s - - [%s] %s\n" % (self.client_address[0],
                                            self.log_date_time_string(),
                                            format % args))
    def do_GET(self):
        start_time = time.time()
        self.log_message("Started download of %s", self.path)
        super().do_GET()
        duration = time.time() - start_time
        size = os.path.getsize(self.translate_path(self.path))
        speed = size / duration / 1024  # KB/s
        self.log_message("Finished download of %s in %.2f seconds at %.2f KB/s",
                         self.path, duration, speed)
        print(f"{self.client_address[0]} downloaded {self.path} at {speed:.2f} KB/s")

PORT = 8000

with socketserver.TCPServer(("", PORT), CustomHTTPRequestHandler) as httpd:
    print(f"Serving HTTP on 0.0.0.0 port {PORT} (http://0.0.0.0:{PORT}/)")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
EOF

# 启动 HTTP 服务器进行文件下载
echo -e "${YELLOW}启动 HTTP 服务器...${NC}"
cd $BACKUP_DIR
python3 /root/custom_http_server.py &

# 提示下载地址
echo -e "${GREEN}文件可通过以下地址下载：${NC}"
echo -e "${YELLOW}http://${IP_ADDRESS}:8000/config_backup_${TIMESTAMP}_${LAST_IP_SEGMENT}.7z${NC}"
echo -e "${YELLOW}下载完成后，请按 Ctrl+C 停止 HTTP 服务器${NC}"

# 保持脚本运行
wait
