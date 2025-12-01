# Makefile for Credits Service

.PHONY: help install install-dev test test-unit test-integration lint format type-check security-scan clean run docker-build docker-run

# Default target
help: ## Show this help message
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Installation
install: ## Install production dependencies
	pip install -r requirements.txt

install-dev: ## Install development and test dependencies
	pip install -r requirements.txt -r requirements-test.txt
	pip install flake8 mypy black isort bandit safety

##@ Testing
test: ## Run all tests
	pytest tests/ -v --cov=src --cov-report=html --cov-report=term-missing

test-unit: ## Run unit tests only
	pytest tests/unit -v --cov=src --cov-report=term-missing

test-integration: ## Run integration tests only
	pytest tests/integration -v

test-watch: ## Run tests in watch mode
	pytest-watch tests/ -- -v

##@ Code Quality
lint: ## Run linting
	flake8 src tests
	isort --check-only --diff src tests
	black --check src tests --line-length=100

format: ## Format code
	isort src tests
	black src tests --line-length=100

type-check: ## Run type checking
	mypy src

security-scan: ## Run security scans
	safety check -r requirements.txt -r requirements-test.txt
	bandit -r src

check-all: ## Run all checks
	make lint
	make type-check
	make security-scan

##@ Development
run: ## Run the service locally
	python -m src.main

run-dev: ## Run the service in development mode with auto-reload
	uvicorn src.main:app --host 0.0.0.0 --port 8001 --reload

##@ Docker
docker-build: ## Build Docker image
	docker-compose build

docker-up: ## Start services with Docker Compose
	docker-compose up

docker-down: ## Stop services
	docker-compose down

docker-logs: ## View service logs
	docker-compose logs -f

docker-clean: ## Clean up Docker volumes
	docker-compose down -v

##@ Utilities
clean: ## Clean up build artifacts and cache files
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache/ 2>/dev/null || true
	rm -rf htmlcov/ 2>/dev/null || true
	rm -rf .coverage 2>/dev/null || true
	rm -rf coverage.xml 2>/dev/null || true
	rm -rf dist/ 2>/dev/null || true
	rm -rf build/ 2>/dev/null || true

setup-env: ## Set up development environment
	python -m venv venv
	@echo "Virtual environment created. Activate it with:"
	@echo "  source venv/bin/activate  (Linux/Mac)"
	@echo "  venv\\Scripts\\activate     (Windows)"
	@echo "Then run: make install-dev"
