	use16
	;
	; This is an example of a program for NOS using the Flat
	; program format.
	; First we need to tell  NOS that this program is flat
	header db "F"
	jmp start
	message db "Listing of boot disk:", 0Dh, 0Ah, 00h
	crlf db 0Dh, 0Ah, 00h
	; Start the program with a message
start:
	push cs
	pop ds
	mov ah, 01h
	mov dx, message
	int 21h
	; First thing is first: update the FSB.
	push es
	mov bx, 1000h
	mov ds, bx
	mov ah, 02h
	mov al, 01d
	mov ch, 00h
	mov cl, 02d		; CL=02 is the FSB
	mov dh, 00h
	mov dl, byte ptr ds:0003h  ;Boot drive stored in kernel space
	mov bx, 2000h		; FSB segment
	mov es, bx
	mov bx, 0000h
	int 13h
	pop es
	push cs
	pop ds
	; Now we need to begin the process of listing out the files.
	; Start by pointing ES:BX at the first file field.
	mov bx, 2000h
	mov es, bx
	mov bx, 0007h
list_files_loop:
	; Now we loop until we find a null, indicating that we have entered empty space.
	; Find the file fields
	mov ah, byte ptr es:bx
	cmp ah, 80h
	je  get_file_name
	; Otherwise, check for null
	cmp ah, 00h
	je done
	; Increment until we find a file
	inc bx
	jmp list_files_loop
get_file_name:
	; The file name is exactly 5 bytes from the 0x80, add that on
	add bx, 05d
	; Now print out the file name on its own
	push dx
	push ds
	mov dx, bx
	push es
	pop ds
	mov ah, 01h
	int 21h
	pop ds
	pop dx
	; Now go to the end of the field
	sub bx, 05d
	add bx, 14d
	; Continue the loop
	jmp list_files_loop
done:
	; We are done here.
	ret
	; Tell NOS that we are at the end.
	footer db "EF", 0FFh

times 512-($-$$) db 00h