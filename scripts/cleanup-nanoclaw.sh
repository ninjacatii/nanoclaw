#!/bin/bash
# NanoClaw 进程清理脚本
# 用于清理所有 nanoclaw 相关进程和释放端口

# 不因为错误而退出，继续执行清理

echo "=== NanoClaw 进程清理脚本 ==="

# 1. 停止 systemd 服务（如果存在）
echo "[1/5] 停止 systemd 服务..."
if systemctl --user status nanoclaw &>/dev/null; then
    systemctl --user stop nanoclaw 2>/dev/null || true
    echo "  ✓ systemd 服务已停止"
else
    echo "  - 未找到 systemd 服务"
fi

# 2. 停止 launchd 服务（macOS，如果存在）
echo "[2/5] 停止 launchd 服务..."
if launchctl list | grep -q com.nanoclaw 2>/dev/null; then
    launchctl unload ~/Library/LaunchAgents/com.nanoclaw.plist 2>/dev/null || true
    echo "  ✓ launchd 服务已停止"
else
    echo "  - 未找到 launchd 服务"
fi

# 3. 杀死所有 nanoclaw 相关进程
echo "[3/5] 杀死 nanoclaw 相关进程..."
PIDS=$(ps aux | grep -E "nanoclaw|dist/index.js|tsx src/index" | grep -v grep | awk '{print $2}' || true)
if [ -n "$PIDS" ]; then
    kill -9 $PIDS 2>/dev/null || true
    echo "  ✓ 已杀死进程：$PIDS"
else
    echo "  - 未找到 nanoclaw 进程"
fi

# 4. 释放端口 3001（credential proxy）
echo "[4/5] 释放端口 3001..."
PORT_PID=$(lsof -ti:3001 2>/dev/null || true)
if [ -n "$PORT_PID" ]; then
    kill -9 $PORT_PID 2>/dev/null || true
    echo "  ✓ 已释放端口 3001 (PID: $PORT_PID)"
else
    echo "  - 端口 3001 未被占用"
fi

# 5. 清理 Docker 容器（可选）
echo "[5/5] 清理 orphaned Docker 容器..."
if command -v docker &>/dev/null; then
    docker ps -a --filter "name=nanoclaw" --format "{{.Names}}" 2>/dev/null | while read -r container; do
        docker rm -f "$container" 2>/dev/null || true
        echo "  ✓ 已清理容器：$container"
    done
    ORPHANS=$(docker ps -a --filter "name=nanoclaw" -q 2>/dev/null | wc -l)
    if [ "$ORPHANS" -eq 0 ]; then
        echo "  - 无 orphaned 容器"
    fi
else
    echo "  - Docker 未安装"
fi

echo ""
echo "=== 清理完成 ==="
echo ""
echo "验证状态:"
echo "  进程检查：$(ps aux | grep -E "nanoclaw|dist/index.js" | grep -v grep | wc -l) 个进程"
echo "  端口 3001: $(ss -tlnp 2>/dev/null | grep :3001 | wc -l) 个占用"
echo "  Docker: $(docker ps --filter "name=nanoclaw" -q 2>/dev/null | wc -l) 个运行中"
