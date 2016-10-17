	;; Use this to write to whole floppy
	file 'bootload.bin'	 ;Bootsector
	file 'fsb.bin'	     ;FSB
	file 'kernel.bin'    ;Kernel
	file 'int21.bin'     ;API
	times 1474560-($-$$) db 0
	
