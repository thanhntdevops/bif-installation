# SOAR Installation - Hệ thống tự động hóa an ninh mạng

## Release
Để sử dụng công cụ thực hiện ở đây: https://gitlab.ncsgroup.vn/rnd/soar/soar-installation/-/releases 

## Giới thiệu dự án

SOAR Installation là một hệ thống triển khai tự động cho nền tảng SOAR (Security Orchestration, Automation and Response) của NCS Group. Dự án này cung cấp các công cụ và script để triển khai một hệ thống SOAR hoàn chỉnh bao gồm:

### Các thành phần chính:
- **SOAR Backend & Frontend**: Hệ thống SOAR chính để quản lý và tự động hóa các quy trình bảo mật
- **N8N Workflow Automation**: Công cụ tự động hóa workflow để tích hợp và điều phối các tác vụ bảo mật
- **PostgreSQL**: Cơ sở dữ liệu lưu trữ dữ liệu hệ thống
- **Redis**: Cache và message broker
- **Elasticsearch**: Công cụ tìm kiếm và phân tích log
- **MinIO**: Object storage để lưu trữ files và artifacts
- **Nginx**: Reverse proxy với SSL/TLS

### Đặc điểm nổi bật:
- ✅ Triển khai tự động hoàn toàn thông qua Docker Compose
- ✅ Tự động tạo SSL certificates cho các domain
- ✅ Quản lý mật khẩu mạnh tự động cho tất cả các services
- ✅ Hỗ trợ cả môi trường online (pull images) và offline (load từ file .tar)
- ✅ Tích hợp sẵn workflow N8N cho SOAR
- ✅ Tự động cấu hình database, tenancy và license

### Kiến trúc hệ thống:
```
┌─────────────────────────────────────────┐
│          Nginx Proxy (Port 443)         │
│        SSL/TLS Termination              │
└────────┬──────────────┬─────────────────┘
         │              │                 │
         │              │                 │
    ┌────▼─────┐   ┌────▼────┐   ┌───────▼────────┐
    │ SOAR FE  │   │  N8N    │   │  SOAR Backend  │
    │  (UI)    │   │         │   │                │
    └──────────┘   └─────────┘   └───────┬────────┘
                                          │
                   ┌──────────────────────┼─────────┬──────────┐
                   │                      │         │          │
                   ▼                      ▼         ▼          ▼
               PostgreSQL               Redis      ES        MinIO
                                                            N8N-API
```

---

## Cài đặt và cấu hình AWS CLI

Trước khi bắt đầu cài đặt hệ thống SOAR, bạn cần cài đặt AWS CLI và cấu hình quyền truy cập để pull Docker images từ AWS ECR (Elastic Container Registry) của NCS Group.

### Bước 1: Cài đặt AWS CLI

#### Trên Linux (Ubuntu/Debian/CentOS/RHEL):
```bash
# File AWS CLI đã được chuẩn bị sẵn trong thư mục tools/
cd tools/

# Giải nén
unzip awscliv2.zip

# Cài đặt
sudo ./aws/install

# Quay lại thư mục gốc
cd ..

# Kiểm tra phiên bản
aws --version
```

> 📦 **Lưu ý**: 
> - File `awscliv2.zip` đã có sẵn trong repo tại `tools/awscliv2.zip`
> - Không cần tải từ Internet, phù hợp cho môi trường offline
> - Nếu gặp lỗi "command not found" sau khi cài đặt, restart terminal hoặc chạy: `source ~/.bashrc`

### Bước 2: Lấy Access Key và Secret Key

> 🔑 **Liên hệ RnD Team**: Access Key và Secret Key sẽ được cung cấp bởi đội RnD của NCS Group.
> 
> **Email**: thanh.nguyen3@ncsgroup.vn
> 
> Thông tin cần cung cấp khi yêu cầu credentials:
> - Tên dự án/khách hàng
> - Mục đích sử dụng (triển khai SOAR)
> - Thời gian dự kiến sử dụng

