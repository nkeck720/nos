	use16
	;
	; This is the kernel for the NOS operating system.
	;
	; Upon entry, this kernel assumes the following:
	; 0000:7C00-0000:7E00	  '	  '   Bootloader
	; 1000:0000		  '	  '   Kernel beginning location
	; DS=0000, CS=1000 (this MUST be true), ES=0000, SS=9C00 (SP=4096d)
	;
	; The kernel memory model looks something like this:
	;
	; 0000:7E00-0000:7C00	  '	  '   Stack
	; 2000:0000	   '	  '	  '   FSB (filesystem block) NOTE: THIS IS ASSUMED LOADED BY THE BOOTLOADER ON STARTUP!
	; 3000:0000	   '	  '	  '   TSR driver space
	; 4000:0000	   '	  '	  '   User program code segment
	; 5000:0000	   '	  '	  '   Data for user programs  -|
	; 6000:0000	   '	  '	  '   Extra for user programs  |--- With the exception of stack, these are not used in flat mode.
	; 7000:0000	   '	  '	  '   Stack for user programs -|
	; 8000:0000	   '	  '	  '   Kernel API space
	; HMA		   '	  '	  '   Command line space
	;
	; And as such we now begin our code...
	; We want to create a sort of data area first, so here we jump over that.
	jmp start
	; We now begin our data area.
	boot_drv db 00h 						    ; For saving tho boot drive
	old_ss dw 0000h 						    ; For saving our old SS locations.
	old_sp dw 0000h 						    ; Same for old SP.
	version db "NOS Beta 1 -- built from Git repository", 0Dh, 00h ; Version string
	bootmsg db "Booting up...", 0Dh, 0Ah, 00h				    ; Boot message
	drv_fname db "DRVS", 00h					    ; Driver list file name
	blank_line db 0Dh, 0Ah, 00h						    ; A blank line on the screen
	prompt db "NOS> ", 00h						    ; Command prompt
	bad_command db "That command doesn't exist, or cannot be found.", 0Dh, 0Ah, 00h 	    ; Bad command message
	ret_opcode equ 0CBh						    ; A RET is a single-byte instruction, so we store it here for later
	old_dx dw 0000h 						    ; For loading segmented stuff
	missing_drvs db "No DRVS file present, skipping", 0Dh, 0Ah, 00h
	message db "Listing of boot disk:", 0Dh, 0Ah, 00h
	no_name_type db "No filename given, abort.", 0Dh, 0Ah, 00h
	error_load_type db "Could not find file, abort.", 0Dh, 0Ah, 00h
start:
	pop dx			; Get our boot drive
	push cs
	push cs
	pop  ds
	pop  es
	mov [boot_drv], dl	; Save it (INT 21 funcs will look at boot_drv)
	pusha
	call a20_line_ena	; Enable A20 for using the HMA later in command line space.
	popa
	; The moment of truth.
	; Now we clear out our bootloader, and set it to the stack.
	mov cx, 0200h	   ; The size of one sector
	mov bx, 7C00h	   ; The beginning location of our bootloader
	mov dx, 0000h	   ; FASM says we have to do it this way...
	mov es, dx
mbr_clear:
	xor ah, ah
	inc bx
	mov [es:bx], ah
	loop mbr_clear
	; We should now have the MBR area clean, set the stack up.
	mov ax, 0000h		; Later in the kernel, we will do checks to see if the SP reaches 7C00 and if 
	mov ss, ax		; it does we will reset the pointer to 7E00 to ensure the 512-byte limit.
	mov sp, 7E00h		; This is in response to http://board.flatassembler.net/topic.php?p=184920#184920
	; Now that we have the stack, do a push-pop test
	mov ax, 55AAh
	push ax
	pop bx
	cmp ax, bx
	; If they don't equal, something is wrong
	jne system_error_preapi
	; Now we need to get the API into RAM. This will be stored in a file called INT21,
	; and will be non-executable.
