#!/usr/bin/env bash
set -euo pipefail

NETWORK_NAME="traefik"
MTU="1450"
COMPOSE_DIR="/home/base"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
ENV_FILE="${COMPOSE_DIR}/.env"

if [ -t 0 ]; then
  read -rp "Введите домен для Grafana (например, grafana.example.com): " GRAFANA_HOST
else
  read -rp "Введите домен для Grafana (например, grafana.example.com): " GRAFANA_HOST </dev/tty
fi

echo "хост для Grafana: ${GRAFANA_HOST}"

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

echo "Создание файла окружения ${ENV_FILE}…"
cat > "${ENV_FILE}" << EOF
EMAIL=support@llmagent.ru
GRAFANA_HOST=
EOF

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
      - --certificatesresolvers.myresolver.acme.email=${EMAIL}
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

  grafana:
    image: grafana/grafana:latest
    env_file:
      - .env
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.rule=Host(`${GRAFANA_HOST}`)"
      - "traefik.http.routers.grafana.tls=true"
      - "traefik.http.routers.grafana.tls.certresolver=myresolver"

  prometheus:
    image: prom/prometheus:latest
    expose:
      - 9090
    networks:
      - traefik
    restart: always

networks:
  traefik:
    external: true

volumes:
  letsencrypt:
    driver: local
  grafana-data:
    driver: local
EOF

cd "${COMPOSE_DIR}"

echo "Осталось настроить env и запустить"
