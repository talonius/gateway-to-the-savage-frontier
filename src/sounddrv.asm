; sounddrv.asm -- the SoundDrv unit's interface to the resident sound driver on INT 66h,
; linked through {$L SOUNDDRV.OBJ} after the unit's Pascal code.  The driver marks
; itself with the text "KERN" six bytes before its interrupt handler.  All three
; are FAR, Pascal convention:
;   procedure DriverDispatch(commandOffset: Word);  hand DS:commandOffset to the
;                                                   driver (function 0688h); ret 2
;   function DriverBusy: Boolean;     the driver's function 0689h answer, in AL
;   function DriverPresent: Boolean;  True when INT 66h leads to a KERN driver
; SoundDrv.SoundCommand checks DriverPresent, waits out DriverBusy, then dispatches
; its DGROUP command record.

KERNVECTOR  EQU  66h*4          ; offset of the INT 66h vector in segment 0
SENDCOMMAND EQU  0688h          ; driver function: take the command at DS:SI
QUERYBUSY   EQU  0689h          ; driver function: nonzero AL while still busy
SIGBACK     EQU  6              ; the signature's distance before the handler
SIGKE       EQU  454Bh          ; 'K','E' as a little-endian word
SIGRN       EQU  4E52h          ; 'R','N'
ARGCOMMAND  EQU  6              ; commandOffset, above BP and the far return

CODE SEGMENT BYTE PUBLIC
 ASSUME CS:CODE
 PUBLIC DRIVERDISPATCH, DRIVERBUSY, DRIVERPRESENT

DRIVERDISPATCH PROC FAR
 push bp
 mov bp,sp                              ; BP addresses the argument
 push es                                ; ES, DS, SI and DI are kept across the driver call
 push ds                                ; DGROUP
 push si
 push di
 cld
 or ax,ax                               ; AX is no parameter: it holds what SoundCommand's
 jz dispatchDone                        ; preceding Move left; zero skips the dispatch
 mov ax,SENDCOMMAND
 mov si,[bp+ARGCOMMAND]                 ; DS:SI = the command record in DGROUP
 int 66h                                ; sound driver
 mov ax,1                               ; unused: the Pascal side is a procedure
dispatchDone:
 pop di
 pop si
 pop ds
 pop es
 pop bp
 ret 2                                  ; drop commandOffset
DRIVERDISPATCH ENDP

DRIVERBUSY PROC FAR
 mov ax,QUERYBUSY
 int 66h                                ; sound driver; AL = the Boolean result
 ret
DRIVERBUSY ENDP

DRIVERPRESENT PROC FAR
 call probeDriver                       ; AX = 1 when present, else 0
 ret
probeDriver:
 push ds                                ; DGROUP
 push si
 mov si,KERNVECTOR
 xor ax,ax
 mov ds,ax                              ; DS = 0: the interrupt vector table
 lds si,[si]                            ; DS:SI = the INT 66h handler
 or si,si
 jz driverAbsent                        ; handler offset 0: taken as no driver installed
 sub si,SIGBACK                         ; DS:SI = where the signature should sit
 cmp word ptr [si],SIGKE
 jnz driverAbsent
 cmp word ptr [si+2],SIGRN
 jnz driverAbsent
 mov ax,1                               ; "KERN" found
probeReturn:
 pop si
 pop ds
 retn                                   ; back into DRIVERPRESENT
driverAbsent:
 xor ax,ax
 jmp short probeReturn
DRIVERPRESENT ENDP
CODE ENDS
 END
