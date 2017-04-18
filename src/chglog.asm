;
; CHGLOG.ASM - This program is an experimental command for NOS that will change the logged (or system) disk
; drive that the kernel and INT21 interfaces use.
;
org 0000h
use16
db "F"
jmp start
startup db "Logged Disk Changer v0.1", 0Dh, 0Ah, 00h
current db "Current active disk is: ", 00h
flop1	db "Floppy Disk 0", 0Dh, 0Ah, 00h
flop2 	db "Floppy Disk 1", 0Dh, 0Ah, 00h
hard	db "Hard Disk", 0Dh, 0Ah, 00h
prompt 	db "Pick disk to switch to, or enter 'C' to cancel (0,1,H): ", 00h
success db "Successfully changed disks.", 0Dh, 0Ah, 00h
failure db "Unable to change disks. Check drives and try again.", 0Dh, 0Ah, 00h
invalid db "Invalid selection, please try again.", 0Dh, 0Ah, 00h
same	db "You cannot change to the current drive!", 0Dh, 0Ah, 00h
cdisk	db 00h
ndisk   db 00h
newline db 0Dh, 0Ah, 00h
start:
	push cs
	pop ds
	mov ah, 01h
	mov dx, startup
	int 21h
	mov ah, 01h
	mov dx, current
	int 21h
	; Parse the current disk drive in the kernel
	mov bx, 1000h
	mov es, bx
	mov ah, byte ptr es:0003h
	; Save it
	mov byte ptr cdisk, ah
	cmp ah, 00h
	je  fdisk1
	cmp ah, 01h
	je  fdisk2
	; Otherwise, assume a hard disk
	jmp hdisk
fdisk1:
	mov ah, 01h
	mov dx, flop1
	int 21h
	jmp disk_switch
fdisk2:
	mov ah, 01h
	mov dx, flop2
	int 21h
	jmp disk_switch
hdisk:
	mov ah, 01h
	mov dx, hard
	int 21h
	jmp disk_switch
disk_switch:
	mov ah, 01h
	mov dx, prompt
	int 21h
	mov ah, 00h
	int 16h
	push ax
	mov ah, 0Eh
	int 10h
	; Check to see if we can read the disk
	mov ah, 01h
	mov dx, newline
	int 21h
	pop ax
	cmp al, 'C'
	je  exit
	cmp al, 'c'
	je  exit
	cmp al, '0'
	je  check_pri_flop
	cmp al, '1'
	je  check_sec_flop
	cmp al, 'H'
	je  check_hdd
	cmp al, 'h'
	je  check_hdd
	; Otherwise tell the user they selected an invalid disk
	mov ah, 01h
	mov dx, invalid
	int 21h
check_pri_flop:
	mov ah, 02h
	mov al, 01h
	mov cx, 0000h
	mov dh, 00h
	mov dl, 00h
	mov bx, garbage
	push cs
	pop es
	int 13h
	jc  disk_error
	mov byte ptr ndisk, 00h
	jmp switch
check_sec_flop:
	mov ah, 02h
	mov al, 01h
	mov cx, 0000h
	mov dh, 00h
	mov dl, 01h
	mov bx, garbage
	push cs
	pop es
	int 13h
	jc  disk_error
	mov byte ptr ndisk, 01h
	jmp switch
check_hdd:
	mov ah, 02h
	mov al, 01h
	mov cx, 0000h
	mov dh, 00h
	mov dl, 80h
	mov bx, garbage
	push cs
	pop es
	int 13h
	jc  disk_error
	mov byte ptr ndisk, 80h
	jmp switch
switch:
	; Load the FSB of the new disk and modify the kernel
	; drive pointer to match, and also check to see if the
	; disk we are loading is the same as the current one.
	mov ah, byte ptr cdisk
	cmp ah, byte ptr ndisk
	je  same_disk
	mov ah, 02h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 02h
	mov bx, 2000h
	mov es, bx
	mov bx, 0000h
	int 13h
	jc  disk_error
	mov ah, byte ptr ndisk
	mov bx, 1000h
	mov es, bx
	xor bx, bx
	mov byte ptr es:0003h, ah
	; Return to the kernel
	mov ah, 01h
	mov dx, success
	int 21h
	jmp exit
disk_error:
	mov ah, 01h
	mov dx, failure
	int 21h
	jmp exit
same_disk:
	mov ah, 01h
	mov dx, same
	int 21h
	jmp exit
	
exit:
	db 0CBh
db "EF", 0FFh
garbage:
times 1024-($-$$) db 0