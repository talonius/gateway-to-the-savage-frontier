; mcremap.asm -- RemapView, the hand-assembled tail of MenuCore, linked through
; {$L MCREMAP.OBJ}.  It steps the three animated palette indices of the mode-13h
; 3D view in place: 1Dh -> 1Fh, 1Eh -> 1Dh, 1Fh -> 1Eh, leaving every other pixel.
; MenuCore's menu wait loop calls it while a remap is pending and more than 25
; GetTicks units (hundredths of a second) have passed since frameTick, which the
; loop sets on menu entry, on each animation-frame advance and after each step.
; FAR, no parameters.  It saves DS, which it points at video memory, and SS with it.

VIEWORG   EQU  24*320+24        ; top-left pixel of the view in the A000h frame
VIEWSIZE  EQU  88               ; the view is 88 pixels square
ROWSKIP   EQU  320-VIEWSIZE     ; frame bytes between one view row and the next
CYCLOW    EQU  1Dh              ; first of the three cycled color indices
CYCHIGH   EQU  1Fh              ; last of them

CODE SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE
        PUBLIC  REMAPVIEW

REMAPVIEW PROC FAR
        push    ss
        push    ds              ; DGROUP, restored on exit
        cld                     ; lodsb/stosb walk forward along a row
        mov     ax,0A000h       ; mode-13h frame buffer segment
        mov     es,ax           ; ES:DI writes the frame
        mov     ds,ax           ; DS:SI reads the frame
        mov     si,VIEWORG      ; SI = first pixel of the view's top row
        mov     cx,VIEWSIZE     ; CX = rows left
@@row:
        push    cx              ; keep the row count while CX counts pixels
        mov     cx,VIEWSIZE     ; CX = pixels left in this row
@@pixel:
        lodsb                   ; AL = pixel, SI moves past it
        cmp     al,CYCHIGH
        ja      @@next          ; above the cycled band: leave it
        cmp     al,CYCLOW
        jb      @@next          ; below the band: leave it
        dec     al              ; step the index down one
        cmp     al,CYCLOW-1     ; 1Dh stepped below the band: wrap to the top
        jnz     @@store
        mov     al,CYCHIGH
@@store:
        mov     di,si
        dec     di              ; DI = the pixel just read
        stosb                   ; write the stepped index back in place
@@next:
        loop    @@pixel
        pop     cx              ; CX = rows left
        add     si,ROWSKIP      ; SI = start of the view's next row
        loop    @@row
        pop     ds
        pop     ss
        ret
REMAPVIEW ENDP

CODE ENDS
END
