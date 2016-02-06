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

	;; INT21 must be our first file here. Otherwise the kernel will not boot.
	db 80h			; Start of field
	db 00h, 00h, 05h	; CHS of INT21
	db 02h			; INT21 will be 1024 bytes
	db "INT21", 00h, "  "	; Filename and padding
	db 00h			; EXE flag
	db 0FFh 		; End field
	times 511-($-$$) db 00h
	db 0FFh
	
