use16
org 7C00h	
mov ax, 9ch
mov ss, ax
mov sp, 4096d
mov ax, 7C0h
mov ds, ax	
mov ah, 02h
mov dx, 0000h
int 10h
;----------------------------------------
loadup:

	mov ah, 00h
	mov dl, 00h
	int 13h
	mov ah, 01h
	mov dl, 00h
	int 13h
	cmp ah, 00h
	jne stop
	;; Load the int 21h code (for future implementation)
	mov ah, 02h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 01h
	mov dl, 00h
	mov bx, 1400h
	mov es, bx
	mov bx, 0000h
	int 13h
	mov ah, 01h
	mov dl, 00h
	int 13h
	cmp ah, 00h
	jne stop
	;; Set up the IVT to recognize my int 21h
	cli
	mov ax, 0000h
	mov es, ax
	mov al, 21h
	mov bl, 04h
	mul bl
	add ax, 02h
	mov bx, ax
	mov dx, 1400h
	mov [es:bx], dx
	mov al, 21h
	mov bl, 04h
	mul bl
	mov bx, ax
	mov dx, 0000h
	mov [es:bx], dx
	sti
	;; Clear the screen
	mov ah, 00h
	mov al, 03h
	int 10h
	;; Display 'NOS 1.0.1' message
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
	mov al, '2'
	int 10h
	;; Begin setting up the environment in which the user will type
	mov bl, 07h
typer:
	cmp dl, 80d
	je  print_enter
	mov ah, 00h
	int 16h
	cmp al, 0Dh
	je  print_enter
	cmp al, 08h
	je  print_back
	mov ah, 09h
	int 10h
	mov ah, 0Eh
	int 10h
	jmp typer
print_enter:
	cmp dh, 25d
	je  mcdn
	mov ah, 02h
	inc dh
	mov dl, 00h
	int 10h
	jmp typer
print_back:
	mov ah, 02h
	dec dl
	int 10h
	mov ah, 09h
	mov al, 20h
	int 10h
	jmp typer
mcdn:
	mov ah, 07h
	mov al, 01h
	int 10h
	mov ah, 02h
	inc dh
	mov dl, 00h
	int 10h
	jmp typer
stop:
hlt
;----------------------------------------
times 510-($-$$) db 0
dw 0xAA55
