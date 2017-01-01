#!/bin/bash
#
# Compiles NOS and optionally writes to a floppy disk
#

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
fasm ./src/image.asm ./bin/NOS.img || exit 1
#
# Ask the user about the floppy
#
echo -e "Compile complete. Do you want me to write out to a floppy (Y/n)? \c"
read ans
if [ "$ans" = "y" -o "$ans" = "Y" -o "$ans"="" ]
then
    sudo dd if=./bin/NOS.img of=/dev/fd0
    #
    # Notify user in case of failure
    #
    ddret="$?"
    if [ "$ddret" = 0 ]
    then
	echo "dd returned success"
    else
	echo "Error occured - dd returned $ddret"
	echo "Check disk drive /dev/fd0 and try again"
	exit 1
    fi
fi
#
# Ask to compile the DOS program
#
echo -e "Would you like to compile the DOS bootstrapper for loading NOS into a DOS environment (Y/n)? \c"
read ans
if [ "$ans" = "y" -o "$ans" = "Y" -o "$ans" = "" ]
then
	fasm ./dos-bootstrapper/nosboot.asm ./bin/nosboot.exe || exit 1
	echo "Bootstrapper compiled to ./bin/nosboot.exe"
fi
#
# Otherwise exit sucessfully
#
exit 0
