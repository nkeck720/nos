	;; This is a simple FSB (Filesystem block) for NOS on a 1.44MB floppy disk.

	;; CHS for Kernel start
	db 00h
	db 00h
	db 03h
	;; Length of kernel in blocks (0FFh here means no kernel on disk)
	db 02h
	;; free blocks
	dw 2876d
	;; total blocks
	dw 2880d
	;; file fields go here
	times 511-($-$$) db 00h
	db 0FFh
	
