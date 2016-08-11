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
	; The first thing we need to do is look at the params passed to us.
	; ES:BX = address space to load file to
	; DS:DX = file name
	; And we return:
	; AL = number of sectors loaded (passed back to the "close_file" function to save
	; We will need to change DX to SI to start - cannot use DX for addressing
	; We will also use DI to keep track of the number of times we need to pop on an error
	push si
	mov si, dx
	push di
	inc di
	inc di
	; Save AX, BX, CX, DX because will use them later with INT 13
	push ax
	push bx
	push cx
	push dx
	inc di
	inc di
	inc di
	inc di
	; Check for the carry flag, signaling an exe
	popf		; From the beginning of the interrupt call
	jnc get_file_name
	mov [exe_flag_check], 80h
get_file_name:
	; We need to find the file name. Load up the file name so that we
	; can compare it later
	; We also cannot assume the FSB is current, user programs may not check. SO, update that now.
	; save ES:BX, we will use it later
	push es
	push bx
	inc di
	inc di
	mov ah, 02h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 02h
	; Get the boot drive from kernel space
	mov bx, 1000h
	mov es, bx
	mov dl, byte ptr es:0002h
	; Now set the address space for the FSB
	mov bx, 2000h
	mov es, bx
	mov bx, 0000h
	int 13h
	; On an error with anything, we need to return with CF set.
	jc open_file_error
	pop bx
	pop es
	dec di
	dec di
	; Get the actual file name.
	; Set up a loop to get the file name
	mov cx, 0008d
	mov ax, 0000h
	push bx
get_filename_loop:
	; Get the byte
	
	;; The following instruction needs more research. FASM refuses to assemble it,
	;; but it may be the only way to do this.
	; mov bl, [ds:dx+ax]

	; Save it

	;; And same with this instruction, it thinks I am using bh as a symbol.
	; mov byte [file_name+ax], bh
	
	inc ax
	loop get_filename_loop
	; Here we will need to check for the file name in the FS block.

open_file_success:
	or dword [esp+4], 0FFFFFFFDh
	iret
	; This will act as a data area for storing the file name/attributes
	file_name      db 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h     ; 8 bytes
	exe_flag_check db 00h					     ; signals whether we need to check for an executable
	times_to_pop   db 00h					     ; How many times to pop on an error
open_file_error:
	mov cx, di
c1:
	pop ax
	loop c1
	; Even though we may not have the expected registers when we return, the
	; carry flag is set to indicate error, and so appropriate action will need to be taken by the
	; program.
	or word [esp+4], 1
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
