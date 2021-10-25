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

.PHONY: build_runner_watch
build_runner_watch:
	flutter pub run build_runner watch --delete-conflicting-outputs --use-polling-watcher

.PHONY: ipa
ipa: clean_test
	flutter build ipa

.PHONY: macos
macos:
	flutter build macos

.PHONY: viz
viz:
	dart pub global run dcdg -o classes.viz.puml -s lib/classes/
	PLANTUML_LIMIT_SIZE=12000 plantuml classes.viz.puml
	open classes.viz.png


.PHONY: clean_test
clean_test: clean deps build_runner test
