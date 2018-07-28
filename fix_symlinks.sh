#!/usr/bin/env bash

cd target
tar -hcf - jlink | tar xf - -C ../bin/
cd ..
