;
; FORMAT.ASM - This serves as a program to format disks under NOS to NOSFS.
;

; Begin with the flat header
db "F"
jmp start
message db "NOS format program 1.0", 0Dh, 0Ah, 00h
prompt	db "Insert a high density disk to format and press RETURN", 0Dh, 0Ah, 00h
formatting db "Formattting...", 0Dh, 0Ah, 00h
writing db "Writing NOSFS...", 0Dh, 0Ah, 00h
; Start by displaying a startup message
start:
mov ah, 01h
mov dx, message
int 21h
; load up the bootloader so we can place it on the disk
mov ah, 02h
mov al, 01h
mov cl, 01h
mov dh, 00h
mov ch, 00h
push ds
mov si, 1000h
mov ds, si
mov dl, byte ptr 0003h
pop ds
push cs
pop es
mov bx, bootload
int 13h
; Now prompt the user to insert the HD disk to format
mov ah, 01h
mov dx, prompt
int 21h
mov ah, 06h
mov dx, garbage
int 21h
; Now write out the bootloader
mov ah, 01h
mov dx, writing
int 21h
mov ah, 03h
mov al, 01h
mov cl, 01h
mov dh, 00h
mov ch, 00h
push ds
mov si, 1000h
mov ds, si
mov dl, byte ptr 0003h
pop ds
push cs
pop es
mov bx, bootload
int 13h
; Begin constructing the fsb now.
; We need to first write out the CHS for the kernel, which doesn't exist on
; a data disk.
mov si, 00h
mov byte [fsb+si], 00h
inc si
mov byte [fsb+si], 00h
inc si
mov byte [fsb+si], 00h
inc si
mov byte [fsb+si], 0FFh
; Write the number of free blocks (2880-boot-fsb=2878)
inc si
mov word [fsb+si], 2878d
add si, 02d
mov word [fsb+si], 2880d
; Now we need to add the footer
add si, 505d
mov byte [fsb+si], 0FFh
; Write the FSB
mov ah, 03h
mov al, 01h
mov ch, 00h
mov dh, 00h
mov cl, 02h
push ds
mov si, 1000h
mov ds, si
mov dl, byte ptr 0003h
pop ds
push cs
pop es
mov bx, fsb
int 13h
; We have formatted the disk. Update the FSB and return now.
mov ah, 02h
mov al, 01h
mov ch, 00h
mov dh, 00h
mov cl, 02h
push ds
mov si, 1000h
mov ds, si
mov dl, byte ptr 0003h
pop ds
mov bx, 2000h
mov es, bx
mov bx, 0000h
int 13h
db 0CBh

bootload:
times 512 db 00h
fsb:
times 512 db 00h
garbage:
db "EF",0FFh
times 1536-($-$$) db 0