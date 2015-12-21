#!/bin/bash

#
# Compiles NOS to /dev/fd0
#

fasm bootload.asm bootload.bin || exit
fasm fsb.asm fsb.bin || exit
fasm kernel.asm kernel.bin || exit
fasm int21.asm int21.bin || exit
fasm image.asm NOS.img || exit
dd if=NOS.img of=/dev/fd0
exit

