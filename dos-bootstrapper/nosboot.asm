	org 100h
	;
	; NOSBOOT.ASM - This DOS program is a simple .COM program that is designed to load NOS
	; into a specific place and boot it up, replacing the DOS interface with NOS.
	; Use wisely - running this program in certain environments can cause instability.
	;
	jmp start
	; This will be our data area
	version db "NOS Bootstrapper version 1.00.", 0Dh, 0Ah, "$"
	notice db "This software is distributed with NOS and falls under", 0Dh, 0Ah
		   db "the same liscense (GNU GPL v2). Please see the GitHub", 0Dh, 0Ah
		   db "page for more information.$"
	insert db "Insert your NOS disk in drive A:. Then press return.", 0Dh, 0Ah, "$"
	errors db "OOPS! Something went wrong. Make sure you are using your NOS disk.", 0Dh, 0Ah, "$"
	
start:
	push cs
	pop ds
	mov ah, 09h
	mov dx, version
	int 21h
	mov ah, 09h
	mov dx, notice
	int 21h
	; Tell the user to insert the disk
	mov ah, 09h
	mov dx, insert
	int 21h
	; Wait here for the user to press return (or really any other key)
	mov ah, 00h
	int 16h
	; Try to load the bootsector and make sure that the signature exists
	mov ah, 02h
	mov al, 01h
	mov ch, 00h
	mov dh, 00h
	mov cl, 01h
	mov dl, 00h
	mov bx, 0000h
	mov es, bx
	mov bx, 7C00h
	int 13h
	jc  boot_error
	mov ax, word ptr 0000h:7DFEh
	cmp ax, word 0AA55h
	jne boot_error
	; Make sure that the three bytes preceeding that say "NOS"
	cmp byte ptr es:7DFBh, "N"
	jne boot_error
	cmp byte ptr es:7DFCh, "O"
	jne boot_error
	cmp byte ptr es:7DFDh, "S"
	jne boot_error
	; we are in the clear, so set DL to the boot drive and jump to the
	; bootloader
	mov dl, 00h
	jmp 0000h:7C00h
boot_error:
	; Houston, we've had a problem.
	mov ah, 09h
	mov dx, errors
	int 21h
	int 20h
	