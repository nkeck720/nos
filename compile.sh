#!/bin/bash

#
# Compiles NOS to /dev/fd0
#

fasm myos.asm myos.img || exit
fasm fsb.asm fsb.img || exit
fasm kernel.asm kernel.img || exit
fasm image.asm NOS.img || exit
dd if=NOS.img of=/dev/fd0
exit

