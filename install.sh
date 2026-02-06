#!/bin/bash

set -e

# load functions
source script/function.sh

IMAGE_DIR="./images"
COMPOSE_TEMPLATE="template/docker-compose.template.sh"
ENV_TEMPLATE="template/env.qradar.template.sh"
HOSTS_FILE="/etc/hosts"
DB_NAME=bif
DB_USER=bif
REDIS_USER=bif

# Tạo passwords
log_info "✓Đang tạo passwords mạnh"
ADMIN_PASSWORD=$(generate_password)
DB_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)

# Prompt cho domain

read -p "Nhập TENANT (Trùng với mã khách hàng viết thường trên SOAR ví dụ: evn): " TENANT
if [ -z "$TENANT" ]; then
    log_error "TENANT không được để trống!"
    exit 1
fi
read -p "Nhập SIEM SOLUTION (1: QRadar, 2: PT): " SIEM_SOLUTION
if [ -z "$SIEM_SOLUTION" ]; then
    log_error "SIEM SOLUTION không được để trống!"
    exit 1
fi

if [[ "$SIEM_SOLUTION" == "1" ]]; then
    SIEM_SOLUTION_NAME="QRadar"
    COMPOSE_TEMPLATE="template/qradar-docker-compose.template.sh"
    ENV_TEMPLATE="template/env.qradar.template.sh"
elif [[ "$SIEM_SOLUTION" == "2" ]]; then
    SIEM_SOLUTION_NAME="PT"
    COMPOSE_TEMPLATE="template/pt-docker-compose.template.sh"
    ENV_TEMPLATE="template/env.pt.template.sh"
else
    log_error "Lựa chọn SIEM SOLUTION không hợp lệ! Vui lòng chọn 1 hoặc 2."
    exit 1
fi

read -p "Nhập SOAR URL (ví dụ: https://soar.ncsgroup.vn): " SOAR_URL
if [ -z "$SOAR_URL" ]; then
    log_error "SOAR URL không được để trống!"
    exit 1
fi

read -p "Nhập SOAR IP (máy chủ chạy SOAR): " SOAR_IP
if [ -z "$SOAR_IP" ]; then
    log_error "SOAR IP không được để trống!"
    exit 1
fi

read -p "Nhập SOAR TOKEN cho SIEM: " SOAR_SIEM_TOKEN
if [ -z "$SOAR_SIEM_TOKEN" ]; then
    log_error "SOAR SIEM TOKEN không được để trống!"
    exit 1
fi

if [[ "$SIEM_SOLUTION_NAME" == "QRadar" ]]; then
    read -p "Nhập SOAR TOKEN cho NCS worker: " SOAR_NCS_WORKER_TOKEN
    if [ -z "$SOAR_NCS_WORKER_TOKEN" ]; then
        log_error "SOAR NCS WORKER TOKEN không được để trống!"
        exit 1
    fi

    read -p "Nhập SIEM API KEY (ví dụ: http://<domain>): " SIEM_API_KEY
    if [ -z "$SIEM_API_KEY" ]; then
        log_error "SIEM API KEY không được để trống!"
        exit 1
    fi
fi

read -p "Nhập SIEM URL (ví dụ: http://<domain>): " SIEM_URL
if [ -z "$SIEM_URL" ]; then
    log_error "SIEM URL không được để trống!"
    exit 1
fi

if [[ "$SIEM_SOLUTION_NAME" == "PT" ]]; then
    read -p "Nhập PT USER: " SIEM_USER
    if [ -z "$SIEM_USER" ]; then
        log_error "PT USER không được để trống!"
        exit 1
    fi

    read -p "Nhập PT PASSWORD: " SIEM_PASSWORD
    if [ -z "$SIEM_PASSWORD" ]; then
        log_error "PT PASSWORD không được để trống!"
        exit 1
    fi

    read -p "Nhập PT CLIENT SECRET: " PT_CLIENT_SECRET
    if [ -z "$PT_CLIENT_SECRET" ]; then
        log_error "PT CLIENT SECRET không được để trống!"
        exit 1
    fi
fi
# read -p "Nhập SOAR PROXY URL (https://): " SOAR_PROXY
# read -p "Nhập SIEM PROXY URL (https://): " SIEM_PROXY
# 
# log_info "SOAR URL: $SOAR_URL"
# log_info "SIEM PROXY URL: $SIEM_PROXY"
# log_info "SOAR PROXY URL: $SOAR_PROXY"