get_api:
	; Get the file, by loading the FSB entry
	mov bx, 2000h
	mov es, bx
	mov bx, 0000h
	mov si, 0008d		;Changed as suggested by SeproMan
	; The program, as stated, assumes the FSB is set on startup.
	; INT21 is always the first file entry on the disk. If it isn't, then
	; we will have to abort the boot.
	; Get the first bytes of the file field.
	mov ah, [es:bx+si]
	cmp ah, 80h
	jne api_load_error
	inc si	; To location of CHS
	; Get each value and push them.
	xor al, al
	mov ah, [es:bx+si]
	push ax
	inc si
	mov ah, [es:bx+si]
	push ax
	inc si
	mov ah, [es:bx+si]
	push ax
	inc si
	; Get the "number of sectors" byte
	mov ah, [es:bx+si]
	push ax
	inc si
	; Now we need to make sure file name is valid.
	; Get each byte and compare it.
	; First we need to get the INT21 bytes...
	mov cx, 0005d
	mov si, 0017d		; So we get the correct values from the FSB
c1:	
	mov ah, [es:bx+si]
	push ax
	dec si
	loop c1
	xor bx, bx
	mov si, bx
	mov es, bx
	; Now we need to compare each one.
	pop ax
	cmp ah, "I"
	jne api_load_error
	pop ax
	cmp ah, "N"
	jne api_load_error
	pop ax
	cmp ah, "T"
	jne api_load_error
	pop ax
	cmp ah, "2"
	jne api_load_error
	pop ax
	cmp ah, "1"
	jne api_load_error
	; Our file is valid. Stack is now as follows:
	; [top]
	; Number of sectors
	; Sector value
	; Head value
	; Cylinder value
	; [unknown values until bottom]
	; So here we set up values to load from disk.
	; Since we can only pop words off the stack, we need to use
	; DX as a gen purpose register here.
	xor dx, dx
	pop dx		; Number of sectors
	mov al, dh
	pop dx
	mov cl, dh	; Sector
	pop dx		; Head, which goes in DH. We will need to back this up in SI.
	mov si, dx
	pop dx
	mov ch, dh	; Cylinder
	mov dx, si
	xor si, si
	mov dl, [boot_drv]  ; Our boot drive
	mov ah, 02h	; Read sectors
	; And now, a brief word from INT 13h...
	mov bx, 8000h
	mov es, bx
	mov bx, 0000h
	int 13h
	jc  api_load_error
	; Our Kernel API is now loaded, so we need to set our IVT values.
	xor ax, ax
	xor bx, bx
	xor cx, cx
	xor dx, dx
	mov es, bx
	mov ax, 8000h
	mov bx, 0000h	; Just to make sure
	mov es, bx		; Make sure ES is set to 0000
	cli		; Moved this down here as suggested by SeproMan
	mov word [es:21h*4], bx
	mov word [es:21h*4+2], ax
	sti
	; Kernel API is now active!
	; We need to be sure that INT 21 works. Function 00 is an install
	; check, and so we will call it with that value.
	mov ah, 00h
	int 21h
	; If AX=5555h, we are done here.
	cmp ax, 5555h
	jne api_load_error
	;; Now here, we want to display a version string and a loading message.
	;; Print string is function 0x01.
	mov ah, 01h
	mov dx, version
	int 21h
	mov ah, 01h		; Never assume that the register will stay the same.
	mov dx, bootmsg
	int 21h
	;; Number of chars written is put in BH, but we don't care about that.
	xor bh, bh
	;; We need our driver list loaded. It will be stored in a file named
	;; DRVS.
	;; File load function is 0x02. File write is 0x03.
	mov ah, 02h
	xor al, al		; Just in case
	mov dx, drv_fname	; Name of file (DS should be set to the same as CS)
	mov bx, 6000h		; Yes, this is the same as program ES. ES will later be cleared.
	mov es, bx
	mov bx, 0000h
	int 21h
	;; First check for an error, and if so handle it appropriately
	;; IF there is no DRVS file, simply skip over this bit
	jc  drv_nofile
	;; Now we need to parse the data. Formatting is as shown:
	;; 0x55FF00AA #<filename1>* #<filename2>* ... 0x0D
	;; This is all in one big string, the CR is the EOF mark (spaces not in file).
	;; When scanning for filenames, anything not enclosed in #* is ignored.
	;; In other files, an EOF is marked by 0xFF.
	;; So get DS to be our file, saving the old DS
	push ds
	push es
	pop ds
	;; Stack
	;; <top>
	;; | Original DS
	;; <end>
	mov ax, word ptr 0000h		;Get the first word
	mov bx, word ptr 0002h		;And the second one
	cmp ax, 00AAh
	;; If we have a bad file, we want to skip over it like it doesn't exist to
	;; avoid errors.
	jne drv_file_done
	cmp bx, 55FFh
	jne drv_file_done
	;; Now we will get the individual filenames.
	mov si, 0004h		;start the pointer at the byte after the header.
	xor bh, bh		;for filename processing
