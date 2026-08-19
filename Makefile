.PHONY: setup lint test run migrate docker-up docker-down

setup:
	python -m pip install -e "backend[dev]"

lint:
	cd backend && ruff check . && mypy app
	cd mobile && flutter analyze

test:
	cd backend && pytest
	cd mobile && flutter test

run:
	cd backend && uvicorn app.main:app --reload

migrate:
	cd backend && alembic upgrade head

docker-up:
	docker compose up --build

docker-down:
	docker compose down

