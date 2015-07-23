	use16
init_kernel:
	;; Here we want to overwrite the MBR code and use it for the stack.
	mov bx, 0000h
	mov es, bx
	mov bx, 7C00h
	call clear_mbr
	mov ax, 0000h
	mov ss, ax
	mov ax, 7C00h
	mov sp, ax
	xor bx, bx
	;; Begin init of kernel (display prompt, prep mem, etc.)
	;; Begin by setting ES to 0000, and it will be used for program segments
	mov es, bx
	;; Display the prompt in a loop, for now not interpreting the commands
	;; using RAM locations 1000:1000-1000:10FF for command line entered
	mov bx, 1000h
prompt_loop:
	mov ah, 0Eh
	mov al, 0Dh
	int 10h
	mov al, '>'
	int 10h
	mov al, 20h
	int 10h
	mov ah, 00h
	int 16h
	cmp al, 08h
	je  print_backspace
	cmp al, 0Dh
	jne prompt_2
	jmp interpret_cmd
prompt_2:	
	mov ah, 0Eh
	int 10h			;Char is already in AL
	mov cx, 1000h
	mov ds, cx
	mov [ds:bx], al
	mov cx, 0000h
	mov ah, 03h
	int 10h
	mov ah, 02h
	inc dl
	int 10h
	cmp bx, 10FFh
	jne prompt_3
	call interpret_cmd
prompt_3:
	inc bx
	jmp prompt_loop
clear_mbr:
	cmp bx, 7E00h
	jne clr_loop
	ret
clr_loop:
	mov dl, 00h
	mov [es:bx], dl
	inc bx
	jmp clear_mbr
interpret_cmd:
	mov ah, 0Eh
	mov al, 0Dh
	int 10h
	mov ah, 03h
	int 10h
	mov ah, 02h
	inc dl
	mov dh, 00h
	int 10h
	;; interpretation code goes here
	mov bx, 1000h
clear_loop:	
	;; reset the pointer and clear everything up to 1000:10FF
	cmp bx, 1100h
	jne clear_cmd
	jmp prompt_loop
clear_cmd:	
	mov bx, 1000h
	mov dl, 00h
	mov [ds:bx], dl
	inc bx
	jmp clear_loop
print_backspace:
	mov ah, 03h
	int 10h
	mov ah, 02h
	dec dl
	int 10h
	mov ah, 09h
	mov al, 20h
	int 10h
	jmp prompt_loop
;; Set to two blocks
times 1020-($-$$) db 0
