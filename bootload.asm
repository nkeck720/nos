use16
;
; This is the bootsector for NOS.
; this code should not have to chnge unless the FSB layout changes or it happens that
; this code needs to be optimized.
;
org 7C00h	
mov ax, 9c00h
mov ss, ax
mov sp, 4096d
mov ax, 0000h
mov ds, ax
push dx ; Save the boot drive
mov ah, 00h
mov al, 03h
int 10h
mov ah, 02h
mov dx, 0000h	
int 10h
;----------------------------------------	
loadup:
	mov ah, 00h
	mov dl, 00h
	int 13h
	jc  reset_err
	;; Clear the screen
	mov ah, 00h
	mov al, 03h
	int 10h

kernel_load:
	;; Load the filesystem into RAM
	mov ah, 02h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 02h
	; DL should be the boot drive
	mov bx, 2000h
	mov es, bx
	mov bx, 0000h
	int 13h
	jc  int13_err
	;; Read kernel CHS and length from RAM
	mov ch, [es:bx]
	inc bx
	mov dh, [es:bx]
	inc bx
	mov cl, [es:bx]
	inc bx
	mov al, [es:bx]
	cmp al, 0FFh
	je  non_sys_disk
	mov ah, 02h
	mov dl, 00h
	mov bx, 1000h
	mov es, bx
	mov bx, 0000h
	int 13h
	jc  int13_err
	;; jump to the kernel
	jmp 1000h:0000h
stop:
	cli
	hlt
	jmp stop
non_sys_disk:
	;; A non-system disk is being booted from
	mov ah, 0Eh
	mov al, 'F'
	int 10h
	mov al, 'S'
	int 10h
	mov al, 'B'
	int 10h
	mov al, 20h
	int 10h
	mov al, 'E'
	int 10h
	mov al, 'R'
	int 10h
	int 10h 		;Char should still be in AL
	jmp stop
int13_err:
	mov ah, 0Eh
	mov al, 'I'
	int 10h
	mov al, '1'
	int 10h
	mov al, '3'
	int 10h
	mov al, 20h
	int 10h
	mov al, 'E'
	int 10h
	mov al, 'R'
	int 10h
	int 10h 		;Again, char should still be in AL
	jmp stop
reset_err:
	mov ah, 0Eh
	mov al, 'R'
	int 10h
	mov al, 'S'
	int 10h
	mov al, 'T'
	int 10h
	mov al, 20h
	int 10h
	mov al, 'E'
	int 10h
	mov al, 'R'
	int 10h
	int 10h

;---------------------------------------- 
; Fit this in the MBR and add boot signature
times 510-($-$$) db 0
dw 0xAA55
