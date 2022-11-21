export DESTARCH=arm
export PREFIX=/mmc

export EXTRACFLAGS = -O2 -pipe -march=armv7-a -mtune=cortex-a9
export PATH := $(PATH):/opt/tomatoware/arm-musl-mmc/bin/

rust:
	./scripts/rust.sh

clean:
	git clean -fdxq && git reset --hard
