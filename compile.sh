#!/bin/bash
#
# Compiles NOS and optionally writes to a floppy disk
# 

fasm bootload.asm bootload.bin || exit 1
fasm fsb.asm fsb.bin || exit 1
fasm kernel.asm kernel.bin || exit 1
fasm int21.asm int21.bin || exit 1
fasm image.asm NOS.img || exit 1
#
# Ask the user about the floppy
#
echo -e "Do you want me to write out to a floppy (Y/n)? \c"
read ans
if [ "$ans" = "y" -o "$ans" = "Y" -o "$ans"="" ]
then
    sudo dd if=NOS.img of=/dev/fd0
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
# Otherwise exit sucessfully
#
exit 0
