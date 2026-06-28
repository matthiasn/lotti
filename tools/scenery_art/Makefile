PYTHON ?= python3

.PHONY: blue-hour

blue-hour:
	$(PYTHON) layer_from_masks.py \
		--master ../../assets/scenery/blue_hour_master.png \
		--out-dir ../../assets/scenery \
		--preview-dir ../../tmp/scenery_work \
		--layer city_bridge=scenes/blue_hour_waterfront/masks/city_bridge.png \
		--layer yacht=scenes/blue_hour_waterfront/masks/yacht.png \
		--layer foreground=scenes/blue_hour_waterfront/masks/foreground.png
	$(PYTHON) isolate_clouds.py \
		--master ../../assets/scenery/blue_hour_master.png \
		--city-bridge ../../assets/scenery/city_bridge.png \
		--yacht ../../assets/scenery/yacht.png \
		--foreground ../../assets/scenery/foreground.png \
		--out-dir ../../assets/scenery \
		--preview-dir ../../tmp/scenery_work