Sau khi nhận được credentials, bạn sẽ có:
- **AWS Access Key ID**: Ví dụ: `AKIAIOSFODNN7EXAMPLE`
- **AWS Secret Access Key**: Ví dụ: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

### Bước 3: Cấu hình AWS CLI

```bash
# Chạy lệnh configure
aws configure

# Nhập thông tin khi được hỏi:
AWS Access Key ID [None]: <Nhập Access Key được cung cấp>
AWS Secret Access Key [None]: <Nhập Secret Key được cung cấp>
Default region name [None]: ap-southeast-1
Default output format [None]: 
```

### Bước 4: Xác thực với AWS ECR

```bash
# Login vào ECR Registry của NCS
aws ecr get-login-password --region ap-southeast-1 | \
docker login --username AWS --password-stdin \
407869965289.dkr.ecr.ap-southeast-1.amazonaws.com
```

**Kết quả thành công**:
```
Login Succeeded
```

### Bước 5: Kiểm tra quyền truy cập

```bash
# Kiểm tra kết nối với AWS
aws sts get-caller-identity

# Output mẫu:
# {
#     "UserId": "AIDAI...",
#     "Account": "407869965289",
#     "Arn": "arn:aws:iam::407869965289:user/..."
# }

# Test pull một image nhỏ để kiểm tra quyền
docker pull 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/public/nginx:alpine
```

### Xử lý lỗi thường gặp:

**Lỗi**: `Unable to locate credentials`
- **Giải pháp**: Kiểm tra lại file `~/.aws/credentials` đã được tạo và có đúng thông tin chưa

**Lỗi**: `An error occurred (UnrecognizedClientException)`
- **Giải pháp**: Access Key hoặc Secret Key không đúng, liên hệ lại RnD để xác nhận

**Lỗi**: `An error occurred (AccessDeniedException)`
- **Giải pháp**: Tài khoản chưa được cấp quyền pull từ ECR, liên hệ RnD để cấp quyền

**Lỗi**: `Error saving credentials: error storing credentials`
- **Giải pháp**: 
  ```bash
  # Xóa credential helper khỏi Docker config
  rm ~/.docker/config.json
  # Thử login lại
  ```

### Lưu ý bảo mật:

⚠️ **QUAN TRỌNG**:
1. **KHÔNG** commit file `~/.aws/credentials` vào git
2. **KHÔNG** chia sẻ Access Key và Secret Key qua email hoặc chat không mã hóa
3. Nếu nghi ngờ credentials bị lộ, liên hệ RnD ngay để vô hiệu hóa và tạo mới
4. Sau khi hoàn tất việc pull images (Phương án 3 - Full Offline), có thể xóa credentials:
   ```bash
   rm -rf ~/.aws/credentials
   ```

---

## Hướng dẫn sử dụng

### Yêu cầu hệ thống:
- **Hệ điều hành**: Linux (Ubuntu 20.04+, CentOS 7+) hoặc macOS
- **Docker**: Phiên bản 20.10 trở lên
- **Docker Compose**: Phiên bản 2.0 trở lên
- **Python**: Phiên bản 3.8 trở lên
- **RAM**: Tối thiểu 32GB (khuyến nghị 48GB)
- **Disk**: Tối thiểu 500GB trống
- **Network**: Kết nối internet (nếu pull images từ registry)

### Trước khi bắt đầu:

> 🔑 **QUAN TRỌNG - Yêu cầu License**:
> Trước khi chạy bất kỳ script nào (`prepare.sh` hoặc `install.sh`), bạn **BẮT BUỘC** phải có:
> 
> 1. **File License** (`.lic`): 
>    - Liên hệ NCSS Team để nhận file license
>    - Cung cấp thông tin: Tên dự án/khách hàng, mục đích sử dụng
> 
> 2. **License Key**: 
>    - Mã key theo định dạng: `XXXX-XXXX-XXXX-XXXX`
>    - Được cung cấp cùng với file license
> 
> 3. **Copy file license vào thư mục `config/license/`**:
>    ```bash
>    # Tạo thư mục nếu chưa tồn tại
>    mkdir -p config/license/
>    
>    # Copy file license vào thư mục (thay tên file phù hợp)
>    cp /path/to/your/license_file.lic config/license/
>    
>    # Kiểm tra file đã được copy
>    ls -la config/license/
>    ```

