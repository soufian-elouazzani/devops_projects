.PHONY: test demo demo-down observe observe-down stats

test:
	cd app && python3 -m unittest test_app -v

demo:
	./projects/04-blue-green/scripts/up.sh

demo-down:
	./projects/04-blue-green/scripts/down.sh

observe:
	docker compose -f projects/06-observability/docker-compose.yml up -d --build

observe-down:
	docker compose -f projects/06-observability/docker-compose.yml down

stats:
	./projects/01-server-observability/server-stats.sh
