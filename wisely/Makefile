.PHONY: test
test:
	flutter test --coverage

.PHONY: clean
clean:
	flutter clean

.PHONY: deps
deps:
	flutter pub get

.PHONY: coverage
coverage: test
	genhtml coverage/lcov.info -o coverage
	open coverage/index.html

.PHONY: check-null-safety
check-null-safety:
	flutter pub outdated --mode=null-safety

.PHONY: build_runner
build_runner:
	flutter pub run build_runner build --delete-conflicting-outputs

.PHONY: ipa
ipa:
	flutter build ipa

.PHONY: macos
macos:
	flutter build macos


.PHONY: clean_test
clean_test: clean deps test