**Checklist chuẩn bị**:
1. ✅ Đảm bảo Docker và Docker Compose đã được cài đặt
2. ✅ Có quyền sudo để cập nhật file `/etc/hosts`
3. ✅ **Đã copy file license (`.lic`) vào thư mục `config/license/`**
4. ✅ **Đã có License Key (format: XXXX-XXXX-XXXX-XXXX)**
5. ✅ Có thông tin PAM domain

---

## 1. Chuẩn bị (prepare.sh)

Script `prepare.sh` được sử dụng để pull và lưu các Docker images cần thiết cho hệ thống. 

### Các phương án triển khai:

Script hỗ trợ **3 phương án** triển khai tùy theo môi trường của khách hàng:

#### Phương án 1: Truy cập Internet hoặc Registry của NCS
- **Điều kiện**: Máy chủ triển khai có thể truy cập Internet hoặc kết nối trực tiếp đến Registry của NCS
- **Registry NCS**: `407869965289.dkr.ecr.ap-southeast-1.amazonaws.com`
- **Cách thực hiện**: Trong quá trình cài đặt (install.sh), chọn **không load images từ folder** (chọn `n` khi được hỏi). Hệ thống sẽ tự động pull images từ registry NCS
- **Ưu điểm**: Đơn giản, luôn lấy được phiên bản mới nhất
- **Yêu cầu**: 
  - Whitelist registry NCS trong firewall/proxy
  - Có kết nối internet ổn định
  - Login ECR trước khi pull (nếu cần):
    ```bash
    aws ecr get-login-password --region ap-southeast-1 | \
    docker login --username AWS --password-stdin \
    407869965289.dkr.ecr.ap-southeast-1.amazonaws.com
    ```

#### Phương án 2: Registry nội bộ của khách hàng
- **Điều kiện**: Khách hàng có private registry riêng và không cho phép kết nối ra Internet
- **Cách thực hiện**: 
  1. Cấu hình replication từ Registry NCS (`407869965289.dkr.ecr.ap-southeast-1.amazonaws.com`) về registry nội bộ của khách hàng
  2. Cập nhật file `image-list.txt` để trỏ đến registry nội bộ:
     ```
     postgres: private-registry.customer.com/postgres:16
     redis: private-registry.customer.com/redis:7.2
     soar-fe: private-registry.customer.com/soar-fe:1.5.52
     ...
     ```
  3. Trong quá trình cài đặt, chọn **không load images từ folder** (chọn `n`). Hệ thống sẽ pull từ registry nội bộ
- **Ưu điểm**: Tuân thủ chính sách bảo mật của khách hàng, không cần Internet
- **Yêu cầu**: 
  - Thiết lập replication từ NCS registry
  - Có quyền pull từ registry nội bộ

#### Phương án 3: Full Offline - Không có Internet
- **Điều kiện**: Máy chủ triển khai hoàn toàn không có Internet và không có registry nội bộ
- **Cách thực hiện**:
  1. **Trên máy có Internet** (máy kỹ thuật viên):
     ```bash
     # Clone project về
     git clone <repository-url>
     cd soar-installation
     
     # Login vào Registry NCS (nếu cần)
     aws ecr get-login-password --region ap-southeast-1 | \
     docker login --username AWS --password-stdin \
     407869965289.dkr.ecr.ap-southeast-1.amazonaws.com
     
     # Chạy script prepare để pull và save
     chmod +x prepare.sh
     ./prepare.sh
     # Chọn Y để pull images
     # Chọn Y để save thành file .tar
     ```
  2. **Chuyển folder `images/`** chứa các file `.tar` sang máy chủ triển khai (USB, FTP, SCP...)
  3. **Trên máy triển khai** (không có Internet):
     ```bash
     # Copy folder images/ vào thư mục soar-installation
     ls images/*.tar  # Kiểm tra các file tar
     
     # Chạy install
     ./install.sh
     # Chọn Y khi được hỏi load images từ folder
     ```
