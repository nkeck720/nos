	;; Use this to write to whole floppy
	file 'bootload.bin'	 ;Bootsector
	file 'fsb.bin'	     ;FSB
	file 'kernel.bin'    ;Kernel
	file 'int21.bin'     ;API
	file 'text.bin' 	 ;Example text file
	file 'hello.bin'	 ;Example program
	times 1474560-($-$$) db 0
	
