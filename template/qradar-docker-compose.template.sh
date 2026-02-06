#!/bin/bash

cat > docker-compose.yml <<EOF
version: '3.8'

services:
  postgres:
    image: ${SERVICE_IMAGES[postgres]}
    container_name: postgres_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: \${POSTGRES_ADMIN_USER}
      POSTGRES_PASSWORD: \${POSTGRES_ADMIN_PASSWORD}
      POSTGRES_DB: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - bif_network

  redis:
    image: ${SERVICE_IMAGES[redis]}
    container_name: redis_cache
    restart: unless-stopped
    command: redis-server --requirepass \${REDIS_PASSWORD} --appendonly yes --aclfile /etc/redis/users.acl
    # command: redis-server --appendonly yes
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
      - ./init-scripts/redis-users.acl:/etc/redis/users.acl:ro
    networks:
      - bif_network

  ${TENANT}-fetch-alerts:
    image: ${SERVICE_IMAGES[qradar-integration]}
    container_name: ${TENANT}-integration-fetch-alerts
    restart: unless-stopped
    volumes:
      - ./.env.qradar:/app/.env:ro
      - ./logs/fetchAlerts/:/app/logs:rw
    command: python fetchAlerts.py
    networks:
      - bif_network
    depends_on:
      - postgres
      - redis
  ${TENANT}-details-alerts:
    image: ${SERVICE_IMAGES[qradar-integration]}
    container_name: ${TENANT}-integration-details-alerts
    restart: unless-stopped
    volumes:
      - ./.env.qradar:/app/.env:ro
      - ./logs/detailsAlerts/:/app/logs:rw
    command: python detailsAlerts.py
    networks:
      - bif_network
    depends_on:
      - postgres
      - redis
  ${TENANT}-sync-close-alerts:
    image: ${SERVICE_IMAGES[qradar-integration]}
    container_name: ${TENANT}-integration-syncCloseAlert
    restart: unless-stopped
    volumes:
      - ./.env.qradar:/app/.env:ro
      - ./logs/syncCloseAlert/:/app/logs:rw
    command: python syncCloseAlert.py
    networks:
      - bif_network
    depends_on:
      - postgres
      - redis

  ncssoar-worker:
    image: ${SERVICE_IMAGES[ncssoar-worker]}
    container_name: ncssoar-worker
    restart: unless-stopped
    volumes:
      - ./.env.ncssoarworker:/app/.env:ro
      - ./logs:/app/logs:rw
    user: 1000:1000
    networks:
      - bif_network
    depends_on:
      - postgres
      - redis
volumes:
  postgres_data:
  redis_data:
networks:
  bif_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
EOF