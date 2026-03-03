#!/bin/bash
# Tạo associative array để lưu mapping service -> image:tag
declare -A SERVICE_IMAGES

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

IMAGE_DIR="./images"
COMPOSE_TEMPLATE="template/docker-compose.template.sh"
ENV_TEMPLATE="template/.env.template.sh"
HOSTS_FILE="/etc/hosts"

# Hàm log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

update_hosts() {
    local domain=$1
    local ip=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local script_name="Soar Installation Script"
    local comment="# Managed by $script_name - Updated: $timestamp"
    
    log_info "Chuẩn bị thêm: $ip $domain vào $HOSTS_FILE"
    
    # Kiểm tra xem cặp IP-domain chính xác đã tồn tại chưa
    if grep -qE "^${ip}\s+${domain}(\s|$)" "$HOSTS_FILE"; then
        log_info "Bản ghi $ip $domain đã tồn tại chính xác trong $HOSTS_FILE"
        return 0
    fi
    
    # Kiểm tra xem domain đã tồn tại với IP khác chưa
    if grep -qE "^\s*[^#].*\s${domain}(\s|$)" "$HOSTS_FILE"; then
        log_info "Domain $domain đã tồn tại với IP khác, đang comment dòng cũ..."
        
        # Comment dòng cũ bằng cách thêm # ở đầu dòng (tạo backup)
        sudo sed -i.bak "/^\s*[^#].*\s${domain}\(\s\|$\)/s/^/# [REPLACED $(date '+%Y-%m-%d')] /" "$HOSTS_FILE"
        
        # Thêm bản ghi mới với comment
        {
            echo ""
            echo "$comment"
            echo "$ip $domain"
        } | sudo tee -a "$HOSTS_FILE" > /dev/null
        
        log_info "✓ Đã comment bản ghi cũ và thêm mới: $ip $domain"
    else
        # Domain chưa tồn tại, thêm mới với comment
        {
            echo ""
            echo "$comment"
            echo "$ip $domain"
        } | sudo tee -a "$HOSTS_FILE" > /dev/null
        
        log_info "✓ Đã thêm mới: $ip $domain vào $HOSTS_FILE"
    fi
}

# Hàm tạo password mạnh
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

