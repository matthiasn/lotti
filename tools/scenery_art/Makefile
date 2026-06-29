PYTHON ?= python3

.PHONY: blue-hour inspect

blue-hour:
	$(PYTHON) layer_from_masks.py \
		--master ../../assets/scenery/blue_hour_master.webp \
		--out-dir ../../assets/scenery \
		--preview-dir ../../tmp/scenery_work \
		--layer city_bridge=scenes/blue_hour_waterfront/masks/city_bridge.png \
		--layer yacht=scenes/blue_hour_waterfront/masks/yacht.png \
		--layer foreground=scenes/blue_hour_waterfront/masks/foreground.png
	$(PYTHON) isolate_clouds.py \
		--master ../../assets/scenery/blue_hour_master.webp \
		--city-bridge ../../assets/scenery/city_bridge.webp \
		--yacht ../../assets/scenery/yacht.webp \
		--foreground ../../assets/scenery/foreground.webp \
		--out-dir ../../assets/scenery \
		--preview-dir ../../tmp/scenery_work
	$(PYTHON) bake_city_windows.py

inspect:
	$(PYTHON) inspect_layers.py
