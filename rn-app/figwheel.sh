#!/usr/bin/env bash

re-natal use-ios-device simulator
re-natal enable-auto-require
re-natal use-figwheel

lein figwheel ios
