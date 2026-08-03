#!/usr/bin/env bash
set -euo pipefail

# يعمل على هذا المسار أياً كان مكان النسخ (repo نفسه)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$REPO_DIR/build"
BRANCH="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo main)"
LOG="/tmp/gnome-pomodoro.log"

cd "$REPO_DIR"

echo "==> 1/4 جلب آخر التعديلات من GitHub"
git pull --ff-only origin "$BRANCH"

echo "==> 2/4 إعداد البناء"
if [ ! -d "$BUILD_DIR" ]; then
    meson setup "$BUILD_DIR" --prefix=/usr
else
    meson setup --reconfigure "$BUILD_DIR" --prefix=/usr >/dev/null
fi

echo "==> 3/4 بناء النسخة الجديدة"
ninja -C "$BUILD_DIR"

echo "==> 4/4 تثبيت في /usr (هتظهر نافذة مصادقة)"
pkexec bash -c "cd '$BUILD_DIR' && ninja install"

echo "==> إعادة تشغيل الديمون بالنسخة الجديدة"
pkill -x gnome-pomodoro 2>/dev/null || true
sleep 1
DISPLAY=:0 GDK_BACKEND=x11 nohup /usr/bin/gnome-pomodoro --no-default-window >"$LOG" 2>&1 &
sleep 2

echo "تم ✓ — النسخة الحالية:"
/usr/bin/gnome-pomodoro --version 2>/dev/null || echo "الديمون شغال"
