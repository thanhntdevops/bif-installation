#!/bin/bash

set -e

IMAGE_DIR="./images"
IMAGE_LIST_FILE="image-list.txt"
IMAGE_MAP_FILE="image-map.conf"

source ./script/function.sh

# Banner
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║           Docker Image Pull & Save Script                ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Kiểm tra Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker chưa được cài đặt!"
    exit 1
fi

log_info "Docker version: $(docker --version)"

# Cấu hình awscli 
configure_awscli

# Tạo thư mục images nếu chưa có
if [ ! -d "$IMAGE_DIR" ]; then
    mkdir -p "$IMAGE_DIR"
    log_info "Đã tạo thư mục $IMAGE_DIR"
fi

# Kiểm tra file image-list.txt
if [ ! -f "$IMAGE_LIST_FILE" ]; then
    log_error "File $IMAGE_LIST_FILE không tồn tại!"
    echo ""
    log_info "Tạo file mẫu $IMAGE_LIST_FILE..."
    
    cat > "$IMAGE_LIST_FILE" <<EOF
# Docker Image List
# Format: service_name: image:tag@sha256:digest
# OR:     service_name: image:tag
# Lines starting with # are comments

postgres: postgres:16
redis: redis:7
nginx-ssl-proxy: nginx:alpine

# Examples with digest
# postgres: registry.example.com/postgres:16@sha256:abc123...
# redis: registry.example.com/redis:7@sha256:def456...

# Private registry examples
# backend: registry.company.com/backend:latest
# frontend: registry.company.com/frontend:v1.0.0@sha256:789ghi...
EOF
    
    log_info "Đã tạo file mẫu $IMAGE_LIST_FILE"
    log_info "Vui lòng chỉnh sửa file này và chạy lại script"
    exit 0
fi

# Đọc và parse image list
declare -A SERVICE_TO_IMAGE
declare -a IMAGES_TO_PULL

log_info "Đọc danh sách images từ $IMAGE_LIST_FILE..."
echo ""

line_number=0
while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))
    
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*#.*$ ]] && continue
    [[ -z "$(echo "$line" | xargs)" ]] && continue
    
    # Parse format: service_name: image:tag@sha256:digest
    if [[ "$line" =~ ^([^:]+):[[:space:]]*(.+)$ ]]; then
        service="${BASH_REMATCH[1]}"
        full_image="${BASH_REMATCH[2]}"
        
        # Trim whitespace
        service=$(echo "$service" | xargs)
        full_image=$(echo "$full_image" | xargs)
        
        if [ -z "$service" ] || [ -z "$full_image" ]; then
            log_warn "Line $line_number: Invalid format, skipping..."
            continue
        fi
        
        SERVICE_TO_IMAGE[$service]="$full_image"
        IMAGES_TO_PULL+=("$full_image")
        
        echo "  ✓ $service -> $full_image"
    else
        log_warn "Line $line_number: Invalid format, skipping..."
    fi
done < "$IMAGE_LIST_FILE"

