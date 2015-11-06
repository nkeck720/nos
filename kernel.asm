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
	; 2000:0000	   '	  '	  '   FSB (filesystem block)
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
mbr_clear:
	mov ah, [0000h:bx]
	xor ah, ah
	mov [0000h:bx], ah
	loop mbr_clear
	; We should now have the MBR area clean, set the stack up.
	mov ss, 0000h
	mov sp, 7E00h
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
	; This will involve changing interrupt vectors. ALWAYS DISABLE INTERRUPTS BEFORE CHANGING
	; ANY VECTORS!
	cli
	; Get the file block, using ES to do so
	mov ax, 2000h
	mov es, ax
	xor bx, bx
	mov cx, 0008d
	; The program, as stated, assumes the FSB is set on startup.
	; INT21 is always the first file entry on the disk. If it isn't, then
	; we will have to abort the boot.
	; Get the first bytes of the file field.
	mov ah, [2000h:cx]
	cmp ah, 80h
	jne api_load_error
	inc cx	; To location of CHS
	; Get each value and push them.
	xor al, al
	mov ah, [2000h:cx]
	push ax
	inc cx
	mov ah, [2000h:cx]
	push ax
	inc cx
	mov ah, [2000h:cx]
	push ax
	inc cx
	; Get the "number of sectors" byte
	mov ah, [2000h:cx]
	push ax
	inc cx
	; Now we need to make sure file name is valid.
	; Get each byte and compare it.
