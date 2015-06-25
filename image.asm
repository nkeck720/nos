	;; Use this to write to whole floppy
	file 'myos.img'
	db 0FFh
	db 80h
	file 'int21.img'
	times 1474560-($-$$) db 0
	