# Lấy domain từ URL
SOAR_DOMAIN=${SOAR_URL#*//}
log_info "SOAR DOMAIN: $SOAR_DOMAIN"
# SOAR_DOMAIN=${SOAR_DOMAIN%%/*}

read -p "Bạn có muốn thêm $SOAR_DOMAIN vào /etc/hosts, cần quyền sudo để chạy? (Y/n): " confirm
confirm="${confirm:-Y}"

# Cập nhật file hosts nếu người dùng đồng ý
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    update_hosts "$SOAR_DOMAIN" $SOAR_IP
fi

# Kiểm tra file template tồn tại
if [ ! -f "$COMPOSE_TEMPLATE" ]; then
    log_error "File template $COMPOSE_TEMPLATE không tồn tại!"
    exit 1
fi

if [ ! -f "$ENV_TEMPLATE" ]; then
    log_error "File template $ENV_TEMPLATE không tồn tại!"
    exit 1
fi
# Kiểm tra thư mục images tồn tại
if [ -d "$IMAGE_DIR" ] && [ "$(find "$IMAGE_DIR" -maxdepth 1 -name "*.tar" -type f 2>/dev/null | wc -l)" -gt 0 ]; then
   

    # Có file tar, hỏi người dùng có muốn load không
    read -p "Bạn có muốn load Docker images từ thư mục $IMAGE_DIR không? (Y/n): " load_images_confirm
    load_images_confirm="${load_images_confirm:-Y}"

    if [[ "$load_images_confirm" =~ ^[Yy]$ ]]; then

        # Load tất cả images và mapping với services
        log_info "\nBắt đầu load Docker images từ $IMAGE_DIR..."
        load_images

        # Validate tất cả images cần thiết đã được load
        log_info "\nKiểm tra images..."
        validate_images
    else
        log_info "\n✓ Bỏ qua việc load Docker images"
    fi
else
    # Không có file tar, đọc từ image-list.txt
    log_info "\n✓ Không tìm thấy file .tar trong $IMAGE_DIR"
    log_info "✓ Đang đọc thông tin images từ image-list.txt..."
    
    if load_images_from_list; then
        log_info "\nKiểm tra images..."
        validate_images
    else
        log_error "Không thể đọc thông tin images từ image-list.txt"
        exit 1
    fi
    # Cấu hình awscli 
    configure_awscli
fi


# Tạo thư mục init-scripts nếu chưa có
mkdir -p init-scripts
mkdir -p logs logs/fetchAlerts logs/detailsAlerts logs/syncCloseAlert
sudo chown -R 1000:1000 logs/

# Tạo file cấu hình pg_hba.conf cho Docker network
cat > init-scripts/00-pg_hba.sh <<EOF
#!/bin/bash
echo "host all all 172.20.0.0/16 scram-sha-256" >> /var/lib/postgresql/data/pgdata/pg_hba.conf
EOF

source template/init.sql.sh

cat > init-scripts/redis-users.acl <<EOF
user default off
user $REDIS_USER on >$REDIS_PASSWORD ~* +@all -FLUSHALL -FLUSHDB -CONFIG -SHUTDOWN -DEBUG
EOF

chmod +x init-scripts/00-pg_hba.sh

# source template/env.qradar.template.sh
source template/env.ncssoar-worker.template.sh

# Tạo .env cho docker-compose
cat > .env <<EOF
POSTGRES_ADMIN_USER=postgres
POSTGRES_ADMIN_PASSWORD=$ADMIN_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
EOF

log_info "✓ Environment variables đã được thiết lập"

if [[ "$SIEM_SOLUTION_NAME" == "QRadar" ]]; then
    COMPOSE_TEMPLATE="template/qradar-docker-compose.template.sh"
    source template/env.qradar.template.sh
    source template/qradar-docker-compose.template.sh
    log_info "✓ docker-compose.yml đã được thiết lập"
elif [[ "$SIEM_SOLUTION_NAME" == "PT" ]]; then
    COMPOSE_TEMPLATE="template/pt-docker-compose.template.sh"
    source template/env.pt.template.sh
    source template/pt-docker-compose.template.sh
    log_info "✓ docker-compose.yml đã được thiết lập"
fi

# source template/docker-compose.template.sh
# log_info "✓ docker-compose.yml đã được thiết lập"

# Tạo .env cho update-config
source template/env.update-config.template.sh
log_info "✓ .env cho update-config đã được thiết lập"
echo -e "\n${YELLOW}Đang khởi động Docker containers...${NC}"
docker network prune -f
docker container prune -f
docker compose up -d

# Chờ 15 giây để các service khởi động
log_info "✓ Chờ 15 giây để các service khởi động..."
sleep 15
sudo chmod +x update-config
./update-config