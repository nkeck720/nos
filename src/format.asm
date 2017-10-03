;
; FORMAT.ASM - This serves as a program to format disks under NOS to NOSFS.
;

; Begin with the flat header
db "F"
jmp start
message db "NOS format program 1.0", 0Dh, 0Ah, 00h
prompt	db "Insert a high density disk to format and press RETURN", 0Dh, 0Ah, 00h
formatting db "Formatting...", 0Dh, 0Ah, 00h
writing db "Writing NOSFS...", 0Dh, 0Ah, 00h
disk_prompt db "Press 'Y' to format hard disk instead: ", 0Dh, 0Ah, 00h
hd_chs db 00h, 00h, 00h
current_cyl db 00h
current_head db 00h
chs_fname db "CHS", 00h, "    "
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
; Ask if the user wants to format the hard disk instead
mov ah, 01h
mov dx, disk_prompt
int 21h
mov ah, 00h
int 16h
cmp al, 'y'
je  hd_format
cmp al, 'Y'
je  hd_format
; Now prompt the user to insert the HD disk to format
mov ah, 01h
mov dx, prompt
int 21h
mov ah, 06h
mov dx, garbage
int 21h
; Write garbage to the disk, to make sure all data is gone
mov ah, 01h
mov dx, formatting
int 21h
mov bx, 1000h
mov ds, bx
mov cx, 80d		; For 80 tracks
format_loop:
push cx
mov ah, 03h
mov al, 18d		; 18 Sectors per track in an HD floppy
pop cx
push cx
mov ch, cl
mov cl, 01h
mov dh, 00h
mov dl, byte ptr ds:0003h
int 13h
mov ah, 03h
mov al, 18d		
pop cx
push cx
mov ch, cl
mov cl, 01h
mov dh, 01h
mov dl, byte ptr ds:0003h
int 13h
pop cx
loop format_loop
push cs
pop ds
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

hd_format:
; Get the CHS information of the disk via the BIOS
mov ah, 08h
mov dl, 80h
int 13h
mov byte [hd_chs], ch
mov byte [hd_chs+1], dh
mov byte [hd_chs+2], cl
; Begin the formatting process
mov ah, 01h
mov dx, formatting
int 21h
; Set up loop to run through all the cylinders, heads, sectors
hd_format_loop:
mov ah, 03h
mov al, byte [hd_chs+2]
and al, 00111111b
mov ch, byte ptr current_cyl
mov dh, byte ptr current_head
mov cl, byte [hd_chs+2]
and cl, 11000000b
push cs
pop es
mov bx, garbage
int 13h
; Check to see if the next cylinder is needed
mov ah, byte ptr current_head
cmp ah, byte [hd_chs+1]
je  next_cyl_hd
; Else increment pointer and continue
inc [current_head]
jmp hd_format_loop
next_cyl_hd:
; Check to see if done
mov ah, byte ptr current_cyl
cmp ah, byte ptr hd_chs
je  done_format_hd
; Else increment and continue
inc [current_cyl]
mov byte ptr current_head, 00h
jmp hd_format_loop
done_format_hd:
mov ah, 01h
mov dx, writing
int 21h
; Write the bootloader
mov ah, 03h
mov al, 01h
mov ch, 00h
mov dh, 00h
mov cl, 01h
mov dl, 80h
push ds
pop es
mov bx, bootload
int 13h
; Construct the filesystem like usual
mov si, fsb
add si, 3d
mov byte [ds:si], 0FFh
inc si
mov word [ds:si], 2877d
add si, 2d
mov word [ds:si], 2880d
add si, 2d
mov byte [ds:si], 80h
add si, 3d
mov byte [ds:si], 03h
inc si
mov byte [ds:si], 01h
inc si
mov cx, 8d
mov bx, chs_fname
fname_loop:
mov ah, byte [ds:bx]
mov byte [ds:si], ah
inc bx
inc si
loop fname_loop
inc si
mov byte [ds:si], 0FFh
; Write the FSB out to the disk
mov ah, 03h
mov al, 01h
mov ch, 00h
mov dh, 00h
mov cl, 02h
mov dl, 80h
push cs
pop es
mov bx, fsb
int 13h
; Write out the CHS file
mov ah, byte ptr hd_chs
mov byte ptr chs_file, ah
mov ah, byte [hd_chs+1]
mov byte [chs_file+1], ah
mov ah, byte [hd_chs+2]
mov byte [chs_file+2], ah
mov byte [chs_file+3], 0FFh
; Finished, exit
db 0CBh

bootload:
times 512 db 00h
fsb:
times 512 db 00h
chs_file:
times 4 db 00h
garbage:
db "EF",0FFh
times 2048-($-$$) db 0