if [ ${#IMAGES_TO_PULL[@]} -eq 0 ]; then
    log_error "Không tìm thấy image nào trong $IMAGE_LIST_FILE"
    exit 1
fi

echo ""
log_info "Tổng số images cần pull: ${#IMAGES_TO_PULL[@]}"

# Hỏi xác nhận
read -p "Bạn có muốn tiếp tục pull images? (Y/n): " confirm
confirm="${confirm:-Y}"

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Đã hủy"
    exit 0
fi

echo ""
log_step "Bắt đầu pull images..."
echo ""

# Pull từng image
pulled_count=0
failed_count=0
declare -a FAILED_IMAGES

for image in "${IMAGES_TO_PULL[@]}"; do
    log_info "Pulling $image..."
    
    if docker pull "$image" 2>&1; then
        log_info "✓ Pulled: $image"
        pulled_count=$((pulled_count + 1))
    else
        log_error "✗ Failed: $image"
        FAILED_IMAGES+=("$image")
        failed_count=$((failed_count + 1))
    fi
    echo ""
done

# Hiển thị kết quả pull
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Pull Summary                             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  ✓ Successfully pulled: $pulled_count"
echo "  ✗ Failed: $failed_count"

if [ $failed_count -gt 0 ]; then
    echo ""
    log_error "Failed images:"
    for img in "${FAILED_IMAGES[@]}"; do
        echo "    - $img"
    done
fi

if [ $pulled_count -eq 0 ]; then
    log_error "Không có image nào được pull thành công!"
    exit 1
fi

# Hỏi có muốn save images không
echo ""
read -p "Bạn có muốn save images thành file .tar? (Y/n): " save_confirm
save_confirm="${save_confirm:-Y}"

if [[ ! "$save_confirm" =~ ^[Yy]$ ]]; then
    log_info "Bỏ qua việc save images"
    exit 0
fi

echo ""
log_step "Saving images to $IMAGE_DIR..."
echo ""

# Save từng image
saved_count=0
for image in "${IMAGES_TO_PULL[@]}"; do
    # Loại bỏ phần digest nếu có
    image_without_digest=${image%%@*}
    docker tag "$image" "$image_without_digest"
    # Skip nếu image failed to pull
    skip=false
    for failed in "${FAILED_IMAGES[@]}"; do
        if [ "$image" = "$failed" ]; then
            skip=true
            break
        fi
    done
    
    if [ "$skip" = true ]; then
        continue
    fi
    
    # Tạo tên file an toàn (thay / và : bằng -)
    filename=$(echo "$image_without_digest" | sed 's/[\/:]/-/g')
    filepath="${IMAGE_DIR}/${filename}.tar"

    log_info "Saving $image_without_digest to ${filename}.tar..."

    if docker save -o "$filepath" "$image_without_digest" 2>&1; then
        log_info "✓ Saved: ${filename}.tar"
        saved_count=$((saved_count + 1))
    else
        log_error "✗ Failed to save: $image"
        rm -f "$filepath"
    fi
    echo ""
done

# Tạo image mapping config file
#log_step "Generating image mapping config..."
#
#cat > "$IMAGE_MAP_FILE" <<EOF
## Image Mapping Configuration
## Auto-generated by pull-and-save-images.sh
## Format: SERVICE_NAME=IMAGE:TAG
#
#EOF
#
#for service in "${!SERVICE_TO_IMAGE[@]}"; do
#    echo "${service}=${SERVICE_TO_IMAGE[$service]}" >> "$IMAGE_MAP_FILE"
#done
#
#log_info "✓ Created $IMAGE_MAP_FILE"

# Hiển thị kết quả cuối cùng
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Final Summary                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  📥 Images pulled: $pulled_count"
echo "  💾 Images saved: $saved_count"
echo "  📁 Saved to: $IMAGE_DIR/"
#echo "  🗺️  Mapping file: $IMAGE_MAP_FILE"
echo ""

# List saved files
if [ $saved_count -gt 0 ]; then
    log_info "Saved files:"
    ls -lh "$IMAGE_DIR"/*.tar 2>/dev/null | awk '{print "     " $9 " (" $5 ")"}'
fi

echo ""
log_info "✅ Hoàn thành pull image và save image!"

echo ""
echo "========================================="
echo "Creating deployment bundle..."
echo "========================================="

BUNDLE_NAME="bif-deployment-$(date +%Y%m%d-%H%M%S).tar.gz"

tar -czf "../${BUNDLE_NAME}" \
    --exclude='.git' \
    --exclude='*.log' \
    -C .. "$(basename $(pwd))"

echo "✓ Bundle: ../${BUNDLE_NAME} ($(du -h ../${BUNDLE_NAME} | cut -f1))"
echo ""
echo "Next steps:"
echo "Copy ${BUNDLE_NAME} đến server cần triển khai BIF và chạy ./install.sh:"
echo "  1. scp ../${BUNDLE_NAME} user@server:/opt/"
echo "  2. ssh user@server"
echo "  3. cd /opt && tar -xzf ${BUNDLE_NAME}"
echo "  4. cd $(basename $(pwd)) && ./install.sh"

echo ""
log_info "✅ Hoàn thành công tác chuẩn bị!"
log_info "✅ Copy ${BUNDLE_NAME} đến server cần triển khai BIF và chạy ./install.sh"