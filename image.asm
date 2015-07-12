	;; Use this to write to whole floppy
	file 'myos.img'
	file 'fsb.img'
	db 0FFh
	db 80h
	file 'kernel.img'
	times 1474560-($-$$) db 0
	
