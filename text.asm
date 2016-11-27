	; This is an example of data file formatting. There is no beginning of file signature, however
	; the end of file signature is signified by a 0xFF.
	db "This is a text file stored under the NOS file system.", 0Dh, 0Ah
	db "This file is for use with testing the 'type' command. It is also very "
	db "convenient for testing the file system's ability to track stored files."
	; There should always be a newline at the end of text files
	db 0Dh, 0Ah

	db 0FFh
	;--------------------------------
	;Keep the thing in one sector
	times 512-($-$$) db 0
	