- **Ưu điểm**: Phù hợp với môi trường bảo mật cao, không phụ thuộc network
- **Lưu ý**: File tar có thể rất lớn (tổng ~5-10GB), cần đủ dung lượng để chuyển

---

### Cách sử dụng prepare.sh:

#### Bước 1: Chuẩn bị file danh sách images
Đảm bảo file `image-list.txt` tồn tại với định dạng:
```
# Format: service_name: image:tag[@sha256:digest]
elasticsearch: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/public/elasticsearch:8.15.0
minio: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/public/minio:latest
nginx: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/public/nginx:alpine
postgres: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/public/postgres:latest
redis: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/public/redis:latest
soar-fe: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/soar/soar-fe-ss:1.5.52
soar-be: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/soar/soar-be-ss-install:1.4.0
my-n8n: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/soar/my-n8n:2.1.4
n8n-get-info-api: 407869965289.dkr.ecr.ap-southeast-1.amazonaws.com/soar/n8n-get-info-api:latest
```

**Lưu ý**: 
- Đối với **Phương án 1**: Sử dụng registry NCS như trong ví dụ trên
- Đối với **Phương án 2**: Thay thế bằng địa chỉ registry nội bộ của khách hàng
- Đối với **Phương án 3**: Sử dụng registry NCS trên máy có Internet

#### Bước 2: Chạy script prepare (chỉ cho Phương án 3)
```bash
chmod +x prepare.sh
./prepare.sh
```

#### Bước 3: Các bước thực hiện
Script sẽ thực hiện các bước sau:

1. **Kiểm tra Docker**: Xác minh Docker đã được cài đặt và hoạt động
2. **Đọc danh sách images**: Parse file `image-list.txt` và hiển thị danh sách images cần pull
3. **Xác nhận**: Hỏi người dùng có muốn tiếp tục không
   ```
   Bạn có muốn tiếp tục pull images? (Y/n):
   ```
4. **Pull images**: Tải từng image từ registry
   - Hiển thị progress bar cho mỗi image
   - Theo dõi images pull thành công/thất bại
5. **Hiển thị kết quả pull**:
   ```
   ╔═══════════════════════════════════════╗
   ║         Pull Summary                  ║
   ╚═══════════════════════════════════════╝
   ✓ Successfully pulled: 9
   ✗ Failed: 0
   ```
6. **Xác nhận save**: Hỏi có muốn save images thành file `.tar` không
   ```
   Bạn có muốn save images thành file .tar? (Y/n):
   ```
7. **Save images**: Lưu mỗi image thành file `.tar` riêng biệt trong thư mục `images/`
   - Tên file được tạo tự động: `registry-example-com-soar-fe-latest.tar` (VD)
   - Hiển thị size của mỗi file
   
   > ⚠️ **LƯU Ý**: Bước này dành riêng cho các trường hợp:
   > - Khách hàng không có kết nối internet tại môi trường triển khai
   > - Không thể whitelist registry để pull images trực tiếp
   > - Sử dụng registry nội bộ của khách hàng (cần save để re-tag và push lên registry nội bộ)

#### Bước 4: Kết quả
Sau khi hoàn tất, bạn sẽ có:
- Thư mục `images/` chứa các file `.tar` của từng image (Nếu chọn option save)
- Danh sách chi tiết các file đã được lưu với kích thước:
  ```
  📁 Saved to: ./images/
  
  Saved files:
     ./images/postgres-16.tar (123MB)
     ./images/redis-7-2.tar (45MB)
     ./images/nginx-alpine.tar (23MB)
     ...
  ```

