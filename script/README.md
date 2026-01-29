# Scripts Quản Lý SOAR

Thư mục này chứa các file thực thi và scripts sẵn sàng cho việc quản lý hệ thống SOAR.

## Nội dung

- `manage-soar` - File thực thi Go để quản lý SOAR (7.3MB, liên kết tĩnh)
- `gen-ssl.sh` - Script tạo chứng chỉ SSL
- `setup.py` - Script cài đặt SOAR

### Công cụ  Cài Đặt SOAR

Script `setup.py` tự động cấu hình hệ thống SOAR mới với các thiết lập mặc định cần thiết.

#### Chức năng

Script sẽ tự động tạo các cấu hình sau nếu chưa tồn tại:

1. **SLA (Service Level Agreement)** - 6 cấu hình thời gian xử lý
   - SLA 15m Assign, 30m Alert, 45m Alert, 60m Alert, 90m Alert, 120m Alert

2. **Severity Levels** - Mức độ nghiêm trọng
   - Critical (Nghiêm trọng), High (Cao), Medium (Trung bình), Low (Thấp)

3. **Priority Levels** - Mức độ ưu tiên
   - High (Cao), Medium (Trung bình), Low (Thấp)

4. **Resolution Configs** - Kết quả xử lý
   - FP (False Positive), TP (True Positive), INC (Sự cố), NC (Cần xác nhận)

5. **Roles** - Vai trò người dùng
   - Tier 1 Trưởng Kíp, Tier 1 - Permission

6. **Integration Sources** - Nguồn tích hợp
   - Integration BIF, Integration n8n BIF (với hard tokens tự động)

7. **Security** - Bảo mật
   - Tự động đổi mật khẩu superadmin thành mật khẩu mạnh ngẫu nhiên

#### Cách sử dụng

```bash
# Sử dụng với URL mặc định (http://192.168.105.6:8080)
python3 setup.py

# Hoặc chỉ định SOAR domain cụ thể
python3 setup.py https://soar.ncsgroup.vn
```

#### Yêu cầu

- Python 3.x
- Thư viện: `requests`, `urllib3`
- Tài khoản superadmin với OTP: 123456 (mặc định trong code)
- Mạng kết nối đến SOAR domain

#### Lưu ý quan trọng

⚠️ **Mật khẩu mới**: Script sẽ tự động thay đổi mật khẩu superadmin và hiển thị mật khẩu mới trong output. **Hãy lưu lại mật khẩu này!**

⚠️ **Integration Tokens**: Nếu tạo mới Integration Sources, tokens sẽ được hiển thị trong output. Lưu lại để cấu hình kết nối.

⚠️ **Idempotent**: Script kiểm tra trước khi tạo, chỉ tạo các cấu hình chưa tồn tại. An toàn để chạy nhiều lần.

#### Output mẫu

```
[*] Logging into SOAR...
[+] Login success
[*] Listing SLA Config...
[+] Total SLA configs found: 6
[+] All required SLA configs exist
...
[✓] Role Tier 1 - Permission created successfully
[+] Generated new superadmin password: xY3k@9mP
[✓] Superadmin password changed successfully
[+] New password: xY3k@9mP
[+] Setup completed successfully
```

#### ⚠️ Quan trọng - Bật Google Authenticator

Sau khi hoàn tất cấu hình và tạo người dùng, **cần bật xác thực Google Authenticator** để bảo mật:

1. Mở file `.env` trong thư mục cài đặt SOAR
2. Thay đổi giá trị `LOGIN_OTP_TYPE`:

```bash
# Trước (OTP qua Email - chỉ dùng khi setup)
LOGIN_OTP_TYPE=1

# Sau (Google Authenticator - production)
LOGIN_OTP_TYPE=2
```

3. Khởi động lại SOAR để áp dụng thay đổi

```bash
docker compose up -d
```

**Lý do:** 
- `LOGIN_OTP_TYPE=1` - Gửi OTP qua Email (dùng khi cài đặt ban đầu, OTP=123456)
- `LOGIN_OTP_TYPE=2` - Sử dụng Google Authenticator (bảo mật cao hơn cho môi trường production)

   
---

### Công cụ Quản lý SOAR

File thực thi `manage-soar` là ứng dụng Go độc lập để quản lý khách hàng, phòng ban và người dùng SOAR.

#### Cách sử dụng

```bash
./manage-soar <SOAR_DOMAIN> <OTP>
```

**Ví dụ:**
```bash
./manage-soar https://soar.ncsgroup.vn 123456
```

#### Tính năng

1. **Tạo Khách hàng + Phòng ban** - Tạo khách hàng và phòng ban cùng lúc
2. **Tạo Người dùng Tier 1** - Tạo người dùng đơn lẻ với mã QR tự động
3. **Tạo Hàng loạt Người dùng Tier 1** - Tạo nhiều người dùng từ file CSV

#### Menu Tương tác

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

#### Định dạng CSV cho Tạo Hàng loạt

File mẫu CSV có sẵn tại `../template/bulk_create_tier_users.csv`.

File CSV cần tuân theo định dạng sau:

```csv
username,email,phone_number
user1,user1@example.com,0123456789
user2,user2@example.com,0987654321
```

#### Mã QR Đầu ra

- Mã QR được tạo tự động cục bộ (không cần internet)
- Lưu vào: `qr-otp/<username>.png`
- Kích thước: 256x256 pixels
- Định dạng: PNG

##### Build từ Source Code

Mã nguồn Go nằm trong thư mục `../build/`.

#### Lệnh Build

```bash
# Sử dụng build script (khuyến nghị)
cd ../build
./build.sh

# Hoặc sử dụng Makefile
cd ../build
make install

# Build thủ công
cd ../build
go build -o manage-soar ./cmd/manage-soar
cp manage-soar ../script/
```

File thực thi sẽ tự động được sao chép vào thư mục `script/` này.

##### Thông tin Binary

- **Ngôn ngữ:** Go 1.21+
- **Kích thước:** ~7.3MB
- **Kiến trúc:** Liên kết tĩnh (không cần dependencies)
- **Nền tảng:** Hoạt động trên Linux, macOS, Windows
- **Mạng:** Tạo QR cục bộ (hoạt động offline)

##### Yêu cầu

- Không cần dependencies bên ngoài (binary độc lập)
- Xác thực qua mã OTP
- Truy cập mạng đến domain SOAR

##### Files Đầu ra

- File thực thi: `manage-soar`
- Mã QR: `qr-otp/<username>.png` (tạo trong thư mục hiện tại)
- Không có logs hoặc files tạm

---
