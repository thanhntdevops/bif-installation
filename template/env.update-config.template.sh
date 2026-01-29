mkdir configs
cat > configs/${TENANT}.yaml <<EOF
tenant: ${TENANT}
services:
  soarncs:
    output_stream: bif_alerts_analyze
    url: ${SOAR_URL}
    access_id: ${SOAR_NCS_WORKER_TOKEN}
  sla:
    Low: 60
    Medium: 60
    High: 30
    Critical: 30
EOF

cat >> .env <<EOF
DEBUG=true
REDIS_HOST=${REDIS_HOST}:6379
REDIS_USER=${REDIS_USER}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_GROUP=bif_core # add tenant
# REDIS_INPUT_STREAM=bif_cpm
REDIS_DB=0
CONFIG_PATH=./configs
EOF