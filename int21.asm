	use16
	;;
	;; This file contains the INT 21 API for the NOS kernel.
	;; Table of functions follows:
	;;
	;; AX=0123h, BX=4567h, CX=8910h, DX=FFFFh: This invokes a kernel panic routine. This is not available
	;; to user apps (the NOS kernel will call the panic with CF set and a byte in RAM set to FFh). This
	;; sends a message to the user and halts the machine.
	;;
	;; AH=00h: Does nothing, returns AX=5555h
	;; AH=01h: Write string to display (null terminated) from DS:DX, returns number of chars written
	;;	   in  BH.
	;; AH=02h: Open a file. Opens file whose null-terminated name is in DS:DX, and loads the contents
	;;	   of the file to ES:BX. Returns number of blocks read in AL, CF is set on an error, and
	;;	   BH describes the error when CF is set.
	;; AH=03h: Close a file. DS:DX points to the null-terminated file name, ES:BX points to the file
	;;	   contents, and AH contains the number of blocks to be written. Returns nothing on no error,
	;;	   if an error occurs then CF is set and BH describes the error.
	;; AH=04h: Gets the NOS version and places two ASCII characters into CX. (e.g. CX="20", NOS 2.0)
	;;	   Minor version number is placed in AL (e.g. Rev 3, AL="3")
	;; AH=05h: No function is here yet, this will just IRET until something gets placed here.
	;; AH=06h: Gets a string from the user until the user presses return. The string is placed into
	;;	   RAM pointed to by DS:DX.

	;; First we want to check if the kernel panic thing is being called.
	pushf
	pushf			; For later functions
	cmp ax, 0123h
	jne main_func_check
	cmp bx, 4567h
	jne main_func_check
	cmp cx, 8910h
	jne main_func_check
	cmp dx, 0FFFFh
	jne main_func_check
	;; Now check for the RAM byte (0x9000:0xFFFF)
	push es
	push bx
	mov bx, 9000h
	mov es, bx
	mov ah, byte ptr es:0FFFFh
	pop bx
	pop es
	cmp ah, 55h
	jne fraud_call
	;; Check the carry flag
	popf
	jc  kernel_panic
fraud_call:	
	;; At this point we can guarantee that this is a fraudulent panic call. Just do an IRET now
	;; with the carry flag set.
	stc
	iret
main_func_check:
	;; Check for a non-panic call.
	cmp ah, 00h
	je  install_check	; Our install check routine for boot time
	cmp ah, 01h
	je  print_string	; Our print string function
	cmp ah, 02h
	je  open_file		; Open file function
	cmp ah, 03h
	je  close_file		; Close file function
	cmp ah, 04h
	je  nos_version 	; Returns tho NOS version
	;; Skip 0x05 for now, created 0x06 with no 0x05! so I will have to think up a
	;; function to fill this hole.
	cmp ah, 06h
	je  get_user_string	; Our getstring function
	;; If none of these match, pop our flags, set carry, and return
	popf
	stc
	iret
install_check:
	;; This is a simple install check function.
	;; Doesn't take any args, and just returns AX=0x5555
	popf			; Required of all functions, to keep stack clean
	mov ax, 5555h
	iret
print_string:
	;; Our own little PRINT function.
	;; Takes one arg in DX, which is the offset from DS that the string exists at.
	;; The string is a, well, string of bytes, each printed until the function sees a NULL,
	;; which is when he funcion quits.
	popf
	;; First save our registers.
	push ax
	; BH will be the number of chars that we write
	push cx
	push dx
	push si
	mov si, dx
	;; Now we need to start a loop where we print chars until we get to NULL.
	mov ah, 0Eh
	xor bx, bx		; If we have anything in BL the text will show up in random colors
	mov cx, 0001h
print_loop:
	;; get the char in DS:DX and increment the loop.
	mov al, byte ptr ds:si
	inc si
	;; Check for a null or a newline (carriage return)
	cmp al, 00h
	je  print_done
	cmp al, 0Dh
	je  print_newline
	;; Otherwise, print the character
	int 10h
	inc bh		; Printed a char
	jmp print_loop
print_done:
	pop si
	pop dx
	pop cx
	pop ax
	;; We are done here.
	iret
print_newline:
	;; We need to service a 0x0D (carriage return).
	pusha			; Save EVERYTHING
	mov ah, 03h
	int 10h 		; get the current cursor pos
	mov ah, 02h
	mov dh, 00h
	inc dl			; Change the row and column values
	int 10h
	popa
	inc bh		; Printed a char
	jmp print_loop
open_file:
	; Empty for the sake of a test build
	popf
	iret
close_file:
	; Empty for the sake of a test build
	popf
	iret
get_user_string:
	; Empty for the sake of a test build
	popf
	iret
nos_version:
	popf
	mov cx, "20"
	iret
kernel_panic:
	; Halt
	cli
	hlt
	jmp kernel_panic
times 512-($-$$) db 00h