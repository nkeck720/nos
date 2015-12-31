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
	; 9000:0000	   '	  '	  '   Command line space
	;
	; And as such we now begin our code...
	; We want to create a sort of data area first, so here we jump over that.
	jmp start
	; We now begin our data area.
	old_ss dw 0000h 						    ; For saving our old SS locations.
	old_sp dw 0000h 						    ; Same for old SP.
	version db "NOS version 2.0 -- built from Git repository", 0Dh, 00h ; Version string
	bootmsg db "Booting up...", 0Dh, 00h				    ; Boot message
	drv_fname db "DRVS", 00h					    ; Driver list file name
	blank_line db 0Dh, 00h						    ; A blank line on the screen
	prompt db "NOS> ", 00h						    ; Command prompt
	bad_command db "That command doesn't exist.", 0Dh, 00h		    ; Bad command message
	ret_opcode ret				       ; A RET is a single-byte instruction, so we store it here for later
start:
	pop dl			; Get our boot drive
	mov boot_drv, dl	; Save it
	; save the boot drive where our INT21 functions will know about it
	mov [8000h:0FFFFh], dl
	; The moment of truth.
	; First we want to set up our segments to what we need. Since the kernel exists as
	; a flat program, set ES and DS to CS.
	; This is a bad practice, but our bootloader should keep the stack within a sane RAM location,
	; as assumed.
	push cs
	push cs
	pop ds
	pop es
	; Now we clear out our bootloader, and set it to the stack.
	mov cx, 0200h	   ; The size of one sector
	mov bx, 7C00h	   ; The beginning location of our bootloader
	mov dx, 0000h	   ; FASM says we have to do it this way...
	mov es, dx
mbr_clear:
	xor ah, ah
	mov es:bx, ah
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
	; Clear out ES
	xor dx, dx
	mov es, dx
	; Now we need to get the API into RAM. This will be stored in a file called INT21,
	; and will be non-executable.
get_api:
	; This will involve changing interrupt vectors. ALWAYS DISABLE INTERRUPTS BEFORE CHANGING
	; ANY VECTORS!
	cli
	; Get the file, by loading the FSB entry
	xor bx, bx
	mov si, 0008d		;Changed as suggested by SeproMan
	; The program, as stated, assumes the FSB is set on startup.
	; INT21 is always the first file entry on the disk. If it isn't, then
	; we will have to abort the boot.
	; Get the first bytes of the file field.
	mov ah, [2000h:si]
	cmp ah, 80h
	jne api_load_error
	inc si	; To location of CHS
	; Get each value and push them.
	xor al, al
	mov ah, [2000h:si]
	push ax
	inc si
	mov ah, [2000h:si]
	push ax
	inc si
	mov ah, [2000h:si]
	push ax
	inc si
	; Get the "number of sectors" byte
	mov ah, [2000h:si]
	push ax
	inc si
	; Now we need to make sure file name is valid.
	; Get each byte and compare it.
	; First we need to get the INT21 bytes...
	mov cx, 0005d
	mov si, cx
c1:	
	mov ah, [2000h:si]
	push ax
	dec si
	loop c1
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
	mov ch, dh	; Sector
	mov dx, si
	xor si, si
	mov dl, [boot_drv]  ; Our boot drive
	mov ah, 02h	; Read sectors
	; And now, a brief word from INT 13h...
	sti
	mov bx, 8000h
	mov es, bx
	mov bx, 0000h
	int 13h
	jc  api_load_error
	cli
	; Our Kernel API is now loaded, so we need to set our IVT values.
	xor ax, ax
	xor bx, bx
	xor cx, cx
	xor dx, dx
	mov es, bx
	mov ax, 8000h
	mov bx, 0000h	; Just to make sure
	mov 0000:21h*4+2, bx
	mov 0000:21h*4, ax
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
	jc  disk_error
	;; Now we need to parse the data. Formatting is as shown:
	;; 0xAA00FF55 #<filename1>* #<filename2>* ... 0x0D
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
	mov ax, word ptr [0000h]	;Get the first word
	mov bx, word ptr [0002h]	;And the second one
	cmp ax, 00AAh
	;; If we have a bad file, we want to skip over it like it doesn't exist to
	;; avoid errors.
	jne drv_file_done
	cmp bx, 55FFh
	jne drv_file_done
	;; Now we will get the individual filenames.
	mov cx, 0004h		;start the pointer at the byte after the header.
	xor bh, bh		;for filename processing
get_dem_filenames:
	;; Scan until we get a hash
	mov ah, byte ptr [ds:cx]
	cmp ah, "#"
	je  we_got_one
	;; So this one isn't a hash. See if it is our EOF.
	cmp ah, 0Dh
	je  drv_file_done
	;; It isn't either one, so we increment the pointer and try again.
	inc cx
	jmp get_dem_filenames
we_got_one:
	;; We found a hash, we need to get each char until we get a closing asterisk.
	inc cx
	mov ah, byte ptr [ds:cx]
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
	mov cx, bh