load_images() {
    for tar_file in "$IMAGE_DIR"/*.tar; do
        if [ ! -f "$tar_file" ]; then
            log_warn "Không tìm thấy file .tar nào trong $IMAGE_DIR"
            continue
        fi
        
        filename=$(basename "$tar_file")
        log_info "Đang load image từ $filename..."
        
        # Load image và capture output
        output=$(docker load -i "$tar_file" 2>&1)
        
        if [ $? -eq 0 ]; then
            # Extract image name và tag từ output
            image_full=$(echo "$output" | grep -oP 'Loaded image: \K.*' || echo "")
            
            if [ -n "$image_full" ]; then
                log_info "✓ Loaded: $image_full"
                
                # Lấy tên image (không có tag)
                image_name=$(basename "$image_full" | cut -d':' -f1)
                
                # Map image với service tương ứng
                case "$image_name" in
                    postgres)
                        SERVICE_IMAGES[postgres]="$image_full"
                        ;;
                    redis)
                        SERVICE_IMAGES[redis]="$image_full"
                        ;;
                    arcsight-integration)
                        SERVICE_IMAGES[arcsight-integration]="$image_full"
                        ;;
                    threatconnect-worker)
                        SERVICE_IMAGES[threatconnect-worker]="$image_full"
                        ;;
                    *)
                        log_warn "Image $image_name không match với service nào"
                        ;;
                esac
            else
                log_error "Không thể extract image name từ: $output"
            fi
        else
            log_error "Lỗi khi load $filename: $output"
        fi
    done

    # Hiển thị mapping
    log_info "\n=== Image Mapping ==="
    for service in "${!SERVICE_IMAGES[@]}"; do
        echo "  $service -> ${SERVICE_IMAGES[$service]}"
    done
}

load_images_from_list() {
    local image_list_file="image-list.txt"
    
    if [ ! -f "$image_list_file" ]; then
        log_error "File $image_list_file không tồn tại!"
        return 1
    fi
    
    log_info "Đang đọc danh sách images từ $image_list_file..."
    
    while IFS=': ' read -r service_key image_full || [ -n "$service_key" ]; do
        # Bỏ qua dòng trống và comment
        [[ -z "$service_key" || "$service_key" =~ ^#.*$ ]] && continue
        
        # Trim whitespace
        service_key=$(echo "$service_key" | xargs)
        image_full=$(echo "$image_full" | xargs)
        
        # Map service key từ image-list.txt sang SERVICE_IMAGES
        case "$service_key" in
            postgres)
                SERVICE_IMAGES[postgres]="$image_full"
                log_info "✓ Mapped: postgres -> $image_full"
                ;;
            redis)
                SERVICE_IMAGES[redis]="$image_full"
                log_info "✓ Mapped: redis -> $image_full"
                ;;
            qradar-integration)
                SERVICE_IMAGES[qradar-integration]="$image_full"
                log_info "✓ Mapped: qradar-integration -> $image_full"
                ;;
            pt-integration)
                SERVICE_IMAGES[pt-integration]="$image_full"
                log_info "✓ Mapped: pt-integration -> $image_full"
                ;;
            ncssoar-worker)
                SERVICE_IMAGES[ncssoar-worker]="$image_full"
                log_info "✓ Mapped: ncssoar-worker -> $image_full"
                ;;
            *)
                log_warn "Service key '$service_key' không được nhận dạng"
                ;;
        esac
    done < "$image_list_file"
    
    log_info "✓ Đã đọc xong danh sách images từ $image_list_file"
}

validate_images() {
    local missing_images=0
    local required_services=("postgres" "redis" "arcsight-integration" "threatconnect-worker")
    
    for service in "${required_services[@]}"; do
        if [ -z "${SERVICE_IMAGES[$service]}" ]; then
            log_error "x Image cho service '$service' chưa được load."
            missing_images=$((missing_images + 1))
        else
            log_info "✓ Image cho service '$service' đã được load: ${SERVICE_IMAGES[$service]}"
        fi
    done
    
    if [ $missing_images -gt 0 ]; then
        log_error "Tổng cộng có $missing_images image bị thiếu. Vui lòng kiểm tra lại."
        exit 1
    else
        log_info "✓ Tất cả images cần thiết đã được load."
    fi
}

function configure_awscli() {
    if ! command -v aws &> /dev/null; then
        log_warn "awscli chưa được cài đặt!"
        log_info "Cài đặt awscli...cần sudo để chạy"
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        python3 -m zipfile -e awscliv2.zip .
        sudo chmod -R +x ./aws/
        sudo ./aws/install
        rm -rf ./aws ./awscliv2.zip
    fi
    log_info "awscli version: $(aws --version)"
    log_info "Cấu hình aws cli..."
    read -p "Nhập AWS_ACCESS_KEY_ID (Liên hệ thanh.nguyen3): " AWS_ACCESS_KEY_ID
    while [[ -z "$AWS_ACCESS_KEY_ID" ]]; do
        echo -e "${RED}AWS_ACCESS_KEY_ID không được để trống${NC}"
        read -p "Nhập AWS_ACCESS_KEY_ID (Liên hệ thanh.nguyen3): " AWS_ACCESS_KEY_ID
    done

    read -p "Nhập AWS_SECRET_ACCESS_KEY (Liên hệ thanh.nguyen3): " AWS_SECRET_ACCESS_KEY
    while [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; do
        echo -e "${RED}AWS_SECRET_ACCESS_KEY không được để trống${NC}"
        read -p "Nhập AWS_SECRET_ACCESS_KEY (Liên hệ thanh.nguyen3): " AWS_SECRET_ACCESS_KEY
    done

    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    aws configure set default.region "ap-southeast-1"
    aws ecr get-login-password --region ap-southeast-1 | \
    docker login --username AWS --password-stdin \
    407869965289.dkr.ecr.ap-southeast-1.amazonaws.com
    log_info "AWS CLI đã được cấu hình với region ap-southeast-1"
    log_info "Sẵn sàng pull images từ AWS ECR"
}