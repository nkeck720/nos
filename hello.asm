	;
	; This will serve as an example file for
	; testing external program loading in NOS.
	; It also will serve as a template of sorts for
	; flat programs.
	;
	
	header db "F"		; Flat structure
	; Begin the code
	push cs
	pop  ds
	mov ah, 01h
	mov dx, message
	int 21h
	ret					; Return to kernel
	
	message db "Hello NOS world!"
	
;----------------------------------
	footer db "EF", 0FFh
	times 512-($-$$) db 0