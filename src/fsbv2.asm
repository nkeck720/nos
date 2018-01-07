; This is the new FSB layout for NOSFS v2 (used with hard disks).
;      TODO: Expand the FSB to multiple sectors?
; This layout is designated by an "0xFE" footer rather than 0xFF
; Start with the 4-byte on-disk address for kernel start, zero meaning no kernel (Kernel must be in first 1/2 of disk)
db 0,0,0,0
; Give the length of kernel in blocks, FF for none (backwards compat)
db 0FFh
; Allocated space for free blocks, 8 bytes
db 0,0,0,0,0,0,0,0
; Allocated space for remaining blocks
db 0,0,0,0,0,0,0,0
; File fields will go as follows:
;      0x80 (new field flag)
;      8-byte absolute start address
;      2-byte length
;      8-byte filename
;      Status byte
;      0xFF (end field flag)
; No space shall exist between these fields. Any zero space is treated as the last file field.
times 511-($-$$) db 0
db 0FEh
