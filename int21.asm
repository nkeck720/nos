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
	or byte [esp+4], 1
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
	; Set carry
	or byte [esp+4], 1
	iret
install_check:
	;; This is a simple install check function.
	;; Doesn't take any args, and just returns AX=0x5555
	popf			; Required of all functions, to keep stack clean
	mov ax, 5555h
	iret
	; This code snippet is provided by SeproMan on the FASM board.
	; Thanks Sepro! :D
print_string:
	popf
	push ax 
	push cx 
	push si 
	mov ah, 0Eh ;BIOS teletype 
	mov bh, 0 ;Display page 0, don't care about BL in video mode 3 
	mov ch, 0 ;Count characters 
	mov si, dx ;DX can't be used to address memory!!! 
print_loop: 
	mov al, [ds:si] 
	inc si 
	cmp al, 0 
	je print_done 
	int 10h 
	inc ch ;Printed a char 
	jmp print_loop 
print_done: 
	mov bh, ch ;BH is be the number of chars that we wrote 
	pop si 
	pop cx 
	pop ax 
	iret
open_file:
	popf
	pusha
	; Load up the FSB
	mov ah, 02h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 02h
	; Get the boot drive from the kernel (4th byte in kernel space)
	push ds
	push ax
	mov ax, 1000h
	mov ds, ax
	pop ax
	mov dl, ptr ds:0003h
	pop ds
	mov bx, 2000h
	mov es, bx
	xor bx, bx
	int 13h
	jc  disk_error
	popa
	push es
	push bx
	; Read through DS:DX to find the filename
	mov si, dx
	; AH is pointer to filename char
	xor ah, ah
open_filename_loop:
	mov al, byte ptr ds:si
	; Check for null
	cmp al, 00h
	je  done_open_filename_loop
	; AH=pointer, AL=byte
	mov bx, filename    ; Address of filename, in data area below
	push bx
	push ax
	xor al, al
	mov al, ah
	xor ah, ah
	; AX=00<ptr byte>h
	add ax, bx
	mov bx, ax
	;BL=ptr byte
	pop ax
	mov byte ptr cs:bx, al
	mov ah, bl
	pop bx
	inc si
	jmp open_filename_loop
done_open_filename_loop:
	; Increment through the FSB starting at the file fields (8 bytes in)
	; File field format:
	; 0x80
	; C,H,S of file (3 bytes)
	; Number of blocks (1 byte)
	; Filename with 0x00 padding (8 bytes)
	; Executable flag (1 byte)
	; 0xFF
	mov bx, 2000h
	mov es, bx
	mov bx, 0007h
find_files_loop:
	; Check for a file
	mov ah, byte ptr es:bx
	cmp ah, 80h
	je  found_field
	inc bx
	jmp find_files_loop
disk_error:
	; Otherwise we are done here, and have not found our file.
	pop bx
	pop es
	or byte [esp+4], 1
	iret
found_field:
	; inc through the field to the filename (pointing at 0x80)
	inc bx
	inc bx
	inc bx
	inc bx
	inc bx
	mov si, filename
	; Compare the filenames
cmp_name_loop:
	mov ah, byte ptr es:bx
	mov al, byte ptr cs:si
	cmp ah, 00h
	je  check_end_filename
	cmp ah, al
	; If not equal then go to the end of the field and check for another one
	jne not_right_file
	; inc and check next char
	inc bx
	inc si
	jmp cmp_name_loop
check_end_filename:
	; Looking at the end of the file name. If they are the same then we have the correct file and we need
	; to load it up.
	cmp ah, al
	jne not_right_file
	; We have a correct filename. Load it up, point at beginning of file field.
go_back_to_80:
	dec bx
	mov ah, byte ptr es:bx
	cmp ah, 80h
	jne go_back_to_80
	; Get CHS info
	inc bx
	mov ch, byte ptr es:bx
	inc bx
	mov dh, byte ptr es:bx
	inc bx
	mov cl, byte ptr es:bx
	; Now the number of blocks
	inc bx
	mov al, byte ptr es:bx
	mov byte ptr cs:blocks, al
	push ds
	push ax
	mov ax, 1000h
	mov ds, ax
	pop ax
	mov dl, byte ptr ds:0003h
	pop ds
	pop es
	pop bx
	mov ah, 02h
	int 13h
	jc  disk_error
	; Move the blocks into AL and quit
	mov al, byte ptr cs:blocks
	iret
not_right_file:
	; Somewhere in the filename. Go back to the beginning of the field
	dec bx
	mov ah, byte ptr es:bx
	cmp ah, 80h
	jne not_right_file
	; Back to 0x80. Go to byte after 0xff
go_to_end:
	mov cx, 14d
	inc bx
	loop go_to_end
	; Go back to check loop
	jmp find_files_loop
open_file_data:
	filename db 00h,00h,00h,00h,00h,00h,00h,00h		; 8 bytes for file name
	blocks	 db 00h 					; For the number of blocks later
	
close_file:
	; Empty for the sake of a test build
	popf
	iret
get_user_string:
	popf
	; Args:
	; DS:DX - address to save string at
	mov si, dx
get_char_loop:
	; Start by getting a char
	mov ah, 00h
	int 16h
	; Check to see if AL is a CR
	cmp al, 0Dh
	je  get_string_done
	; Otherwise copy the char and begin again
	mov [ds:si], al
	inc si
	jmp get_char_loop
get_string_done:
	; Place our NULL and exit
	mov byte [ds:si], 00h
	xor si, si
	iret
nos_version:
	popf
	mov cx, "20"
	iret
kernel_panic:
	; Turn on all keylights and Halt
	mov dx, 60h 
	mov al, 0EDh 
	out dx, al
	mov ax, 00000111b  
	out dx, al
	cli
	hlt
	jmp kernel_panic
times 1024-($-$$) db 00h
