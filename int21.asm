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
	;;	   contents. Returns nothing on no error, if an error occurs then CF is set and BH describes 
	;;     the error. If CF is set on entry, then will save as executable and will look for EOF marks
	;;     ("EF", 0xFF for flat; "ES", 0xFF for segmented)
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
	mov byte ptr exec_check, 00h
	; Check to see if we are loading an executable file
	mov ah, byte [esp+4]
	and ah, 1
	cmp ah, 1
	; If so set the exec flag
	jne start_open_file
	mov byte ptr exec_check, 80h
	; clear carry
	clc
	and byte [esp+4], -2
start_open_file:
	push es
	push bx
	; Place the address to load up to in RAM
	mov word ptr cs:loadto_off, bx
	push es
	pop bx
	mov word ptr cs:loadto_seg, bx
	pop bx
	pop es
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
	; DI is pointer to filename char
	xor di, di
	mov di, filename
open_filename_loop:
	mov al, byte ptr ds:si
	; Check for null
	cmp al, 00h
	je  done_open_filename_loop
	mov [cs:di], al
	inc di
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
	; If there is a null here, then we are in empty spce of the FSB.
	; Exit just in case.
	cmp ah, 00h
	je  disk_error
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
	; Check if the file we are looking for is an executable file
	cmp byte ptr exec_check, 80h
	je  check_for_exec
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
	; Get the address
	mov bx, word ptr cs:loadto_seg
	mov es, bx
	mov bx, word ptr cs:loadto_off
	mov ah, 02h
	int 13h
	jc  disk_error
	; Move the blocks into AL
	mov al, byte ptr cs:blocks
	; Return filesystem string to expected values
	mov cx, 08d
	mov bx, filename
clear_data_loop_open:
	mov si, cx
	mov byte ptr cs:bx+si, 00h
	loop clear_data_loop_open
	; We are finished, quit
	iret
not_right_file:
	; Somewhere in the filename. Go back to the beginning of the field
	dec bx
	mov ah, byte ptr es:bx
	cmp ah, 80h
	jne not_right_file
	; Back to 0x80. Go to byte after 0xff
	add bx, 14d
	jmp find_files_loop
check_for_exec:
	; Pointing at the end of the file name
	; Point to the exec flag (13 bytes in)
	dec bx
	mov ah, byte ptr es:bx
	cmp ah, 80h
	jne check_for_exec
	add bx, 13d
	cmp byte ptr es:bx, 80h
	jne not_right_file
	; We have a correct file name.
	jmp go_back_to_80
open_file_data:
	filename db 00h,00h,00h,00h,00h,00h,00h,00h		; 8 bytes for file name
	blocks	 db 00h 					; For the number of blocks later
	loadto_seg dw 0000h					; For the segment to load the file to
	loadto_off dw 0000h					; For the offset to load the file to
	exec_check db 00h					; For the executable check flag
	scratch    db 00h					; For random stuff
	
close_file:
	popf
	; First thing first, update the FSB.
	pusha
	mov ah, 02h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 02h
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
	jc  disk_error_save
	popa
	; To begin saving a file, we need to see if we are saving an executable file or not.
	; If so, we need to check for a specific sequence of characters rather than just the
	; 0xFF EOF character to avoid truncating code.
	; File is in ES:BX, name in DS:DX
	jc  save_as_exec
	; Otherwise, we will save as a normal file.
	; First we need to see if the file exists. We will use the empty space in the INT21
	; segment for this purpose.
	push es
	push bx
	push cs
	pop es
	mov bx, out_in_space
	mov ah, 02h
	int 21h
	; If the file exists, then all we need to do is check the length of the file to see
	; if we need to allocate more space in the FSB for it.
	; If it doesn't, then we need to create a new FSB entry for it.
	jc  save_does_not_exist
	; It does exist. Check the length of the file here.
	mov cx, 0000h
	push bx
check_length:
	inc cx
	mov al, byte ptr es:bx
	cmp al, 0FFh
	je  done_check_length
	; Not done, so inc to next byte and check again
	inc bx
	jmp check_length
