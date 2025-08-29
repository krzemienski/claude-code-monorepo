SHELL := /bin/bash
COMPOSE := docker compose -f deploy/compose/docker-compose.yml

.PHONY: up down logs rebuild ps fetch-backend login

up:            ## Build and start the backend
	$(COMPOSE) up --build -d

down:          ## Stop the backend
	$(COMPOSE) down

logs:          ## Tail logs
	$(COMPOSE) logs -f api

rebuild:       ## Rebuild image without cache
	$(COMPOSE) build --no-cache api

ps:            ## Show compose services
	$(COMPOSE) ps

fetch-backend: ## Vendor the upstream backend into services/backend/claude-code-api
	./scripts/fetch_backend.sh

login:         ## Open an interactive shell for CLI login if needed
	$(COMPOSE) exec api bash -lc "claude /login"