#### Xử lý lỗi thường gặp:

**Lỗi**: `image-list.txt không tồn tại`
- **Giải pháp**: Script sẽ tự động tạo file mẫu, chỉnh sửa file này với thông tin images của bạn

**Lỗi**: `Failed to pull image: unauthorized`
- **Giải pháp**: Login vào registry trước: `docker login <registry-url>`

**Lỗi**: `No space left on device`
- **Giải pháp**: Giải phóng dung lượng disk hoặc dọn dẹp Docker:
  ```bash
  docker system prune -a
  ```

**Lỗi**: `Network timeout`
- **Giải pháp**: Kiểm tra kết nối mạng, có thể cần cấu hình proxy cho Docker

---

## 2. Cài đặt (install.sh)

Script `install.sh` thực hiện cài đặt và cấu hình hoàn chỉnh hệ thống SOAR. Đây là script chính để triển khai production.

### Cách sử dụng:

#### Bước 1: Chuẩn bị
```bash
# Đảm bảo có quyền thực thi
chmod +x install.sh

# Đảm bảo file license tồn tại
ls config/license/*.lic
```

#### Bước 2: Chạy script cài đặt
```bash
./install.sh
```

#### Bước 3: Các bước cấu hình (Interactive)

Script sẽ hỏi các thông tin sau:

**1. Domain Configuration**
```
Nhập root domain name (ví dụ: ncsgroup.vn): example.com
```
- Đây là domain gốc cho toàn bộ hệ thống

**2. SOAR Domain**
```
Nhập SOAR DOMAIN (mặc định: soar.example.com): [Enter hoặc nhập custom]
```
- Domain để truy cập SOAR UI và API

**3. N8N Domain**
```
Nhập N8N DOMAIN (mặc định: n8n.example.com): [Enter hoặc nhập custom]
```
- Domain để truy cập N8N workflow automation

**4. PAM Domain**
```
Nhập địa chỉ domain PAM truy cập (Theo syntax: <domain>.pam.ncsgroup.vn): client.pam.ncsgroup.vn
```
- Domain của hệ thống PAM để tích hợp

**5. License Key**
```
Nhập LICENSE: XXXX-XXXX-XXXX-XXXX
```
- License key được cung cấp bởi NCS Group

**6. Cập nhật /etc/hosts**
```
Bạn có muốn thêm soar.example.com và n8n.example.com vào /etc/hosts, cần quyền sudo để chạy? (Y/n):
```
- Chọn `Y` để tự động thêm domain vào file hosts (cần sudo)
- Chọn `n` nếu bạn quản lý DNS riêng

**7. Load Docker Images**
```
Bạn có muốn load Docker images từ thư mục ./images không? (Y/n):
```
- Chọn `Y` nếu bạn có file `.tar` trong thư mục `images/` (triển khai offline)
- Chọn `n` nếu muốn pull images từ registry (cần internet)

#### Bước 4: Quá trình cài đặt tự động

Sau khi nhập xong thông tin, script sẽ tự động:

**1. Tạo mật khẩu mạnh** cho tất cả services:
```
✓ Đang tạo passwords mạnh
  - Admin password
  - Database password
  - Redis password
  - MinIO access key & secret
```

**2. Kiểm tra file license**:
```
✓ Đang kiểm tra file license...
✓ Đã tìm thấy file license: config/license/license_xxx.lic
```

**3. Tạo SSL certificates**:
```
✓ Đang tạo chứng chỉ SSL tự ký cho Nginx...
✓ Đã tạo certificates cho: soar.example.com, n8n.example.com
```

**4. Load hoặc Pull Docker images**:
```
✓ Bắt đầu load Docker images từ ./images/...
✓ Loaded: postgres:16
✓ Loaded: redis:7.2
...
✓ Kiểm tra images... Tất cả images cần thiết đã sẵn sàng
```

