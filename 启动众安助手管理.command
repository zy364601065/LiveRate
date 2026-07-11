#!/bin/zsh

set -e

ADMIN_DIR="/Users/zengyuan/Desktop/LiveRate/admin"
WEB_URL="http://127.0.0.1:5173"

cd "$ADMIN_DIR"

echo "正在启动众安助手管理..."
echo "后台目录: $ADMIN_DIR"
echo "网页地址: $WEB_URL"
echo

if [ ! -d "node_modules" ]; then
  echo "首次启动需要安装依赖，正在执行 npm install..."
  npm install
fi

sleep 1
open "$WEB_URL"

npm run dev
