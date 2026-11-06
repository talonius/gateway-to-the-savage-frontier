; joystick.asm -- ReadJoystick, the game-port reader linked into the Joystick unit
; through {$L JOYSTICK.OBJ}.
;
;   function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;
;   FAR, Pascal convention, ret 0Eh; the Boolean is returned in AL.
;
; Fires the game port's one-shots and counts polls until joystick joy's X, and
; then its Y, one-shot expires; the counts are the raw axis positions.  buttons
; gets the four button bits of port 201h, pressed = 1, in its low nibble (joystick
; 1: bits 0-1, joystick 2: bits 2-3).  False when joy is not 1 or 2 or any wait
; times out.  Each count is followed by an empty `loop $` of SETTLECOUNT minus the
; count, which evens out how long a read takes across stick positions; a count
; equal to SETTLECOUNT leaves CX 0, so the loop runs 65536 times, and only a count
; above it skips the loop.
;
; Note: a Y count above SETTLECOUNT branches to the X store instead of the Y
; store: the count lands in xRaw and the read goes on timing the next port bit
; as Y.

ARGJOY      EQU  12h            ; joy, a byte in its own word
ARGXRAW     EQU  0Eh            ; far pointer to xRaw
ARGYRAW     EQU  0Ah            ; far pointer to yRaw
ARGBUTTONS  EQU  06h            ; far pointer to buttons
GAMEPORT    EQU  201h           ; PC game port: bits 0-3 axis one-shots, 4-7 buttons
SETTLECOUNT EQU  1FFFh          ; an axis count plus its padding loop
BUTTONSHIFT EQU  4              ; button bits sit in the port's high nibble

CODE SEGMENT BYTE PUBLIC
 ASSUME CS:CODE
 PUBLIC READJOYSTICK
READJOYSTICK PROC FAR
 push bp
 mov bp,sp                              ; BP addresses the arguments
 cmp byte ptr [bp+ARGJOY],1
 jz joyValid
 cmp byte ptr [bp+ARGJOY],2
 jz joyValid
 mov al,0                               ; neither joystick 1 nor 2: False
 pop bp
 ret 0Eh
joyValid:
 mov ah,1                               ; AH = X-axis bit: joystick 1 uses bit 0
 xor bx,bx                              ; dead store: BX is set again below
 cmp byte ptr [bp+ARGJOY],2
 jnz maskSet
 shl ah,1
 shl ah,1                               ; joystick 2 uses bit 2
maskSet:
 mov bx,1                               ; BX = X count
 xor cx,cx                              ; CX = 0: the wait allows 65536 polls
 mov al,0FFh
 mov dx,GAMEPORT
 out dx,al                              ; any write fires all four one-shots
xLoop:
 in al,dx
 not al                                 ; a set bit now means its one-shot has expired
 test al,ah
 jnz xDone                              ; X one-shot expired
 inc bx
 loop xLoop
 mov al,0                               ; X never expired: False
 pop bp
 ret 0Eh
xDone:
 mov cx,SETTLECOUNT
 sub cx,bx                              ; CX = padding passes for this count
 jc xStore                              ; count already beyond it: no padding
 loop $                                 ; pad
xStore:
 les di,[bp+ARGXRAW]
 mov es:[di],bx                         ; xRaw := count
 shl ah,1                               ; AH = the Y-axis bit, next above X
 xor cx,cx
yWait:
 in al,dx
 not al
 test al,ah
 jnz yFire                              ; Y one-shot from the first firing has expired
 loop yWait
 mov al,0                               ; Y never expired: False
 pop bp
 ret 0Eh
yFire:
 mov bx,1                               ; BX = Y count
 xor cx,cx
 mov al,0FFh
 out dx,al                              ; fire the one-shots again to time Y alone
yLoop:
 in al,dx
 not al
 test al,ah
 jnz yDone                              ; Y one-shot expired
 inc bx
 loop yLoop
 mov al,0                               ; Y timed out: False
 pop bp
 ret 0Eh
yDone:
 mov cx,SETTLECOUNT
 sub cx,bx                              ; CX = padding passes for this count
 jc xStore                              ; beyond it: the slip to the X store
 loop $                                 ; pad
 les di,[bp+ARGYRAW]
 mov es:[di],bx                         ; yRaw := count
 shr ah,1                               ; AH = the X-axis bit again
 xor cx,cx
buttonWait:
 in al,dx
 not al                                 ; buttons read 1 when pressed after the NOT
 test al,ah
 jnz buttonRead                         ; X one-shot of the second firing expired
 loop buttonWait
 mov al,0                               ; X never expired: False
 pop bp
 ret 0Eh
buttonRead:
 mov cx,BUTTONSHIFT
 shr al,cl                              ; button bits of this read into the low nibble
 les di,[bp+ARGBUTTONS]
 mov es:[di],al                         ; buttons := bits
 mov al,1                               ; True
 pop bp
 ret 0Eh
READJOYSTICK ENDP
CODE ENDS
 END
