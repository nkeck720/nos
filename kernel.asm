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
	old_ss dw 0000h    ; For saving our old SS locations.
	old_sp dw 0000h    ; Same for old SP.
	version db "NOS version 2.0 -- built from Git repository", 0Dh, 00h ; Version string
	bootmsg	db "Booting up...", 0Dh, 00h				    ; Boot message
start:
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
	mov dl, 00h	; Floppy 0 is assumed, like in the bootloader
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
	xor al, al		;Just in case
	mov dx, drv_fname	;Name of file (DS should be set to the same as CS)
	mov bx, 6000h		;Yes, this is the same as program ES. ES will later be cleared.
	mov es, bx
	mov bx, 0000h
	int 21h
	;; First check for an error, and if so handle it appropriately
	jc  disk_error
	;; Now we need to parse the data. Formatting is as shown:
	;; 0xAA00FF55 #<filename1>* #<filename2>* ... 0x0D
	;; This is all in one big string, the CR is the EOF mark (spaces not in file).
	;; When sacnning for filenames, anything not enclosed in #* is ignored.
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
	push ax			;When we pop these off, we will ONLY be using the byte in AH
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
	push es			;So we can recover later
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
	
