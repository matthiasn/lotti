.PHONY: test
test:
	flutter test --no-sound-null-safety --coverage

.PHONY: coverage
coverage: test
	genhtml coverage/lcov.info -o coverage
	open coverage/index.html
