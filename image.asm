	;; Use this to write to whole floppy
	file 'myos.bin'      ;Bootsector
	file 'fsb.bin'	     ;FSB
	file 'kernel.bin'    ;Kernel
	times 1474560-($-$$) db 0
	
