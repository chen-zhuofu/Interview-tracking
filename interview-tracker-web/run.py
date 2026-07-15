#!/usr/bin/env python3
"""启动脚本：初始化数据库 → 启动 uvicorn → 自动打开浏览器到看板页。"""
import webbrowser
import threading
import time

import uvicorn

from app.database import Base, engine


def init_database():
    """创建所有表（幂等操作）。"""
    Base.metadata.create_all(bind=engine)


def open_browser():
    """延迟 1.5 秒后自动打开浏览器，给 uvicorn 时间完成启动。"""
    time.sleep(1.5)
    webbrowser.open("http://127.0.0.1:8000")


if __name__ == "__main__":
    init_database()

    # 在后台线程打开浏览器 (uvicorn 启动后)
    threading.Thread(target=open_browser, daemon=True).start()

    uvicorn.run(
        "app.main:app",
        host="127.0.0.1",
        port=8000,
        reload=False,
    )
