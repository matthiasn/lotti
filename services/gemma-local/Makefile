# Makefile for Gemma Local Service

.PHONY: help install install-dev test test-unit test-integration lint format type-check security-scan clean run run-new docker-build docker-run

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
	flake8 src tests --max-line-length=127 --extend-ignore=E203,W503
	isort --check-only --diff src tests
	black --check src tests

format: ## Format code
	isort src tests
	black src tests

type-check: ## Run type checking
	mypy src --ignore-missing-imports --disable-error-code=import

security-scan: ## Run security scans
	safety check -r requirements.txt -r requirements-test.txt
	bandit -r src

##@ Development
run: ## Run the legacy server
	python main.py

run-new: ## Run the new modular server
	python -m src.main_new

run-dev: ## Run the new server in development mode with auto-reload
	uvicorn src.main_new:app --host 0.0.0.0 --port 8000 --reload

##@ Docker
docker-build: ## Build Docker image
	docker build -t gemma-local-service:latest .

docker-run: ## Run Docker container
	docker run -it --rm -p 8000:8000 \
		-e LOG_LEVEL=INFO \
		gemma-local-service:latest

docker-dev: ## Run Docker container with volume mount for development
	docker run -it --rm -p 8000:8000 \
		-v $(PWD):/app \
		-e LOG_LEVEL=DEBUG \
		gemma-local-service:latest

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

benchmark: ## Run basic performance benchmark
	@echo "Running basic benchmark..."
	python -c "
import time
import requests
import json
import statistics
from concurrent.futures import ThreadPoolExecutor

def test_health():
    start = time.perf_counter()
    response = requests.get('http://localhost:8000/health')
    end = time.perf_counter()
    return (end - start) * 1000, response.status_code == 200

def run_benchmark():
    print('Starting benchmark (ensure server is running on port 8000)...')
    times = []
    successes = 0

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(test_health) for _ in range(100)]
        for future in futures:
            try:
                duration, success = future.result(timeout=5)
                times.append(duration)
                if success:
                    successes += 1
            except Exception as e:
                print(f'Request failed: {e}')

    if times:
        print(f'Requests: {len(times)}')
        print(f'Success rate: {successes/len(times)*100:.1f}%')
        print(f'Average response time: {statistics.mean(times):.2f}ms')
        print(f'Median response time: {statistics.median(times):.2f}ms')
        print(f'95th percentile: {sorted(times)[int(len(times)*0.95)]:.2f}ms')
    else:
        print('No successful requests')

if __name__ == '__main__':
    run_benchmark()
"

##@ Documentation
docs: ## Generate documentation (if we add docs later)
	@echo "Documentation generation not yet implemented"

check-all: lint type-check test ## Run all code quality checks