**5. Tạo database init scripts**:
```
✓ Đang tạo init scripts cho PostgreSQL...
✓ Đã tạo: init-scripts/00-pg_hba.sh
✓ Đã tạo: init-scripts/01-init.sql
```

**6. Tạo cấu hình Nginx**:
```
✓ Nginx config đã được thiết lập
  - soar.conf (reverse proxy cho SOAR)
  - n8n.conf (reverse proxy cho N8N)
```

**7. Tạo file cấu hình**:
```
✓ Environment variables đã được thiết lập (.env)
✓ docker-compose.yml đã được thiết lập
```

**8. Khởi động Docker containers**:
```
✓ Đang khởi động Docker containers...
[+] Running 9/9
 ✔ Container soar-postgres       Started
 ✔ Container soar-redis          Started
 ✔ Container soar-elasticsearch  Started
 ✔ Container soar-minio          Started
 ✔ Container soar-backend        Started
 ✔ Container soar-frontend       Started
 ✔ Container soar-nginx          Started
 ✔ Container n8n                 Started
 ✔ Container n8n-api             Started
```

**9. Chờ services khởi động**:
```
✓ Chờ 15 giây để các service khởi động...
✓ Kiểm tra kết nối tới SOAR tại https://soar.example.com/api/v1/license/status
[12:34:56] Kết nối thành công! (HTTP 200)
```

**10. Cấu hình SOAR**:
```
Nhập TENANCY CODE: DEMO-TENANT
✓ Cập nhật tenancy thành công
✓ Thiết lập cấu hình cho SOAR thành công
...
...
[+] Token for Integration: a4dc2d4f-6060-4bb6-bb24-0d6f572fbdb2  <- Save for BIF Integration
[+] Using SOAR_TOKEN environment variable in next steps: 2d539ace-1eb6-46c5-add5-d062d2abdb37 <- Lấy SOAR_TOKEN cho step tiếp theo
[+] Generated new superadmin password: U9o/Ql,m./3zTS79 <- superadmin pass please save
```

**11. Cấu hình N8N**:
```
✓ Đang thiết lập N8N...
✓ Kiểm tra kết nối tới N8N tại https://n8n.example.com
[12:35:10] N8N đã sẵn sàng! (HTTP 200)

Nhập email cho N8N Admin: admin@example.com
Nhập SOAR_TOKEN: <token từ SOAR_TOKEN> 

...
...
============================================================
✓ API Key saved to .env file
   Path: /home/cyai/soar-main/.env
============================================================

[INFO] ✓ Thiết lập N8N thành công
```

**12. Khởi động lại containers** để áp dụng cấu hình:
```
✓ Khởi động lại Docker containers để áp dụng cấu hình mới...
✓ Chờ các service khởi động lại...
```

#### Bước 5: Kết quả cài đặt

Sau khi hoàn tất, bạn sẽ thấy thông tin đăng nhập:

```
==========================================
CÀI ĐẶT HOÀN TẤT!
==========================================

📋 THÔNG TIN ĐĂNG NHẬP HỆ THỐNG:
==========================================

🔹 N8N:
   URL: https://n8n.example.com
   Email: admin@example.com
   Password: Ab3xY9pQw2... (tự động tạo)

🔹 Other Info:
   Domain: example.com
   N8N Domain: n8n.example.com
   Tenancy Code: DEMO-TENANT
   License: XXXX-XXXX-XXXX-XXXX

==========================================
⚠️  VUI LÒNG LƯU TẤT CẢ THÔNG TIN TRÊN!
⚠️  NHỚ CẬP NHẬT CẤU HÌNH EMAIL TRONG FILE .env
==========================================
```

**⚠️ LƯU Ý QUAN TRỌNG**: Sao chép và lưu tất cả thông tin đăng nhập vào nơi an toàn!

#### Bước 6: Truy cập hệ thống

**SOAR UI**:
```
URL: https://soar.example.com
Username: <tạo từ SOAR admin panel>
Password: <tạo từ SOAR admin panel>
OTP Default: 123456
```

