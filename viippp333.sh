#!/bin/bash

# ==============================================================================
# CẤU HÌNH (Đã cập nhật link của bạn)
# ==============================================================================
GOOGLE_SCRIPT_URL="https://script.google.com/macros/s/AKfycbwP8_m9efIoQiVjKkuDNng4LNdpW4nvNmHs36tPwvRpjNwv74p41ywU1LOgMgVN0aVw/exec"

# Các thông số cố định
PANEL_USER="honglee"
PANEL_PASS="Abc369852@spo@VIP2024@VPN"
PANEL_PORT=3712

# ==============================================================================
# HÀM LOGGING (Để hiện thông báo màu sắc dễ nhìn)
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
log_info "Đang kiểm tra các gói cần thiết..."
command -v curl >/dev/null 2>&1 || { apt-get update && apt-get install -y curl; }

log_info "Đang thay đổi mật khẩu Root..."
NEW_ROOT_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 25)
echo "root:$NEW_ROOT_PASS" | chpasswd

log_info "Đang chạy script Setup SSH..."
bash <(curl -fsSL https://raw.githubusercontent.com/Betty-Matthews/-setup_ssh/refs/heads/main/setup_ssh_ubuntu.sh) || log_warn "Setup SSH có cảnh báo (có thể bỏ qua)."

# ==============================================================================
# 3. CÀI ĐẶT 3X-UI (CÓ KIỂM TRA ĐỂ TRÁNH LỖI KHI CHẠY LẠI)
# ==============================================================================
XUI_BIN="/usr/local/x-ui/x-ui"

if [ -f "$XUI_BIN" ]; then
    # Nếu đã cài rồi -> Chỉ dừng service để cấu hình lại
    log_warn "Phát hiện 3x-ui đã tồn tại. Bỏ qua cài đặt, tiến hành cấu hình lại..."
    $XUI_BIN stop > /dev/null 2>&1
else
    # Nếu chưa cài -> Cài mới
    log_info "Đang cài đặt 3x-ui..."
    echo -e "n\n" | bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
fi

# ==============================================================================
# 4. CẤU HÌNH USER/PASS/PORT/PATH
# ==============================================================================
log_info "Đang áp dụng cấu hình (User: $PANEL_USER / Port: $PANEL_PORT)..."

# Tạo WebBasePath ngẫu nhiên (16 ký tự)
RANDOM_PATH=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

if [ -f "$XUI_BIN" ]; then
    # Lệnh setting đè cấu hình cũ
    $XUI_BIN setting -username "$PANEL_USER" -password "$PANEL_PASS" -port "$PANEL_PORT" -webbasepath "/$RANDOM_PATH"
    
    # Khởi động lại
    $XUI_BIN restart > /dev/null 2>&1
    log_info "Đã khởi động 3x-ui với cấu hình mới."
else
    log_error "Lỗi: Không tìm thấy file chạy 3x-ui!"
    exit 1
fi

# ==============================================================================
# 5. ĐỒNG BỘ DỮ LIỆU LÊN GOOGLE SHEET
# ==============================================================================
log_info "Đang thu thập thông tin..."
HOST_IP=$(curl -s ifconfig.me)
HOSTNAME=$(hostname)
ACCESS_URL="http://${HOST_IP}:${PANEL_PORT}/${RANDOM_PATH}"

# Tạo gói tin JSON
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

log_info "Đang gửi dữ liệu lên Google Sheet..."
# Gửi Request
SYNC_RES=$(curl -s -L -X POST -H "Content-Type: application/json" -d "$JSON_DATA" "$GOOGLE_SCRIPT_URL")

# Kiểm tra kết quả
if [[ "$SYNC_RES" == *"success"* ]]; then
    log_info "Đồng bộ THÀNH CÔNG!"
else
    log_error "Đồng bộ THẤT BẠI. Phản hồi server: $SYNC_RES"
fi

# ==============================================================================
# 6. HIỂN THỊ THÔNG TIN & TỰ HỦY
# ==============================================================================
echo "------------------------------------------------"
echo "Username:    $PANEL_USER"
echo "Password:    $PANEL_PASS"
echo "Port:        $PANEL_PORT"
echo "WebBasePath: $RANDOM_PATH"
echo "Access URL:  $ACCESS_URL"
echo "Root Pass
