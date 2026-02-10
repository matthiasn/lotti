# Makefile for Matrix Provisioner Tool

.PHONY: help install install-dev test test-cov test-watch lint format clean setup-env

# Default target
help: ## Show this help message
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Installation
install: ## Install production dependencies
	pip install -r requirements.txt

install-dev: ## Install development and test dependencies
	pip install -r requirements.txt
	pip install -r requirements-dev.txt

##@ Testing
test: ## Run all tests
	pytest tests/ -v --tb=short

test-cov: ## Run tests with coverage
	pytest tests/ -v --cov=. --cov-report=html --cov-report=term-missing

test-watch: ## Run tests in watch mode
	pytest-watch tests/ -- -v

##@ Code Quality
lint: ## Run linting
	flake8 *.py tests/
	isort --check-only --diff *.py tests/
	black --check *.py tests/ --line-length=100

format: ## Format code
	isort *.py tests/
	black *.py tests/ --line-length=100

##@ Utilities
clean: ## Clean up build artifacts and cache files
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf .pytest_cache/ 2>/dev/null || true
	rm -rf htmlcov/ 2>/dev/null || true
	rm -rf .coverage 2>/dev/null || true

setup-env: ## Set up development environment
	python -m venv .venv
	@echo "Virtual environment created. Activate it with:"
	@echo "  source .venv/bin/activate"
	@echo "Then run: make install-dev"