> 📱 **LƯU Ý QUAN TRỌNG**: Sau khi đăng nhập lần đầu tiên, hệ thống sẽ hiển thị **QR Code** để cấu hình OTP (One-Time Password). 
> - **Bắt buộc**: Sử dụng ứng dụng xác thực (Google Authenticator, Microsoft Authenticator, Authy, etc.) để quét QR Code
> - **Lưu lại**: QR Code chỉ hiển thị một lần, hãy chắc chắn bạn đã quét và lưu thành công trước khi đóng

**N8N Workflow Automation**:
```
URL: https://n8n.example.com
Email: <email đã nhập trong quá trình cài đặt>
Password: <password được tạo tự động>
```

#### Bước 7: Cấu hình bổ sung

**1. Cấu hình Email (Bắt buộc cho notifications)**:
```bash
# Chỉnh sửa file .env
nano .env

# Cập nhật các thông số email:
FROM_MAIL=soar@ncs.vn
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_SMTP_AUTH=true
MAIL_STARTTLS_ENABLE=true

# Restart containers để áp dụng cấu hình email
docker compose up -d
```

> ⚠️ **BẮT BUỘC - Kích hoạt OTP Authentication**: Sau khi cấu hình email server thành công, **BẮT BUỘC** phải kích hoạt OTP Authentication:
> 
> ```bash
> # Mở file .env
> nano .env
> 
> # Tìm và thay đổi:
> LOGIN_OTP_TYPE=1    # OTP qua Email (mặc định)
> 
> # Thành:
> LOGIN_OTP_TYPE=2    # OTP qua Google Authenticator (bắt buộc cho production)
> 
> # Lưu file và restart
> docker compose up -d
> ```


**2. Kiểm tra logs**:
```bash
# Xem logs của tất cả services
docker compose logs -f

# Xem logs của service cụ thể
docker compose logs -f soar-backend
docker compose logs -f n8n
```

#### Xử lý lỗi thường gặp:

**Lỗi**: `License file not found`
- **Giải pháp**: Đảm bảo file `.lic` tồn tại trong `config/license/`

**Lỗi**: `Cannot connect to database`
- **Giải pháp**: 
  ```bash
  # Kiểm tra PostgreSQL container
  docker compose logs postgres
  
  # Restart PostgreSQL
  docker compose restart postgres
  ```

**Lỗi**: `Port 443 already in use`
- **Giải pháp**: 
  ```bash
  # Tìm process đang dùng port 443
  sudo lsof -i :443
  
  # Stop service đang conflict
  sudo systemctl stop apache2  # hoặc nginx
  ```

**Lỗi**: `SSL certificate error`
- **Giải pháp**: Certificates tự ký cần được trust:
  ```bash
  # macOS
  sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain \
    config/certs/soar.example.com.crt
  
  # Linux
  sudo cp config/certs/*.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
  ```

**Lỗi**: `N8N workflow import failed`
- **Giải pháp**: Import thủ công:
  1. Login vào N8N UI
  2. Vào menu Workflows > Import
  3. Upload file `n8n-workflows/Core_Webhook.json`

#### Quản lý hệ thống:

**Dừng toàn bộ hệ thống**:
```bash
docker compose down
```

**Khởi động lại**:
```bash
docker compose up -d
```

**Xem resource usage**:
```bash
docker stats
```

**Backup database**:
```bash
docker compose exec postgres pg_dump -U soar soar > backup_$(date +%Y%m%d).sql
```

**Restore database**:
```bash
cat backup_20260115.sql | docker compose exec -T postgres psql -U soar -d soar
```

---
## 3. Công cụ Quản lý SOAR

File thực thi `manage-soar` là ứng dụng Go độc lập để quản lý khách hàng, phòng ban và người dùng SOAR.

### Cách sử dụng

```bash
./manage-soar <SOAR_DOMAIN> <OTP>
```

