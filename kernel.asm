	use16
disp_check:
	;; Set display mode
	mov ah, 00h
	mov al, 03h
	int 10h
	;; Check the disply for proper operation
	mov ah, 09h
	mov al, '#'
	mov cx, 0FFFFh
	int 10h
	mov ah, 86h
	mov cx, 000Fh
	mov dx, 4240h
	int 15h
	mov ah, 09h
	mov al, ' '
	mov cx, 0FFFFh
	int 10h
	xor ax, ax
	mov bx, ax
	mov cx, ax
	mov dx, ax
init_kernel:
	;; Display 'NOS 1.0.4' message
	mov ah, 0Eh
	mov al, 'N'
	int 10h
	mov al, 'O'
	int 10h
	mov al, 'S'
	int 10h
	mov al, 20h
	int 10h
	mov al, '1'
	int 10h
	mov al, '.'
	int 10h
	mov al, '0'
	int 10h
	mov al, '.'
	int 10h
	mov al, '4'
	int 10h
	call print_enter
	;; Here we want to overwrite the MBR code and use it for the stack.
	mov bx, 0000h
	mov es, bx
	mov bx, 7C00h
	call clear_mbr
	mov ax, 0000h
	mov ss, ax
	mov es, ax
	mov ax, 7C00h
	mov sp, ax
	xor ax, ax
	xor bx, bx
	;; Begin init of kernel (display prompt, prep mem, etc.)
	;; Begin by setting ES to 0000, and it will be used for program segments
	mov es, bx
	;; Display the prompt in a loop, for now not interpreting the commands
	;; using RAM locations 1000:1000-1000:10FF for command line entered
	mov bx, 1000h
	push cx
	mov cx, 1000h
	mov ds, cx
	pop cx
beep_init:
	;; Show that the kernel has been loaded by beeping the PC speaker
	mov cx, 1000d
	call startsound
	mov ah, 86h
	mov cx, 000Fh
	mov dx, 4240h
	int 15h
	call stopsound
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
	int 10h 		;Char is already in AL
	mov [ds:bx], al
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
startsound:			;Not my own software bit, got this function
				;edaboard.com
	;; CX=Frequency in Hertz. Destroys AX and DX.
	cmp cx, 014h
	jb  startsound_done	;Call stopsound
	in  al, 61h
	or  al, 003h
	dec ax
	out 061h, al		;Turn and gate on; turn timer off
	mov dx, 00012h		;High word of 1193180
	mov ax, 034DCh		;Low word of 1193180
	div cx
	mov dx, ax
	mov al, 0B6h
	pushf
	cli			;!!!
	out 043h, al
	mov al, dl
	out 042h, al
	mov al, dh
	out 042h, al
	popf
	in  al, 061h
	or  al, 003h
	out 61h, al
startsound_done:
	ret
stopsound:			;Destroys AL. Again, not my own code in this routine. From edaboard.com.
	in  al, 061h
	and al, 0FCh
	out 061h, al
	ret
print_enter:
	mov ah, 03h
	int 10h
	mov ah, 02h
	inc dh
	mov dl, 00h
	int 10h
	ret
;; Set to two blocks
times 1024-($-$$) db 0
