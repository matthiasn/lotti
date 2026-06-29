SHELL := /usr/bin/env bash

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(MAKEFILE_DIR)/../..)
OUT_DIR ?= build/character_video_exports

FPS ?= 60
START ?= 0
DURATION ?=
CRF ?= 18
X264_PRESET ?= veryfast
AUDIO_KBPS ?= 320
REBUILD ?= 0
CAPTIONS ?= 0
OUT ?= $(OUT_DIR)/dance_full_1080p$(FPS)_fast.mp4

REALTIME := tools/character_video_export/export_dance_video_realtime.sh
HIDDEN_EXACT := tools/character_video_export/export_dance_video_app.sh

REBUILD_FLAG = $(if $(filter 1 true yes,$(REBUILD)),--rebuild,)
CAPTIONS_FLAG = $(if $(filter 1 true yes,$(CAPTIONS)),--captions,)
DURATION_FLAG = $(if $(DURATION),--duration $(DURATION),)

COMMON_FLAGS = \
	--fps $(FPS) \
	--start $(START) \
	$(DURATION_FLAG) \
	--crf $(CRF) \
	--audio-kbps $(AUDIO_KBPS) \
	--x264-preset $(X264_PRESET) \
	$(REBUILD_FLAG) \
	$(CAPTIONS_FLAG)

.DEFAULT_GOAL := full-1080p

.PHONY: \
	help \
	smoke-1080p \
	hook-1080p \
	full-720p \
	full-1080p \
	full-1080p-fast \
	full-1080p-hidden \
	full-1440p \
	full-1440p-fast \
	full-1440p-hidden \
	verify

help:
	@printf '%s\n' \
	  'Character dance video exports' \
	  '' \
	  'Default: make full-1080p (native 1920x1080 at 60 fps).' \
	  '' \
	  'Fast targets use rootful Xwayland capture. They finish in minutes on the VM' \
	  'and can show a temporary render window while exporting.' \
	  '' \
	  'Hidden targets use Xvfb + frame-exact app readback. They avoid a visible' \
	  'window but are much slower.' \
	  '' \
	  'Targets:' \
	  '  make smoke-1080p         5s 1080p60 fast smoke around the hook' \
	  '  make hook-1080p          12s 1080p60 fast hook clip' \
	  '  make full-720p           full 720p60 fast export' \
	  '  make full-1080p          full native 1080p60 fast export' \
	  '  make full-1080p-hidden   full native 1080p60 hidden exact export (slow)' \
	  '  make full-1440p          full native 1440p60 fast export (2560x1440)' \
	  '  make full-1440p-hidden   full native 1440p60 hidden exact export (slow)' \
	  '  make verify OUT=...      ffprobe + full-color frame-hash cadence check' \
	  '' \
	  'Useful variables:' \
	  '  REBUILD=1                rebuild release Linux bundle first' \
	  '  FPS=60                   output fps' \
	  '  CRF=18                   x264 CRF' \
	  '  X264_PRESET=veryfast     x264 preset' \
	  '  START=80 DURATION=12     custom clip window' \
	  '  CAPTIONS=1               burn captions'

smoke-1080p: START = 80
smoke-1080p: DURATION = 5
smoke-1080p: CRF = 23
smoke-1080p: X264_PRESET = ultrafast
smoke-1080p:
	cd "$(REPO_ROOT)" && $(REALTIME) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_smoke_1080p$(FPS)_fast.mp4"

hook-1080p: START = 80
hook-1080p: DURATION = 12
hook-1080p:
	cd "$(REPO_ROOT)" && $(REALTIME) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_hook_1080p$(FPS)_fast.mp4"

full-720p:
	cd "$(REPO_ROOT)" && $(REALTIME) \
		--preset 720p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_720p$(FPS)_fast.mp4"

full-1080p: full-1080p-fast

full-1080p-fast:
	cd "$(REPO_ROOT)" && $(REALTIME) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_1080p$(FPS)_fast.mp4"

full-1080p-hidden:
	cd "$(REPO_ROOT)" && $(HIDDEN_EXACT) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_1080p$(FPS)_hidden_exact.mp4"

full-1440p: full-1440p-fast

full-1440p-fast:
	cd "$(REPO_ROOT)" && $(REALTIME) \
		--preset 1440p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_1440p$(FPS)_fast.mp4"

full-1440p-hidden:
	cd "$(REPO_ROOT)" && $(HIDDEN_EXACT) \
		--preset 1440p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_1440p$(FPS)_hidden_exact.mp4"

verify:
	cd "$(REPO_ROOT)" && test -s "$(OUT)"
	cd "$(REPO_ROOT)" && ffprobe -v error -select_streams v:0 \
		-show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate,nb_frames \
		-of default=noprint_wrappers=1 "$(OUT)"
	cd "$(REPO_ROOT)" && ffprobe -v error -select_streams a:0 \
		-show_entries stream=codec_name,sample_rate,channels,bit_rate \
		-of default=noprint_wrappers=1 "$(OUT)"
	cd "$(REPO_ROOT)" && ffprobe -v error -show_entries format=duration,size \
		-of default=noprint_wrappers=1 "$(OUT)"
	cd "$(REPO_ROOT)" && ffmpeg -v error -i "$(OUT)" -map 0:v:0 -an \
		-vf "scale=480:-1,format=rgb24" -f framemd5 - | \
		awk 'BEGIN{prev="";same=0;maxrun=0;run=0;n=0} /^0,/ {hash=$$NF; n++; if(hash==prev){same++; run++} else {if(run>maxrun) maxrun=run; run=0} prev=hash} END{if(run>maxrun) maxrun=run; print "frames=" n, "same=" same, "maxrun=" maxrun}'