pop_off_loop:	
	pop ax
	mov [ds:0FFF0h+bh], ah
	loop pop_off_loop
	;; We should have this now:
	;; <top>
	;; | Original DS
	;; <end>
	;; Now we need to place the 0x00 string terminator on the string.
	inc bh
	mov [ds:0FFF0h+bh], 00h
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
	mov al, byte ptr [es:bx]
	cmp al, "F"
	;; If this isn't flat we will take the "scream and run" approach:
	;; - Notify the user that a driver is invalid
	;; - Stop any further driver loading
	;; - Clear out the TSR space
	;; - Continue with OS loading
	;; - Do not use any external commands.
	;; We will start this "safe mode" state by setting the first byte in the TSR space to 0x12.
	jne run_for_your_life
	;; The driver is OK. Here we will run the code, by calling it. To exit, a program/driver
	;; must "RET".
	call 3000h:0001h
	;; Check the return code to match a driver. Again, if this is not true then we need to run
	;; for our lives.
	cmp ch, 00h
	jne run_for_your_life
	;; Check for a successful return code
	cmp cl, 00h
	;; If no success, then we could have an issue, so we need to run for it just in case.
	jne run_for_your_life
	;; If we get here, we are successfully loaded.
	pop cx
	pop es
	jmp get_dem_filenames
drv_file_done:
	;; When we get here we are done with our driver file. We need to unload DRVS (from RAM, no writing
	;; to disk is necessary since we didn't modify anything in the file.
	;; Stack:
	;; <top>
	;; | Original DS
	;; <end>
	mov cx, 0FFFFh
	xor bx, bx
unload_drv_list:
	mov si, cx		; For writing to RAM (thanks Sepro!)
	mov ds:si, bh
	loop unload_drv_list	; Keep going until CX gets to 0
	;; Driver list unloaded, we can return to home sweet Original DS.
	pop ds
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
	push ds 		; Save original DS again
	mov ax, 9000h
	mov ds, ax		; The command line space as shown in the memory model
	mov dx, 0000h
	int 21h
	;; Now, we switch back to the original DS and parse the command.
	;; For now, the only builtin we have is CLS.
	pop ds
	push es 		; Save ES
	mov bx, 9000h
	mov es, bx
	mov bx, 0000h
	;; String compare function is under development, so for now we want to use
	;; the individual comparison.
	mov ah, byte ptr [es:bx]
	cmp ah, "C"		; Command line is always in caps
	jne external_command
	inc bx
	mov ah, byte ptr [es:bx]
	cmp ah, "L"
	jne external_command
	inc bx
	mov ah, byte ptr [es:bx]
	cmp ah, "S"
	jne external_command
	inc bx			; We still have to check for the end of the line
	mov ah, byte ptr [es:bx]
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
external_command:
	;; We have a disk-based program to load, so here we want to load that
	;; and set up the memory model of the said file.
	;; First we want to make sure the FSB is up to date.
	mov ah, 02h
	mov al, 01d
	mov mov ch, 00h
	mov cl, 01d
	mov dh, 00h
	mov dl, [boot_drv]
	mov bx, 4000h		;The program segment, which will be used later to run the thing
	mov es, bx
	mov bx, 0000h
	int 13h
	;; If there is a disk error, we want to call up the handler
	jc  disk_io_error
	;; Load up the file specified, and signal for the check of executable file
	;; by setting carry on call
	push ds 	  ; Save this again
	mov ah, 02h
	mov dx, 4000h
	mov ds, dx
	mov dx, 0000h
	;; ES:BX should be already set
	stc		  ; STC indicates the loading of an executable file
	int 21h
	;; Check to make sure the file was loaded. If not, we don't have an executable file
	;; or the file was not found.
	jc  bad_prog_file
	;; Now check for a flat or segmented program
	pop ds			; We get this back now
	mov ah, byte ptr [es:bx]
	cmp ah, "F"
	je  run_flat_prog
	cmp ah, "S"
	je run_segmented_prog
	;; Anything else and we have an invalid program.
	jmp bad_prog_hdr
bad_prog_file:
	;; If we get here the user has either entered a bad command, or there was a disk error.
	;; In any case we need to notify the user and return to a prompt.
	push cs
	pop ds
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
	mov ah, byte ptr [es:bx]
	cmp ah, "E"
	jne not_done_yet_flat
	inc bx
	mov ah, byte ptr [es:bx]
	cmp ah, "F"
	jne not_done_yet_flat
	inc bx
	mov ah, byte ptr [es:bx]
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
	mov es:bx, [ret_opcode]
	inc bx
	; Now pointing at the "F"
	; save these two as NULLs
	mov es:bx, 00h
	inc bx
	mov es:bx, 00h
	; Now that we have stripped the file down to the code, call it at the starting address,
	; setting the stack segment before we do so.
	push ss
	pop ax
	mov [old_ss], ax
	mov ax, sp
	mov [old_sp], ax
	call 4000h:0001h
	; Reset our stack
	mov ax, [old_ss]
	mov bx, [old_sp]
	mov ss, ax
	mov sp, bx
	; When we return here, we clear out the segment
	; Set up a loop to do so
	mov cx, 0FFFFh
	; ES is already set
clear_code_flat:
	mov bx, cx
	mov es:bx, 00h
	loop clear_code_flat
	; Now return to the prompt.
	push cs
	pop ds
	jmp command_prompt
no_flat_footer:
	; No footer was detected in the program.
	; Stop here, give a message, and clear out the seg.
	mov ah, 01h
	mov dx, bad_program
	int 21h
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
	; 0xFF signature
	; [end file]
	; We also have a bit of a problem: this file will probably be greater than 64K. We will need to check this,
	; and if it is process it in blocks of 64K.
	;
	; Begin by checking the file size in the FSB
	
