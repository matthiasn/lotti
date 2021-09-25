.PHONY: test
test:
	flutter test --coverage

.PHONY: coverage
coverage: test
	genhtml coverage/lcov.info -o coverage
	open coverage/index.html
