	; This is an example of data file formatting. There is no beginning of file signature, however
	; the end of file signature is signified by a 0xFF.
	db "This is a text file stored under the NOS file system."
	db "This file is for use with testing the 'type' command. It is also very"
	db "convenient  for testing the file system's ability to track stored files."

	db 0FFh