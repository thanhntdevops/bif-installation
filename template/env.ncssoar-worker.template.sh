cat > .env.ncssoarworker <<EOF
DEBUG=false
REDIS_HOST=redis:6379
REDIS_USER=${REDIS_USER}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_GROUP=bif_ncs_alerts
REDIS_INPUT_STREAM=bif_cpm
REDIS_DB=0
# Configuration settings for number of threads to use for processing data.
THREADS=5

# Configuration settings for the database connection.
DB_HOST=postgres
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
MAX_RETRIES=5
TIME_WAIT=1

WORKFLOW_TEMPLATE="Giám sát ATTT"

DEPARTMENT_CODE=NCS
TENANCY_CODE=NCS
EOF