get_dem_filenames:
	push es 		;So we can recover later 
	push si 
	;; Scan until we get a hash
	mov ah, byte ptr ds:si
	cmp ah, "#"
	je  we_got_one
	;; So this one isn't a hash. See if it is our EOF.
	cmp ah, 0Dh
	je  drv_file_done
	;; It isn't either one, so we increment the pointer and try again.
	inc si
	jmp get_dem_filenames
we_got_one:
	;; We found a hash, we need to get each char until we get a closing asterisk.
	inc si
	mov ah, byte ptr ds:si
	cmp ah, "*"
	je  store_filename
	;; We don't have our closing mark yet, so store the char
	push ax 		;When we pop these off, we will ONLY be using the byte in AH
	inc bh
	jmp we_got_one
store_filename:
	;; So we have a mess on the stack:
	;; <top>
	;; | Filename (number of PUSHes done in BH)
	;; | Original DS
	;; <end>
	;; We want to store this in DS starting at FFF0 (DRVS can't possibly be almost 64k long...)
	;; Start by popping crud off of the stack.
	mov bl, bh
	xor bh, bh
	mov cl, bl
	mov ch, 00h
	; Code snippet provided by SeproMan on the FASM board
	mov  [0FFF0h+bx], ch	;CH=0
pop_off_loop:
	dec bx
	pop ax
	mov [0FFF0h+bx], ah
	loop pop_off_loop
	;; We should have this now:
	;; <top>
	;; | Original DS
	;; <end>
	;; Now we need to place the 0x00 string terminator on the string.
	inc bh
	mov byte ptr 0FFF0h+bx, 00h
	;; And here we need to load the driver. This will load it into TSR space. Curently, only one driver
	;; may stay resident at a time until I work in some RAM tracking code.
	push es 		;So we can recover later
	push cx
	mov ah, 02h
	mov dx, 0FFF0h
	mov bx, 3000
	mov es, bx
	mov bx, 0000h
	int 21h
	;; Check for an error
	jc  disk_error
	;; Now check the driver, making sure that the noted architecture is flat (F)
	mov al, byte ptr es:bx
	cmp al, "F"
	; Instead of the previously suggested scream and run approach, we will simply tell the
	; user that there was a problem with the driver.
	jne drv_error
	;; The driver is OK. Here we will run the code, by calling it. To exit, a program/driver
	;; must "RET".
	call 3000h:0001h
	;; Check the return code to match a driver. Again, if this is not true then we need to run
	;; for our lives.
	cmp ch, 00h
	jne drv_error
	;; Check for a successful return code
	cmp cl, 00h
	;; If no success, then we could have an issue, so we need to run for it just in case.
	jne drv_error
	;; If we get here, we are successfully loaded.
	pop cx
	pop es
	pop  si 
	pop  es 
	inc  si 		;Skip asterisk 
	mov  bh, 0		;Reset counter 
	jmp  get_dem_filenames 
drv_file_done:
	;; When we get here we are done with our driver file. We need to unload DRVS (from RAM, no writing
	;; to disk is necessary since we didn't modify anything in the file.)
	;; Stack:
	;; <top>
	;; | Original DS
	;; <end>
	mov cx, 0000h
	xor bx, bx
unload_drv_list:
	mov si, cx		; For writing to RAM (thanks Sepro!)
	mov [ds:si], bh
	loop unload_drv_list	; Keep going until CX gets to 0
	;; Driver list unloaded, we can return to home sweet Original DS.
	pop ds
	; To make sure that ES holds 1000h, pointed out in Issue #22
	push bx
	mov bx, 1000h
	mov es, bx
	pop bx
	;; Now we can load up a basic CLI (Command line interface, not the cli instruction :D)
	;; Start by skipping a line just for visual effects
	mov ah, 01h		; Print function
	mov dx, blank_line
	int 21h
command_prompt: 
	;; We shall now display the prompt and a space, and invoke the get string function (0x06)
	;; Note that 0x06 places a null at the end of the line gotten automatically
	mov ah, 01h
	mov dx, prompt
	int 21h
	mov ah, 06h
	push ds ; Save original DS again
	push bx
	mov bx, 0FFFFh		; HMA
	mov ds, bx		; The command line space as shown in the memory model
	pop bx
	mov dx, 0010h
	int 21h
	;; Now, we switch back to the original DS and parse the command.
	;; For now, the only builtin we have is CLS.
	pop ds
	push es 		; Save ES
	mov bx, 0FFFFh
	mov es, bx
	mov bx, 0010h
	;; String compare function is under development, so for now we want to use
	;; the individual comparison.
	mov ah, byte ptr es:bx
	cmp ah, "t"
	je  check_type
	cmp ah, "d"
	je  check_dir
	cmp ah, "c"		
	jne external_command
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, "l"
	jne external_command
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, "s"
	jne external_command
	inc bx			; We still have to check for the end of the line
	mov ah, byte ptr es:bx
	cmp ah, 00h
	jne external_command
	;; We have a CLS command.
	pop es
	xor bx, bx
	;; CLS gets the current video mode and then sets it, clearing the screen.
	mov ah, 0Fh
	int 10h
	mov ah, 00h
	int 10h
	;; Now go back to the command prompt.
	jmp command_prompt
check_dir:
	; pointing at "d"
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, "i"
	jne external_command
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, "r"
	jne external_command
	; We have a dir command
	push cs
	pop ds
	mov ah, 01h
	mov dx, message
	int 21h
	; First thing is first: update the FSB.
	push es
	mov bx, 1000h
	mov ds, bx
	mov ah, 02h
	mov al, 01d
	mov ch, 00h
	mov cl, 02d		; CL=02 is the FSB
	mov dh, 00h
	mov dl, byte [boot_drv]
	mov bx, 2000h		; FSB segment
	mov es, bx
	mov bx, 0000h
	int 13h
	pop es
	push cs
	pop ds
	; Now we need to begin the process of listing out the files.
	; Start by pointing ES:BX at the first file field.
	mov bx, 2000h
	mov es, bx
	mov bx, 0007h
list_files_loop:
	; Now we loop until we find a null, indicating that we have entered empty space.
	; Find the file fields
	mov ah, byte ptr es:bx
	cmp ah, 80h
	je  get_file_name_dir
	; Otherwise, check for null
	cmp ah, 00h
	je done
	; Increment until we find a file
	inc bx
	jmp list_files_loop
get_file_name_dir:
	; The file name is exactly 5 bytes from the 0x80, add that on
	add bx, 05d
	; Now print out the file name on its own
	push dx
	push ds
	mov dx, bx
	push es
	pop ds
	mov ah, 01h
	int 21h
	mov ah, 0Eh
	mov al, 0Dh
	int 10h
	mov al, 0Ah
	int 10h
	pop ds
	pop dx
	; Now go to the end of the field
	sub bx, 05d
	add bx, 14d
	; Continue the loop
	jmp list_files_loop
done:
	; We are done here.
	jmp command_prompt
check_type:
	; Check for a type command
	; pointing at 't'
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, 'y'
	jne external_command
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, 'p'
	jne external_command
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, 'e'
	jne external_command
	; We do have a type command if we are here. Check if there is a filename
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, 00h
	je  no_filename_type
	; Check for a space, and if none then we might have an external command
	cmp ah, 20h
	je  type_file
	; If we are here, we probably have an external command
	jmp external_command
no_filename_type:
	mov ah, 01h
	mov dx, no_type_name
	int 21h
	jmp command_prompt
type_file:
	; Pointing at the space. Load up the file after the space
	inc bx
	push ds
	push dx
	push es
	pop ds
	mov dx, bx
	; Use the program extra to load up to
	mov bx, 6000h
	mov es, bx
	mov bx, 0000h
	mov ah, 02h
	int 21h
	jc  type_error
	push ds
	pop es
	pop dx
	pop ds
	; Now loop through the entire file
	; We don't need to address the command line anymore, so use
	; ES:BX to point to the file we loaded up
	; 0xFF is an EOF mark
	mov bx, 6000h
	mov es, bx
	mov bx, 0000h
type_file_loop:
	mov ah, 0Eh
	mov al, byte ptr es:bx
	cmp al, 0FFh
	je  done_type
	; otherwise, print the char and continue the loop
	mov bh, 00h
	int 10h
	inc bx
	jmp type_file_loop
done_type:
	; We are done here.
	jmp command_prompt
type_error:
	; Could not find the file or there was a disk error
	mov ah, 01h
	mov dx, error_load_tpye
	int 21h
	jmp command_prompt
external_command:
	;; We have a disk-based program to load, so here we want to load that
	;; and set up the memory model of the said file.
	;; First we want to make sure the FSB is up to date.
	push es
	mov ah, 02h
	mov al, 01d
	mov ch, 00h
	mov cl, 02d		; CL=02 is the FSB
	mov dh, 00h
	mov dl, [boot_drv]
	mov bx, 2000h		; FSB segment
	mov es, bx
	mov bx, 0000h
	int 13h
	;; If there is a disk error, we want to call up the handler
	jc  disk_error
	;; Restore ES
	pop es
	;; Load up the file specified, and signal for the check of executable file
	;; by setting carry on call
	push ds 	  ; Save this again
	mov ah, 02h
	mov dx, 0FFFFh
	mov ds, dx
	mov dx, 0010h
	;; set up ES:BX
	mov bx, 4000h
	mov es, bx
	mov bx, 0000h
	; Commenting this out for now, as it is not yet implemented.
	;stc		  ; STC indicates the loading of an executable file
	int 21h
	;; Check to make sure the file was loaded. If not, we don't have an executable file
	;; or the file was not found.
	jc  bad_prog_file
	;; Now check for a flat or segmented program
	pop ds			; We get this back now
	mov ah, byte ptr es:bx
	cmp ah, "F"
	je  run_flat_prog
	cmp ah, "S"
	je  run_segmented_prog
	;; Anything else and we have an invalid program.
	jmp bad_prog_file
bad_prog_file:
	;; If we get here the user has either entered a bad command, or there was a disk error.
	;; In any case we need to notify the user and return to a prompt.
	push cs
	pop ds
	; There is still a value to be popped, pop it and
	; leave no trace to clue as to whether or not it existed.
	pop ax
	xor ax, ax
	mov ah, 01h
	mov dx, bad_command
	int 21h
	jmp command_prompt
run_flat_prog:
	;; Here we wanna look at the flat structured file for a bit:
	;;
	;; A flat program file is structured like so:
	;;
	;; [begin file]
	;; "F" (0x46) indicates flat program
	;; [up to 64k-1 byte of code and data]
	;; "EF" (byte order 0x4546)
	;; 0xFF signature
	;;
	;; This structure needs to be tested. If we never find the "EF" or the 0xFF, then we
	;; have a bad program. We also need to make sure that the code fits one segment.

	;; First test for the EF thingy.
	mov bx, 0001h		; 64k-1 byte
test_flat_seg:
	mov ah, byte ptr es:bx
	cmp ah, "E"
	jne not_done_yet_flat
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, "F"
	jne not_done_yet_flat
	inc bx
	mov ah, byte ptr es:bx
	cmp ah, 0FFh
	jne not_done_yet_flat	; Just in case "EF" appears in the program/data.
	;; If we get here, we have a program footer
	;; so we want to start working on getting the code into the segment alone and
	;; calling it
	jmp remove_footer_flat
not_done_yet_flat:
	;; We aren't done, so we increment the pointer and try again
	;; UNLESS: if bx=0xFFFF here, or 0x0000 (from the inc "starting over"), we have a bad
	;; program because of a missing footer.
	cmp bx, 0FFFFh
	je  no_flat_footer
	cmp bx, 0000h
	je  no_flat_footer
	inc bx
	jmp test_flat_seg
remove_footer_flat:
	; All we need to do here is remove the footer from the code and run it.
	; Get the pointer at the start of the footer
	dec bx
	dec bx
	; We are now poining at the byte of the "E"
	; Place a RET here so that the program will return from execution safely
	mov byte ptr es:bx, ret_opcode
	inc bx
	; Now pointing at the "F"
	; save these two as NULLs
	mov byte ptr es:bx, 00h
	inc bx
	mov byte ptr es:bx, 00h
	; Now that we have stripped the file down to the code, call it at the starting address,
	; setting the stack segment before we do so.
	push ss
	pop ax
	mov [old_ss], ax
	mov ax, sp
	mov [old_sp], ax
	mov ax, 7000h
	mov ss, ax
	mov sp, 0FFFFh
	mov ax, 4000h
	;; Set up data segments
	mov ds, ax
	mov es, ax
	call 4000h:0001h
	; Reset our stack
	;; Also need to reset DS
	mov ax, 1000h
	mov ds, ax
	mov ss, word ptr old_ss
	mov sp, word ptr old_sp
	; When we return here, we clear out the segment
	; Set up a loop to do so
	mov cx, 0
	; ES is already set
clear_code_flat:
	mov bx, cx
	mov byte ptr es:bx, 00h
	loop clear_code_flat
	; Now return to the prompt.
	pop ds
	mov ax, [old_ss]
	mov bx, [old_sp]
	mov ss, ax
	mov sp, bx
	jmp command_prompt
no_flat_footer:
	; No footer was detected in the program.
	; Stop here, give a message, and clear out the seg.
	mov ah, 01h
	mov dx, bad_prog_file
	int 21h
	; Set things up to have expected values
	mov cx, 0
	push ss
	pop ax
	mov word ptr old_ss, ax
	mov word ptr old_sp, sp
	jmp clear_code_flat
run_segmented_prog:
	; This gets a bit complicated, due to the format of the segmented program:
	;
	; [begin file]
	; "S" to signal segmented program
	; "C" begins code segment (this must exist or the program is invalid)
	; Code
	; "EC" to signal done with code
	; "D" to signal data
	; Data
	; "ED"
	; "E" to signal extra
	; Extra segment stuff
	; "EE"
	; "ES" to signal end of file
	; [end file]
	
	; First off, we need to find segments.
	push ds
	mov dx, 4000h
	mov ds, dx
	mov dx, 0000h
find_segs_loop:
	; Increment through the program to find the code segment
	; Can't use DX to address memory. This is a simple hack to fix that
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	cmp ah, "C"
	je  move_code
	cmp ah, "D"
	je  move_data
	cmp ah, "E"
	je  check_for_end
	; Didn't find anything.
	inc dx
	jmp find_segs_loop
move_code:
	; Right now, we are pointed at the C, so increment and start loading.
	inc dx
move_code_loop:
	 ; Can't use DX to address memory. This is a simple hack to fix that
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	; check for EC
	cmp ah, "E"
	je  check_end_code
save_code:
	; We simply keep it in this segment, so just increment and check for end again.
	inc dx
	jmp move_code_loop
check_end_code:
	; Pointing at E
	inc dx
	 ; Can't use DX to address memory. This is a simple hack to fix that
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	cmp ah, "C"
	jne save_code
	; Done!
	push si
	dec dx
	mov si, dx
	mov byte ptr ds:si, 00h
	inc dx
	mov si, dx
	mov byte ptr ds:si, 00h
	pop si
	jmp find_segs_loop
move_data:
	; Pointing at D
	inc dx
move_data_loop:
	; Can't use DX to address memory. This is a simple hack to fix that
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	; check for ED
	cmp ah, "E"
	je  check_end_data
	; Here we need to move the data on over to 5000:0000
	push ds
	push dx
	mov dx, 5000h
	mov ds, dx
save_data:
	; We will save DX in RAM here
	push ds
	mov cx, 1000h
	mov ds, cx
	mov dx, [old_dx]
	pop ds
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	inc dx
	push ds
	mov cx, 1000h
	mov ds, cx
	mov [old_dx], dx
	pop ds
	pop dx
	pop ds
	pop ax
	jmp move_data_loop
check_end_data:
	; Pointing at E
	inc dx
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	cmp ah, "D"
	jne save_data
	; Done!
	push si
	dec dx
	mov si, dx
	mov byte ptr ds:si, 00h
	inc dx
	mov si, dx
	mov byte ptr ds:si, 00h
	pop si
	jmp find_segs_loop
check_for_end:
	; Looking for either extra or end here.
	; Pointing at E
	inc dx
	cmp ah, "S"
	jne check_for_extra
	; We are finished.
	pop ds
	; Load up the program segments
	push ss
	pop ax
	mov [old_ss], ax
	push sp
	pop ax
	mov [old_sp], ax
	mov dx, 5000h
	mov ds, dx
	mov bx, 6000h
	mov es, bx
	mov ax, 0FFFFh
	mov sp, ax
	mov ax, 7000h
	mov ss, ax
	xor ax, ax
	xor bx, bx
	xor cx, cx
	xor dx, dx
	; go to the program
	call 4000h:0001h
	; We have returned
	; Reset our stack
	; Also need to reset DS
	mov ax, 1000h
	mov ds, ax
	cli
	mov ax, word ptr old_ss
	mov ss, ax 
	mov ax, word ptr old_sp
	mov sp, ax
	sti
	; When we return here, we clear out the segments
	; Set up a loop to do so
	mov cx, 0
	xor ax, ax
	mov bx, 4000h
	mov es, bx
clear_code_seg:
	mov bx, cx
	mov byte ptr es:bx, ah
	loop clear_code_seg
	; Clear data
	mov cx, 0
	mov bx, 5000h
	mov es, bx
clear_data_seg:
	mov bx, cx
	mov byte ptr es:bx, ah
	loop clear_code_seg
	; Clear extra
	mov cx, 0
	mov bx, 6000h
	mov es, bx
clear_extra_seg:
	mov bx, cx
	mov byte ptr es:bx, ah
	loop clear_code_seg
check_for_extra:
	; Pointing at byte after E
	; We are sure this is extra
	; load it
	mov word ptr old_dx, 0000h
move_extra_loop:
	; Can't use DX to address memory. This is a simple hack to fix that
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	; check for EE
	cmp ah, "E"
	je  check_end_extra
	; Here we need to move the data on over to 6000:0000
	push ds 			;1
	push dx 			;2
	mov dx, 6000h
	mov ds, dx
save_extra:
	; We will save DX in RAM here
	push ds 			;3
	mov cx, 1000h
	mov ds, cx
	mov dx, [old_dx]
	pop ds
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	inc dx
	push ds 			;4
	mov cx, 1000h
	mov ds, cx
	mov [old_dx], dx
	pop ds
	pop dx
	pop ds
	pop ax
	jmp move_extra_loop
check_end_extra:
	; Pointing at "E"
	inc dx
	push si
	mov si, dx
	mov ah, byte ptr ds:si
	pop si
	cmp ah, "E"
	jne save_extra
	; At the end
	push si
	dec dx
	mov si, dx
	mov byte ptr ds:si, 00h
	inc dx
	mov si, dx
	mov byte ptr ds:si, 00h
	pop si
	jmp find_segs_loop
	

system_error_preapi:
	; There is something horrendously wrong with the
	; system before we loaded our API.
	; Notify the user, and halt.
	xor bh, bh
	mov ah, 0Eh
	mov al, 'B'
	int 10h
	mov al, 'O'
	int 10h
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
	jmp halt_forever
api_load_error:
	xor bh, bh
	; Problems loading the API?
	; This label can help!
	mov ah, 0Eh
	mov al, 'L'
	int 10h
	mov al, 'A'
	int 10h
	mov al, 'P'
	int 10h
	mov ah, 'I'
	int 10h
	mov ah, 20h
	int 10h
	mov ah, 'E'
	int 10h
	mov ah, 'R'
	int 10h
	int 10h
	jmp halt_forever
disk_error:
	xor bh, bh
	mov ah, 0Eh
	mov al, 'D'
	int 10h
	mov al, 'I'
	int 10h
	mov al, 'S'
	int 10h
	mov al, 'K'
	int 10h
	mov al, 20h
	int 10h
	mov al, 'E'
	int 10h
	mov al, 'R'
	int 10h
	int 10h
	jmp halt_forever
drv_error:
	xor bh, bh
	mov ah, 0Eh
	mov al, 'D'
	int 10h
	mov al, 'R'
	int 10h
	mov al, 'V'
	int 10h
	mov al, 20h
	int 10h
	mov al, 'E'
	int 10h
	mov al, 'R'
	int 10h
	int 10h
	jmp halt_forever
halt_forever:
	cli
	hlt
	jmp halt_forever
a20_line_ena:
	; Enable the high memory area.
	mov	ax,2403h		;--- A20-Gate Support ---
	int	15h
	jb	a20_ns			;INT 15h is not supported
	cmp	ah,0
	jnz	a20_ns			;INT 15h is not supported
 
	mov	ax,2402h		;--- A20-Gate Status ---
	int	15h
	jb	a20_failed		;couldn't get status
	cmp	ah,0
	jnz	a20_failed		;couldn't get status
 
	cmp	al,1
	jz	a20_activated		;A20 is already activated
 
	mov	ax,2401h		;--- A20-Gate Activate ---
	int	15h
	jb	a20_failed		;couldn't activate the gate
	cmp	ah,0
	jnz	a20_failed		;couldn't activate the gate
 
a20_activated:			;go on
	ret
a20_failed:
a20_ns:
	mov ah, 0Eh
	mov al, "A"
	int 10h
	mov al, "2"
	int 10h
	mov al, "0"
	int 10h
	mov al, "E"
	int 10h
	mov al, "R"
	int 10h
	int 10h
	jmp halt_forever

drv_nofile:
	mov ah, 01h
	mov dx, missing_drvs
	int 21h
	; Skip past driver processing
	jmp command_prompt
times 2048-($-$$) db 00h
