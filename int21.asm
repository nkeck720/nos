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
	mov ah, 0Eh
	int 10h
	;; Increment the RAM address pointer and continue
	inc bx
	jmp print_string
print_ds:
	;; Since the special char to terminate the line is a $, we want to print an actual $
	;; if the stored char is null (00h)
	mov ah, 0Eh
	mov al, 24h
	int 10h
	jmp print_string
line_done:
	ret
;--------------------------------
times 510-($-$$) db 0

