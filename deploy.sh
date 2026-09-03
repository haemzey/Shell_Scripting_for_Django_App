#!/bin/bash
set -o pipefail

REPO_URL="https://github.com/haemzey/deploy_django_app.git"
REPO_DIR="deploy_django_app"
DOCKER_LOG_DIR="/var/log/docker_logs"
SERVICES_LOG_FILE="/var/log/services_logs.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DOCKER_COMPOSE_LOG="${DOCKER_LOG_DIR}/docker_compose_${DATE}.log"
DOCKER_LOG_FILE="${DOCKER_LOG_DIR}/docker_${DATE}.log"

dlog(){

    echo "[$(date '+%Y-%m-%d_%H:%M:%S')] $1" | tee -a "$DOCKER_LOG_FILE"
}

slog(){
    
    echo "[$(date '+%Y-%m-%d_%H:%M:%S')] $1" | tee -a "$SERVICES_LOG_FILE"
}

verify_services_log_file() {
    if [[ ! -f "$SERVICES_LOG_FILE" ]]; then
    sudo touch "$SERVICES_LOG_FILE"
    sudo chown "$USER":"$USER" "$SERVICES_LOG_FILE" 
    fi
}

verify_docker_dir() {
    if [[ ! -d "$DOCKER_LOG_DIR" ]]; then
    sudo mkdir "${DOCKER_LOG_DIR}"
    sudo chown "$USER":"$USER" "${DOCKER_LOG_DIR}"
    fi
}

verify_docker_compose_log_file() {
    if [[ ! -f "$DOCKER_COMPOSE_LOG" ]]; then
    sudo touch "${DOCKER_COMPOSE_LOG}"
    sudo chown "$USER:$USER" "${DOCKER_COMPOSE_LOG}" 
    fi
}

clone_or_pull() {
    if [ -d "$REPO_DIR" ]; then
        echo "Repo already exists — pulling latest changes..."
        cd "$REPO_DIR" && git pull
    else
        git clone "$REPO_URL" && cd "$REPO_DIR"
    fi
}

dependency() {
    sudo apt-get update -y
    sudo apt-get upgrade -y 
}

docker_service() {
    verify_services_log_file
    if sudo systemctl enable --now docker; then
        slog "Docker service enabled and started successfully"
        return 0
    else
            slog "Docker service failed"
            return 1
    fi 
}

nginx_service() {
    verify_services_log_file
    if sudo systemctl enable --now nginx; then
        slog "Nginx service enabled and started successfully"
        return 0
    else
        slog "Nginx serice is failed"
        return 1 
    fi
}

check_env_file() {
    if [ ! -f ".env" ]; then
        echo "ERROR: .env file not found. It must be provided separately"
        echo "(e.g. copied from CI secrets) before deployment can continue."
        return 1
    fi
}

echo "********** DEPLOYMENT STARTED **********"

deploy() {
    verify_services_log_file
    docker compose up -d --build 
    if [[ $? -eq 0 ]]; then
        slog "Docker containers started successfully"
        return 0
    else
        slog "ERROR: Docker containers failed to start"
        return 1
    fi
}

deploy_log() {
    verify_docker_dir
    verify_docker_compose_log_file

    if docker compose logs --tail 50 | tee -a "$DOCKER_COMPOSE_LOG" 2>&1; then
        dlog "Docker logs captured successfully at ${$DOCKER_COMPOSE_LOG}"
        return 0
    else
        dlog "ERROR: Failed to capture Docker logs at ${$DOCKER_COMPOSE_LOG}"
        return 1
    fi
}

if ! clone_or_pull; then
    echo "ERROR: git clone/pull failed"
    exit 1
fi

if ! dependency; then
    echo "ERROR: dependency installation failed"
    exit 1
fi

if ! docker_service; then
    echo "ERROR: enabling Docker service failed"
    exit 1
fi

if ! nginx_service; then
    echo "ERROR: enabling Nginx service failed"
    exit 1
fi

if ! check_env_file; then
    exit 1
fi

if ! deploy; then
    echo "ERROR: deployment failed"
    #sendmail
    exit 1
fi

if ! deploy_log; then
    echo "error: deploy logs failed"
    exit 1
fi

echo "********** DEPLOYMENT ENDED **********"