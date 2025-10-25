.PHONEY: clean run

all: help

help: 
	@echo make [ clean macpaste run ]

clean:
	-rm -f macpaste

macpaste: macpaste.m
	gcc -O2 -framework AppKit -framework ApplicationServices -o macpaste macpaste.m

run:
	./macpaste