done_check_length:
	; Divide the number of bytes counted by 512 to get the total number of blocks
	push dx
	mov ax, cx
	mov cx, 0200h					; 512 decimal
	div cx
	; Check to see if there is a remainder, and if so then add a block to the result
	cmp dx, 0000h
	je  get_field_save
	inc ax
	; Save the count in CX
	mov cx, ax
get_field_save:
	; Now we need to find the file field for the file and check to see if we need to
	; allocate more space.
	pop dx
	push es
	push bx
	mov bx, 2000h
	mov es, bx
	mov bx, 0008h
look_for_file_save:
	mov ah, byte ptr es:bx
	cmp ah, 80h
	je  found_field_save
	pop dx
	pop si
	cmp ah, 00h
	je  disk_error_save
	push si
	push dx
	inc bx
	jmp look_for_file_save
found_field_save:
	; Check to see if it is indeed our file.
	; Pointing at 0x80
	push bx
	add bx, 05d
	mov si, dx
	push si
compare_filename_save:
	mov ah, byte ptr es:bx
	cmp ah, byte ptr ds:si
	jne not_right_file_save
	; Check for the end of the filename
	cmp ah, 00h
	je  found_file_save
	; Otherwise keep going
	inc bx
	inc si
	jmp compare_filename_save
not_right_file_save:
	pop si
	; Go back to the 0x80
	pop bx
	; Now to the next field
	add bx, 14d
	jmp look_for_file_save
found_file_save:
	; We have our file. Go back to the 0x80 and look at the length in blocks.
	pop si
	pop bx
	add bx, 04d				; Pointing at length
	mov ah, cl				; FSB limitation: can't save more than 255 blocks at once
	mov al, byte ptr es:bx
	cmp ah, al
	jg  allocate_more_space_save
	; If we have something that is less than the curently allocated space, we will leave it there just to
	; keep things simple
	jmp save_file
allocate_more_space_save:
	; Currently not implemented
	pop ax
	pop ax
	mov ah, 01h
	push ds
	push cs
	pop ds
	mov dx, allocate_ns
	int 21h
	pop ds
	iret
	allocate_ns db "WARN: Extra space allocation is currently not implemented in INT21!", 0Dh, 0Ah, 00h
save_file:
	; We have length in cl, move it to al
	mov al, cl
	mov ah, 03h
	; Get the CHS information
	sub bx, 03h
	mov ch, byte ptr es:bx
	inc bx
	mov dh, byte ptr es:bx
	inc bx
	mov cl, byte ptr es:bx
	pop bx
	pop es
	; Get boot drive from kernel
	push ds
	push si
	mov si, 1000h
	mov ds, si
	mov dl, byte ptr 0003h
	pop si
	pop ds
	int 13h
	jc  disk_error_save
	; We are successful! Return here.
	iret
save_as_exec:
	; Currently not implemented
	mov ah, 01h
	push cs
	pop ds
	mov dx, save_as_exec_ns
	int 21h
	iret
	save_as_exec_ns db "WARN: Saving as executable currently not implemented!", 0Dh, 0Ah, 00h
disk_error_save:
	or byte [esp+4], 1
	iret
save_does_not_exist:
	; First, we need to find the last used sector on the disk.
	; We will do this by incrementing through the FSB fields until we
	; find something that is the last physical file on the disk. We will
	; then save the file there.
	push ds
	push es
	push bx
	push cs
	pop ds
	mov bx, 2000h
	mov es, bx
	mov bx, 0008h
last_file_loop:
	; Find a 0x80
	mov ah, byte ptr es:bx
	; If we have a null, we are out in spcae after the file fields
	cmp ah, 00h
	je done_last_file
	; If we have a 0x80, then we need to go on out to the CHS and figure out
	; if it is further out on the disk than the last recorded value
	cmp ah, 80h
	je  found_field_last
	; Otherwise increment and continue looking
	inc bx
	jmp last_file_loop