**Ví dụ:**
```bash
./manage-soar https://soar.ncsgroup.vn 123456
```

### Tính năng

1. **Tạo Khách hàng + Phòng ban** - Tạo khách hàng và phòng ban cùng lúc
2. **Tạo Người dùng Tier 1** - Tạo người dùng đơn lẻ với mã QR tự động
3. **Tạo Hàng loạt Người dùng Tier 1** - Tạo nhiều người dùng từ file CSV

### Menu Tương tác

Sau khi xác thực thành công, bạn sẽ thấy menu tương tác:

```
========================================
        SOAR Management System
========================================
1. Create Customer + Department
2. Create Tier 1 User
3. Bulk Create Tier 1 Users from CSV
0. Exit
========================================
```

### Định dạng CSV cho Tạo Hàng loạt

File mẫu CSV có sẵn tại `template/bulk_create_tier_users.csv`.

File CSV cần tuân theo định dạng sau:

```csv
username,email,phone_number
user1,user1@example.com,0123456789
user2,user2@example.com,0987654321
```

### Mã QR Đầu ra

- Mã QR được tạo tự động cục bộ (không cần internet)
- Lưu vào: `qr-otp/<username>.png`
- Kích thước: 256x256 pixels
- Định dạng: PNG

> ⚠️ **LƯU Ý BẢO MẬT**: 
> - Sau khi gửi mã QR cho người dùng, **BẮT BUỘC XÓA** thư mục `qr-otp/` để đảm bảo an toàn
> - Mã QR chứa secret key để thiết lập OTP, không được để lộ ra ngoài
> - Chạy lệnh xóa: `rm -rf qr-otp/`


### Build từ Source Code cho Dev

Mã nguồn Go nằm trong thư mục `build/`.

#### Lệnh Build

```bash
# Sử dụng build script (khuyến nghị)
cd build
./build.sh

# Hoặc sử dụng Makefile
cd build
make install

# Build thủ công
cd build
go build -o manage-soar ./cmd/manage-soar
cp manage-soar ../script/
```

File thực thi sẽ tự động được sao chép vào thư mục `script/`.

#### Yêu cầu

- Không cần dependencies bên ngoài (binary độc lập)
- Xác thực qua mã OTP
- Truy cập mạng đến domain SOAR

---
## 4. Cấu trúc thư mục quan trọng

```
soar-installation/
├── install.sh              # Script cài đặt chính
├── prepare.sh              # Script pull và save images
├── image-list.txt          # Danh sách Docker images
│
├── script/
│   ├── function.sh         # Các hàm tiện ích dùng chung
│   ├── gen-certs.sh        # Script tạo SSL certificates
│   ├── setup.py            # Script cấu hình SOAR
│   └── setup-n8n.py        # Script cấu hình N8N
│
├── template/
│   ├── docker-compose.template.sh   # Template Docker Compose
│   ├── .env.template.sh             # Template biến môi trường
│   ├── soar-template.conf.sh        # Template Nginx config cho SOAR
│   ├── n8n-template.conf.sh         # Template Nginx config cho N8N
│   └── init.sql.sh                  # Template SQL khởi tạo database
│
├── config/
│   ├── license/            # Thư mục chứa file license
│   ├── certs/              # SSL certificates (tự động tạo)
│   └── nginx/              # Nginx configs (tự động tạo)
│
├── images/                 # Docker image tar files (offline install)
├── n8n-workflows/          # N8N workflow definitions
└── init-scripts/           # Database init scripts (tự động tạo)
```

---

## 5. Hỗ trợ

Nếu gặp vấn đề trong quá trình cài đặt, vui lòng:
1. Kiểm tra logs: `docker compose logs -f`
2. Xem lại các yêu cầu hệ thống
3. Liên hệ RnD support: thanh.nguyen3@ncsgroup.vn

---

**Phát triển bởi NCS Group**  
**Version**: 1.0.0  
**Last Updated**: January 2026
