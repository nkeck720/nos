	;
	; This will serve as an example file for
	; testing external program loading in NOS.
	; It also will serve as a template of sorts for
	; flat programs.
	;
	use16
	header db "F"		; Flat structure
	; Begin the code
	push cs
	pop  ds
	mov ah, 01h
	mov dx, message
	int 21h
	db 0CBh
	message db "Hello NOS world!", 0Dh, 0Ah, 00h
	
;----------------------------------
	footer db "EF", 0FFh
	times 512-($-$$) db 0
