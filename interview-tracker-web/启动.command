#!/bin/bash
# 面试管理工具 — Mac 双击启动脚本
# 双击这个文件即可启动，无需打开终端

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# 检查 Python3
if ! command -v python3 &>/dev/null; then
    osascript -e 'display dialog "未找到 Python3。请先安装 Python：https://www.python.org/downloads/" buttons {"OK"} default button "OK" with icon stop'
    exit 1
fi

# 检查并创建虚拟环境
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -q -r requirements.txt
else
    source .venv/bin/activate
fi

# 清理旧数据库（如需保留数据，删除下面这行）
# rm -f data/interview_tracker.db

# 启动服务器（后台运行）
python3 run.py &
SERVER_PID=$!

# 等 2 秒让服务器起来，然后打开浏览器
sleep 2
open "http://127.0.0.1:8000"

# 浏览器关闭后，按任意键停止服务器
echo ""
echo "面试管理工具正在运行中..."
echo "浏览器已打开 http://127.0.0.1:8000"
echo "关闭此窗口即可停止服务。"
read -p ""

kill $SERVER_PID 2>/dev/null
