org 0000h
db "F"
; HFORMAT - formats a hard disk using NOSFS v2, placing boot files on the drive and the HD version of the bootsector.
; First jump past the data area
jmp start
intro db "NOS hard disk formatter/installer", 0Dh, 0Ah, 00h
version db "Installer version 1.0, kernel version string:", 0Dh, 0Ah, 00h
anykey db "Press any key to format, C to cancel...", 0Dh, 0Ah, 00h
formatting db "Formatting...", 0Dh, 0Ah, 00h
installing db "Installing NOS...", 0Dh, 0Ah, 00h
done db "Done! Remove disks and press a key to reboot...", 00h
max_blocks times 8 db 0
drive_params times 1Eh db 0

start:
; Start with the intro message and display kernel version
mov ah, 01h
mov dx, intro
int 21h
mov ah, 01h
mov dx, version
int 21h
; Point DX to the kernel offset where it has the version string
mov ah, 01h
mov dx, kern+8
int 21h
; See if the computer even supports disk extensions that NOSFS v2 requires
mov ah, 41h
mov dl, 80h		; For now the assumption is that the primary hard disk is the install destination, TODO: make routine to pick drive
mov bx, 55AAh
int 13h
jc  no_extensions
cmp bx, 0AA55h
jne no_extensions
; We have extensions, so now find the last block on the disk
mov ah, 48h
mov dl, 80h
mov si, drive_params
int 13h
mov cx, 8
get_blocks:
mov si, cx
mov ah, byte [drive_params+10h+si]
mov byte [max_blocks+si], ah

; Now

kern:
file 'kernel.bin'
api:
file 'int21.bin'
mbr:
file 'hdboot.bin'
db "EF", 0xFFh
whatever: