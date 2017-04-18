	;; This is a simple FSB (Filesystem block) for NOS on a 1.44MB floppy disk.
	;; PERSONAL NOTE: there are 18 sectors per track, 2 tracks per cyl, and 80 cyl on a 1.44MB floppy

	;; CHS for Kernel start
	db 00h
	db 00h
	db 03h
	;; Length of kernel in blocks (0FFh here means no kernel on disk)
	db 05h
	;; free blocks
	dw 2875d
	;; total blocks
	dw 2880d
	;; file fields go here

	;; INT21 must be our first file here. Otherwise the kernel will not boot.
	db 80h			; Start of field
	db 00h, 00h, 08h	; CHS of INT21
	db 03h			; INT21 will be 1536 bytes
	db "INT21", 00h, "  "	; Filename and padding
	db 00h			; EXE flag
	db 0FFh 		; End field
	; Example text file for use with type command
	db 80h
	db 00h, 00h, 0Bh
	db 01h
	db "text", 00h, "   "
	db 00h
	db 0FFh
	; Example programs
	db 80h
	db 00h, 00h, 0Ch
	db 01h
	db "hello", 00h, "  "
	db 80h
	db 0FFh
	
	db 80h
	db 00h, 00h, 0Dh
	db 01h
	db "sync", 00h, "   "
	db 80h
	db 0FFh
	
	db 80h
	db 00h, 00h, 0Eh
	db 03h
	db "format", 00h, " "
	db 80h
	db 0FFh
	
	db 80h
	db 00h, 00h, 0Fh
	db 02h
	db "chglog", 00h, " "
	db 80h
	db 0FFh
	

times 511-($-$$) db 00h
db 0FFh
