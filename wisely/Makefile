.PHONY: test
test:
	flutter test --coverage

.PHONY: coverage
coverage: test
	genhtml coverage/lcov.info -o coverage
	open coverage/index.html

.PHONY: check-null-safety
check-null-safety:
	flutter pub outdated --mode=null-safety
