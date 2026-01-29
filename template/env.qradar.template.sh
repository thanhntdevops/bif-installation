cat > .env.qradar <<EOF
TENANT = $(echo "$TENANT" | tr 'A-Z' 'a-z')
PLATFORM=qradar
NUM_WORKER=3

REDIS_HOST=redis
REDIS_PORT=6379
REDIS_USER=${REDIS_USER}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_GROUP=bif_ncs_alert11
REDIS_INPUT_STREAM=bif_details_alert_$(echo "$TENANT" | tr 'A-Z' 'a-z')
FETCH_ALERT_OUTPUT_STREAM=bif_details_alert_$(echo "$TENANT" | tr 'A-Z' 'a-z')


DB_HOST=postgres
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# SOAR
SOAR_URL=${SOAR_URL}
SOAR_TOKEN=${SOAR_TOKEN}
# Qradar

QRADAR_URL=${SIEM_URL}
QRADAR_API_KEY=${SIEM_API_KEY}
# QRADAR_FIELDS=payload, Action, username, sourceip, Source IP Address, sourceport, destinationip, destinationport, Hostname, Message, Method, URL, botURL, User Agent, Actual Action, Machine Identifier, Filename, File Path, Requested Action, Second Action, Threat Name, Operation
EOF