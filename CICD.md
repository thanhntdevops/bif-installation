# GitLab CI/CD Pipeline cho SOAR Installation

File `.gitlab-ci.yml` được cấu hình để tự động build và release package `soar-installation`.

## Pipeline Stages

### 1. Build Stage

Pipeline build cho **Linux (amd64)** sử dụng Docker với Go 1.21.

**Artifacts bao gồm:**
- `script/` - Binary và scripts quản lý
- `template/` - Template files (.env, docker-compose, etc.)
- `config/` - Configuration files (license, etc.)
- `image-list.txt` - Danh sách Docker images
- `install.sh`, `prepare.sh` - Installation scripts

**Loại trừ:**
- `build/` - Source code Go (không cần trong production)

### 2. Release Stage

Tự động tạo GitLab Release khi có tag mới với:
- Package artifact hoàn chỉnh
- Download link cho Linux
- Release notes tự động

## Cách sử dụng

### Build thủ công

Push code lên GitLab, pipeline sẽ tự động chạy khi push lên branch `main`:

```bash
git add .
git commit -m "Update soar-installation"
git push origin main
```

### Tạo Release

Tạo tag để release phiên bản mới:

```bash
# Tạo tag với version number
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

Pipeline sẽ:
1. Build Linux package với tất cả files cần thiết
2. Tạo GitLab Release với tag v1.0.0
3. Upload artifact package và tạo download link

### Download Package

Sau khi release, khách hàng có thể tải package từ:

**Qua GitLab UI:**
```
Project → Releases → Chọn version → Download artifacts
```

**Qua Direct Link:**
```
https://gitlab.com/<namespace>/<project>/-/jobs/artifacts/v1.0.0/download?job=build:linux
```

**Giải nén và sử dụng:**
```bash
# Giải nén package
unzip soar-installation-linux-amd64-*.zip

# Chạy binary
cd script
chmod +x manage-soar
./manage-soar <SOAR_DOMAIN> <OTP>

# Hoặc chạy installation
./install.sh
```

## Artifacts

Build job tạo package hoàn chỉnh với thời hạn 30 ngày:

**Bao gồm:**
- `script/` - Binary `manage-soar` và các scripts
- `template/` - Template files
- `config/` - License và configs
- Installation scripts

**Không bao gồm:**
- `build/` - Source code (excluded)

## Yêu cầu

### GitLab Runner

Cần có runner với Docker executor cho Linux builds.

### Variables

Không cần cấu hình thêm variables, pipeline sử dụng:
- `GO_VERSION`: Go 1.21 (có thể thay đổi)
- `BINARY_NAME`: soar-installation

## Trigger Conditions

Pipeline chạy khi:
- ✅ Push lên branch `main`
- ✅ Tạo tag mới (vd: v1.0.0)

Pipeline KHÔNG chạy khi:
- ❌ Push lên branch khác
- ❌ Tạo merge request (đã disable)

## Tùy chỉnh

### Thay đổi Go version

```yaml
variables:
  GO_VERSION: "1.22"  # Thay đổi version
```

### Thêm files vào artifacts

```yaml
artifacts:
  paths:
    - script/
    - template/
    - config/
    - your-new-folder/  # Thêm folder mới
```

### Build cho ARM64

Thêm job mới:

```yaml
build:linux-arm64:
  stage: build
  image: golang:${GO_VERSION}
  script:
    - cd build
    - GOARCH=arm64 make install
  artifacts:
    name: "${BINARY_NAME}-linux-arm64"
    paths:
      - script/
      - template/
      - config/
```

### Chạy tests trước build

Thêm stage test:

```yaml
stages:
  - test
  - build
  - release

test:
  stage: test
  image: golang:${GO_VERSION}
  script:
    - cd build
    - go test -v ./...
```

## Troubleshooting

### Build fails

Kiểm tra:
1. Go version tương thích
2. Dependencies trong go.mod đúng
3. Makefile có target `install`

### Artifacts không đầy đủ

Kiểm tra paths trong artifacts và đảm bảo exclude đúng:
```yaml
exclude:
  - build/**/*  # Source code không cần
```

### Release không tạo

Kiểm tra:
1. Có quyền tạo release trong project settings
2. Tag format đúng (vd: v1.0.0)
3. Job build:linux thành công

## Best Practices

1. **Semantic Versioning**: Sử dụng format `vMAJOR.MINOR.PATCH`
   ```bash
   git tag -a v1.0.0 -m "Initial release"
   git tag -a v1.0.1 -m "Bug fixes"
   git tag -a v1.1.0 -m "New features"
   ```

2. **Release Notes**: Cập nhật description trong `.gitlab-ci.yml` hoặc thêm `CHANGELOG.md`

3. **Testing**: Thêm automated tests trước khi release

4. **Notifications**: Cấu hình GitLab notifications để thông báo khi có release mới

## Security

- Artifacts expire sau 30 ngày để tiết kiệm storage
- Chỉ build từ branch `main` và `tags`
- Source code không được include trong artifacts

## Monitoring

Xem pipeline status:
```
Project → CI/CD → Pipelines
```

Download build logs:
```
Project → CI/CD → Jobs → Chọn job → Download logs
```
