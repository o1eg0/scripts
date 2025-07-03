#!/usr/bin/env bash
set -euo pipefail

NETWORK_NAME="traefik"
MTU="1450"
COMPOSE_DIR="/home/traefik"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
  echo "Создание docker-сети ${NETWORK_NAME}…"
  docker network create \
    --driver=bridge \
    --opt com.docker.network.driver.mtu="${MTU}" \
    "${NETWORK_NAME}"
else
  echo "Сеть ${NETWORK_NAME} существует"
fi

mkdir -p "${COMPOSE_DIR}"

echo "Создание ${COMPOSE_FILE}…"
cat > "${COMPOSE_FILE}" << 'EOF'
services:
  traefik:
    image: traefik:v3.1
    command:
      - --providers.docker
      - --providers.docker.network=traefik
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --entrypoints.web.http.redirections.entryPoint.to=websecure
      - --entrypoints.websecure.http.tls=true
      - --certificatesresolvers.myresolver.acme.tlschallenge=true
      - --certificatesresolvers.myresolver.acme.email=support@llmagent.ru
      - --certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json
      - --api.insecure=true
      - --api.dashboard=true
      - --log.level=INFO
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - letsencrypt:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - traefik
    restart: always

networks:
  traefik:
    external: true

volumes:
  letsencrypt:
    driver: local
EOF

echo "Запускание контейнеров…"
cd "${COMPOSE_DIR}"
docker-compose pull
docker-compose up -d

echo "Traefik запущен в сети ${NETWORK_NAME}."
cd /home/
