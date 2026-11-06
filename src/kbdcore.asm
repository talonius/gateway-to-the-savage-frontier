; kbdcore.asm -- the two BIOS keyboard calls behind GameIo's key queue, linked
; through {$L KBDCORE.OBJ}.  GameIo.RawPending polls BiosPending and, when a key
; is waiting, takes it with BiosRead.  Both are NEAR, take no parameters and
; return in AX:
;   function BiosRead: Word;        AH = scan code, AL = ASCII (0 for an extended key)
;   function BiosPending: Boolean;  1 when a keystroke is waiting, else 0
; Each saves SS and DS across INT 16h, a guard against a BIOS or a resident
; keyboard handler that does not preserve them.
.286
CODE SEGMENT BYTE PUBLIC 'CODE'
ASSUME CS:CODE
PUBLIC BIOSREAD, BIOSPENDING
BIOSREAD PROC NEAR
 push ss                                ; kept across the BIOS call
 push ds                                ; the data segment, likewise
 xor ah,ah                              ; INT 16h function 0: wait for and remove a keystroke
 int 16h                                ; BIOS keyboard; AX = scan code:ASCII, the result
 pop ds
 pop ss
 ret
BIOSREAD ENDP
BIOSPENDING PROC NEAR
 push ss                                ; kept across the BIOS call
 push ds                                ; the data segment, likewise
 mov ah,1                               ; INT 16h function 1: is a keystroke waiting?
 int 16h                                ; BIOS keyboard; ZF set when the buffer is empty
 mov ax,0                               ; False; MOV leaves the BIOS's ZF intact
 jz short pendingDone                   ; buffer empty: return False
 mov ax,1                               ; a key is waiting: return True
pendingDone:
 pop ds
 pop ss
 ret
BIOSPENDING ENDP
CODE ENDS
END
