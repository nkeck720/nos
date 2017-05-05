#!/bin/bash
#
# Compiles NOS and optionally writes to a floppy disk
#

#
# Check for an argument called "clean"
#
if [ "$1" = "clean" ]
then
    echo "Cleaning build dir..."
    rm -rf ./bin
    exit
fi

#
# Check to see if ./bin exists
#
if [ ! -d ./bin ]
then
	rm -rf ./bin	# to remove the file if it isn't a dir
	mkdir ./bin || exit 2
fi

fasm ./src/bootload.asm ./bin/bootload.bin || exit 1
fasm ./src/fsb.asm ./bin/fsb.bin || exit 1
fasm ./src/kernel.asm ./bin/kernel.bin || exit 1
fasm ./src/int21.asm ./bin/int21.bin || exit 1
fasm ./src/text.asm ./bin/text.bin || exit 1
fasm ./src/hello.asm ./bin/hello.bin || exit 1
fasm ./src/sync.asm ./bin/sync.bin || exit 1
fasm ./src/format.asm ./bin/format.bin || exit 1

#
# We have to have the source file in the same dir as the bins
#
cp ./src/image.asm ./bin/image.asm
cd ./bin
fasm image.asm NOS.img || exit 1
cd ..
rm ./bin/image.asm

#
# I removed this bit because it's pretty trivial to write out a disk image in userspace and
# because it was causing bugs on systems other than Ubuntu.
#

#
# Ask to compile the DOS program
#
echo -e "Would you like to compile the DOS bootstrapper for loading NOS into a DOS environment (Y/n)? \c"
read ans
if [ "$ans" = "y" -o "$ans" = "Y" -o "$ans" = "" ]
then
	cd dos-bootstrapper
	fasm nosboot.asm ../bin/nosboot.exe || exit 1
	echo "Bootstrapper compiled to ./bin/nosboot.exe"
	cd ..
fi
#
# Otherwise exit sucessfully
#
exit 0
