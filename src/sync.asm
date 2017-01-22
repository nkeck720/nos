;
; SYNC.ASM - a command that makes sure that the currrent RAM image of the 
;			 NOS FSB is saved to disk.
;

; Begin by defining a flat architecture
db "F"
jmp start
message db "Syncing FSB to disk...", 0Dh, 0Ah, 00h
errormsg db "OOPS! A write error occured! Check your disk", 0Dh, 0Ah
		 db "and try again.", 0Dh, 0Ah, 00h
start:
	mov ah, 01h
	mov dx, message
	int 21h
	mov ah, 03h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 02h
	; Get drive from kernel
	push ds
	mov bx, 1000h
	mov ds, bx
	mov dl, byte ptr 0003h
	pop ds
	mov bx, 2000h
	mov es, bx
	mov bx, 0000h
	int 13h
	jc error_writing
	; Return to kernel
	db 0CBh
	
error_writing:
	mov ah, 01h
	mov dx, errormsg
	int 21h
	db 0CBh
	
times 512-($-$$) db 0			; Keep it at one sector