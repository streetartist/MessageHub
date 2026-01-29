@echo off
chcp 65001 >nul
echo ========================================
echo   QQ 聊天 AI 助手 - 启动中...
echo ========================================
echo.

cd /d "%~dp0"

REM 检查虚拟环境
if not exist "venv" (
    echo [1/3] 创建虚拟环境...
    python -m venv venv
)

REM 激活虚拟环境
echo [2/3] 激活虚拟环境...
call venv\Scripts\activate.bat

REM 安装依赖
echo [3/3] 检查依赖...
pip install -r requirements.txt -q

echo.
echo ========================================
echo   启动 Web 服务器...
echo   访问地址: http://localhost:5000
echo ========================================
echo.

python app.py

pause