found_field_last:
	; First thing to look at is the cylinder (track) value.
	; Pointing at 0x80
	inc bx
	mov si, 0000h
	mov ah, byte ptr es:bx
	mov al, byte ptr last_file_chs
	cmp ah, al
	; If they are equal then move on to the head value, otherwise we should
	; check to see if it is greater. If so, then this file is further out than
	; our current recorded value.
	je  check_field_head
	; If less than then this file is further inward, so ignore
	jl  not_outward_save
	; It is greater than. Value for C is in AH.
	mov byte ptr last_file_chs, ah
	inc si
	inc bx
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	inc si
	inc bx
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	xor si, si
	; Now we need to go to the end of the field and keep looking.
	add bx, 10d
	jmp last_file_loop
check_field_head:
	; Pointing at the cylinder value
	inc bx
	inc si
	mov ah, byte ptr es:bx
	mov al, byte [last_file_chs+si]
	cmp ah, al
	je  check_field_sector
	jl  not_outward_save
	; Otherwise, decrement and move the values in
	dec bx
	dec si
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	inc si
	inc bx
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	inc si
	inc bx
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	inc si
	inc bx
	add bx, 10d
	jmp last_file_loop
check_field_sector:
	inc bx
	inc si
	mov ah, byte ptr es:bx
	mov al, byte [last_file_chs+si]
	cmp ah, al
	jl  not_outward_save
	; IF they are equal then there is an error somewhere in the form of a duplicate
	; file field.
	je  disk_error_save
	sub bx, 02d
	sub si, 02d
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	inc si
	inc bx
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	inc si
	inc bx
	mov ah, byte ptr es:bx
	mov byte [last_file_chs+si], ah
	inc si
	inc bx
	add bx, 10d
	jmp last_file_loop
not_outward_save:
	; If we are here then this field is closer to the beginning of the disk.
	; We need to go to the end of the field.
	dec bx
	mov ah, byte ptr es:bx
	cmp ah, 80h
	jne not_outward_save
	add bx, 14d
	; Now back to the top of the loop
	jmp last_file_loop
done_last_file:
	; What we have now is the last file on disk's CHS stored in RAM.
	; We need to save the file one sector after this one.
	;; NOTE: FOR NOW WE WILL ASSUME THE BOOT DISK IS A FLOPPY. I AM AWARE THAT THIS IS NOT A GOOD PRACTICE.
	;;       PROPER HARD DISK SUPPORT WILL BE IMPLEMENTED AT A LATER DATE.
	pop bx
	pop es
	; To increment the value, we need to check to make sure that the CHS values stay within their limits.
	mov si, 0003d
	cmp byte [last_file_chs+si], 18d
	; If so then we need to carry. Otherwise, we can just increment the sector value and be fine.
	je  carry_chs_save
	inc byte [last_file_chs+si]
	; Now we need to start working on creating the file field.
	jmp create_new_field
carry_chs_save:
	; We need to carry the sector value over, so reset it to zero and add one to the head value. If needed, we
	; also can carry that, and if we overflow we need to display a "disk full" message to the user.
	mov byte [last_file_chs+si], 00h
	dec si
	cmp byte [last_file_chs+si], 01d
	je  carry_over_head
	; Otherwise, increment the head and move right along
	inc byte [last_file_chs+si]
	jmp create_new_field
carry_over_head:
	mov byte [last_file_chs+si], 00h
	dec si
	cmp byte [last_file_chs+si], 79d
	je disk_full
	inc byte [last_file_chs+si]
	jmp create_new_field
disk_full:
	mov ah, 01h
	mov dx, disk_full_msg
	int 21h
	pop ds
	jmp disk_error_save
	disk_full_msg db "ERR: Attempted to save to a disk that has no space for the file.", 0Dh, 0Ah, 00h
create_new_field:
	
	
	last_file_chs db 00h,00h,00h
	
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
	mov ah, 0Eh
	int 10h
	jmp get_char_loop
get_string_done:
	; Place our NULL, print a return, and exit
	mov byte [ds:si], 00h
	xor si, si
	push ax
	push bx
	mov ah, 0Eh
	mov al, 0Dh
	mov bh, 00h
	int 10h
	mov al, 0Ah
	int 10h
	pop bx
	pop ax
	iret
nos_version:
	popf
	mov cx, "B3"
	mov al, "0"
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
out_in_space:

times 1024-($-$$) db 00h
