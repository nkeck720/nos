	use16
	;; This is the int 21h code used in NOS.
	;; Begin by checking the function and its parameters...
	cmp ah, 00h
	je  print_string
	;; Set the invalid function register (BL) to FF and return
	mov bl, 0FFh
	ret
print_string:
	;; grab the char from RAM and process it
	mov al, [es:bx]
	cmp al, 24h
	je  line_done		; We want the terminating character to be $
	cmp al, 00h		; If null then print a $
	je  print_ds
	;; Go ahead and print the character since it is not a handled char
	mov ah, 09h
	int 10h
	;; Move the cursor to the right
	cmp dl, 80d
	je  line_dn		; If the end of a line is reached, we want to scroll down one line
	inc dl			; If not, then move the cursor to the right
	mov ah, 02h
	int 10h
	;; Increment the RAM address pointer and continue
	inc bx
	jmp print_string
print_ds:
	;; Since the special char to terminate the line is a $, we want to print an actual $
	;; if the stored char is null (00h)
	mov ah, 09h
	mov al, 24h
	int 10h
	cmp dl, 80d
	je  line_dn
	mov ah, 02h
	inc dl
	jmp print_string
line_dn:
	;; Scroll down a line and move the cursor to the beginning of said line
	mov ah, 07h
	mov al, 01h
	int 10h
	mov ah, 02h
	mov dl, 00h
	inc dh
	int 10h
	jmp print_string
line_done:
	ret
;--------------------------------
times 512-($-$$) db 0

