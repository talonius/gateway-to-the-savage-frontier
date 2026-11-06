; textrend.asm -- the hand-assembled half of TextRend, linked through {$L TEXTREND.OBJ}: the four glyph blitters
; RenderChar dispatches on displayMode, one per mode.  Each paints one 8x8 character cell from the glyph rows RenderChar
; has just copied into GLYPHBITS, ink where a bit is set and paper where it is clear.
;
; Entry points, as textrend.pas declares them between {$F-} and {$F+}:
;   procedure CGAGLYPH(col, row: Word; fg, bg, charIdx: Byte); external;      mode 0, CGA 320x200x4
;   procedure EGAGLYPH(col, row: Word; fg, bg, charIdx: Byte); external;      mode 1, EGA 320x200x16
;   procedure TANDYGLYPH(col, row: Word; fg, bg, charIdx: Byte); external;    mode 2, Tandy 320x200x16
;   procedure VGAGLYPH(col, row: Word; fg, bg, charIdx: Byte); external;      mode 3, VGA 320x200x256
; NEAR, Pascal convention (arguments pushed in order, the callee pops them with ret 0Ah); col 0..39, row 0..24.
; Each is entered with DS = DGROUP, loads ES with a video segment, and leaves SS and DS as it found them.
;
; ATTRTAB and GLYPHBITS are fixed DGROUP offsets of GDConsts.attrTable and GDVars.glyphBits: the object carries no
; relocations, so they must be changed whenever that storage moves.

CODE    SEGMENT BYTE PUBLIC 'CODE'
        ASSUME  CS:CODE
        PUBLIC  CGAGLYPH, EGAGLYPH, TANDYGLYPH, VGAGLYPH

ATTRTAB   EQU  3082h        ; each color's 2-bit CGA pixel value, a byte per color (GDConsts.attrTable)
GLYPHBITS EQU  7852h        ; the glyph's 8 rows, bit 0 its rightmost pixel (GDVars.glyphBits)

ARGCOL    EQU  0Ch          ; col, the character column
ARGROW    EQU  0Ah          ; row, the character row
ARGFG     EQU  8            ; fg, the ink color
ARGBG     EQU  6            ; bg, the paper color
                            ; charIdx, unread: the glyph is already in GLYPHBITS

; ===========================================================================
; CGAGLYPH -- displayMode 0: CGA 320x200 in four colors, two bits a pixel.  Even
; scanlines are at B800:0 and odd ones at BA00:0, 80 bytes each, so a character
; row is 4*80 = 320 bytes of each bank and a cell is 2 bytes wide.
; ===========================================================================
CGAGLYPH LABEL NEAR
        push    bp
        mov     bp,sp
        push    ss                      ; SS and DS are restored before the return
        push    ds
        mov     ax,[bp+ARGROW]
        mov     bx,140h
        mul     bx
        mov     bx,[bp+ARGCOL]
        shl     bx,1
        add     ax,bx
        mov     di,ax                   ; DI = row*320 + col*2, the cell's first byte in each bank
        xor     bx,bx
        mov     bl,[bp+ARGFG]
        mov     dl,[bx+ATTRTAB]         ; DL = the ink's CGA pixel, in bits 0-1
        mov     bl,[bp+ARGBG]
        mov     dh,[bx+ATTRTAB]         ; DH = the paper's
        xor     bx,bx                   ; BX = glyph row
        mov     ah,1                    ; AH = the pixel's bit in the glyph row, rightmost first
        mov     cx,4                    ; 4 scanline pairs, one glyph row in each bank
@@cgaPair:
        push    cx
        mov     cx,0B800h
        mov     es,cx                   ; ES = bank 0, the even scanlines
        mov     cx,2                    ; 2 bytes to the cell
        inc     di                      ; the cell's right byte first
@@cgaEvenByte:
        push    cx
        mov     cx,4                    ; 4 pixels to the byte
        mov     al,0
@@cgaEvenPixel:
        test    [bx+GLYPHBITS],ah
        jz      @@cgaEvenPaper
        or      al,dl                   ; ink
        jmp     @@cgaEvenNext
@@cgaEvenPaper:
        or      al,dh                   ; paper
@@cgaEvenNext:
        rol     dl,1
        rol     dl,1                    ; both pixel values move one pixel (two bits) left
        rol     dh,1
        rol     dh,1
        rol     ah,1                    ; and so does the glyph bit
        loop    @@cgaEvenPixel
        mov     es:[di],al
        dec     di                      ; the byte to its left
        pop     cx
        loop    @@cgaEvenByte
        inc     bx                      ; next glyph row
        inc     di                      ; DI = the cell's first byte again
        mov     ah,1                    ; AH, DL and DH have come full circle; AH is reset anyway
        mov     al,0
        mov     cx,0BA00h
        mov     es,cx                   ; ES = bank 1, the odd scanlines
        mov     cx,2
        inc     di
@@cgaOddByte:
        push    cx
        mov     cx,4
        mov     al,0
@@cgaOddPixel:
        test    [bx+GLYPHBITS],ah
        jz      @@cgaOddPaper
        or      al,dl
        jmp     @@cgaOddNext
@@cgaOddPaper:
        or      al,dh
@@cgaOddNext:
        rol     dl,1
        rol     dl,1
        rol     dh,1
        rol     dh,1
        rol     ah,1
        loop    @@cgaOddPixel
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@cgaOddByte
        inc     bx
        add     di,51h                  ; back to the cell's first byte, one scanline down the bank (+80)
        pop     cx
        loop    @@cgaPair
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; pops the 10 bytes of arguments

; ===========================================================================
; EGAGLYPH -- displayMode 1: EGA 320x200x16, four planes, 40 bytes a scanline, a
; cell one byte wide.  Write mode 2 takes the color from the CPU byte and the
; pixels from the Bit Mask: each glyph row is painted as ink through its set
; bits, then as paper through its clear ones.  Read mode 1 with Color Don't
; Care 0 makes every read return FFh, so `and es:[di],al` loads the latches and
; writes AL unchanged.
; ===========================================================================
EGAGLYPH LABEL NEAR
        push    bp
        mov     bp,sp
        push    ss                      ; SS and DS are restored before the return
        push    ds
        mov     ax,0A000h
        mov     es,ax                   ; ES = EGA display memory
        mov     ax,[bp+ARGROW]
        mov     bx,140h
        mul     bx
        add     ax,[bp+ARGCOL]
        mov     di,ax                   ; DI = row*320 + col: 8 scanlines of 40 bytes a row
        mov     dx,3CEh                 ; graphics controller: index in AL, data in AH
        mov     ax,0A05h                ; GC 5 Mode := 0Ah: write mode 2, read mode 1
        out     dx,ax
        mov     ah,0
        mov     al,3                    ; GC 3 Data Rotate := 0: replace, no rotation
        out     dx,ax
        mov     ax,7                    ; GC 7 Color Don't Care := 0
        out     dx,ax
        xor     bx,bx                   ; BX = glyph row
        mov     cx,8
@@egaRow:
        mov     ah,[bx+GLYPHBITS]
        mov     al,8                    ; GC 8 Bit Mask := the glyph row: the ink pixels
        out     dx,ax
        mov     al,[bp+ARGFG]
        and     es:[di],al              ; paint them in fg
        not     ah
        mov     al,8                    ; Bit Mask := the other pixels
        out     dx,ax
        mov     al,[bp+ARGBG]
        and     es:[di],al              ; paint them in bg
        add     di,28h                  ; next scanline, 40 bytes on
        inc     bx
        loop    @@egaRow
        mov     ax,5                    ; GC 5 Mode := 0: write mode 0, read mode 0
        out     dx,ax
        mov     ax,0FF08h               ; GC 8 Bit Mask := FFh, every pixel
        out     dx,ax
        mov     ax,3                    ; GC 3 Data Rotate := 0
        out     dx,ax
        mov     ax,0F07h                ; GC 7 Color Don't Care := 0Fh
        out     dx,ax
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; pops the 10 bytes of arguments

; ===========================================================================
; TANDYGLYPH -- displayMode 2: Tandy 320x200x16, four bits a pixel, 160 bytes a
; scanline in four interleaved banks (B800, BA00, BC00, BE00), so a character row
; is 2*160 = 320 bytes of each bank and a cell is 4 bytes wide.  The colors are
; 4-bit indices used as they are, with no ATTRTAB lookup.
; ===========================================================================
TANDYGLYPH LABEL NEAR
        push    bp
        mov     bp,sp
        push    ss                      ; SS and DS are restored before the return
        push    ds
        mov     ax,[bp+ARGROW]
        mov     bx,140h
        mul     bx
        mov     bx,[bp+ARGCOL]
        shl     bx,1
        shl     bx,1
        add     ax,bx
        mov     di,ax                   ; DI = row*320 + col*4, the cell's first byte in each bank
        mov     dl,[bp+ARGBG]           ; DL = paper
        mov     dh,[bp+ARGFG]           ; DH = ink
        xor     bx,bx                   ; BX = glyph row
        mov     ah,1                    ; AH = the pixel's bit in the glyph row, rightmost first
        mov     cx,2                    ; 2 passes of 4 banks, one glyph row in each
@@tandyPass:
        push    cx
        mov     cx,0B800h
        mov     es,cx                   ; ES = bank 0
        mov     cx,4                    ; 4 bytes to the cell
        add     di,3                    ; the cell's right byte first
@@tandyBank0Byte:
        push    cx
        mov     cx,2                    ; 2 pixels to the byte
        mov     al,0
@@tandyBank0Pixel:
        test    [bx+GLYPHBITS],ah
        jz      @@tandyBank0Paper
        or      al,dh                   ; ink
        jmp     @@tandyBank0Next
@@tandyBank0Paper:
        or      al,dl                   ; paper
@@tandyBank0Next:
        push    cx
        mov     cx,4
        rol     dl,cl                   ; both colors move one pixel (a nibble) left
        mov     cx,4
        rol     dh,cl
        rol     ah,1                    ; and so does the glyph bit
        pop     cx
        loop    @@tandyBank0Pixel
        mov     es:[di],al
        dec     di                      ; the byte to its left
        pop     cx
        loop    @@tandyBank0Byte
        add     di,4                    ; DI = the cell's right byte again
        inc     bx                      ; next glyph row
        mov     cx,0BA00h
        mov     es,cx                   ; ES = bank 1
        mov     cx,4
@@tandyBank1Byte:
        push    cx
        mov     cx,2
        mov     al,0
@@tandyBank1Pixel:
        test    [bx+GLYPHBITS],ah
        jz      @@tandyBank1Paper
        or      al,dh
        jmp     @@tandyBank1Next
@@tandyBank1Paper:
        or      al,dl
@@tandyBank1Next:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@tandyBank1Pixel
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@tandyBank1Byte
        add     di,4
        inc     bx
        mov     cx,0BC00h
        mov     es,cx                   ; ES = bank 2
        mov     cx,4
@@tandyBank2Byte:
        push    cx
        mov     cx,2
        mov     al,0
@@tandyBank2Pixel:
        test    [bx+GLYPHBITS],ah
        jz      @@tandyBank2Paper
        or      al,dh
        jmp     @@tandyBank2Next
@@tandyBank2Paper:
        or      al,dl
@@tandyBank2Next:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@tandyBank2Pixel
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@tandyBank2Byte
        add     di,4
        inc     bx
        mov     cx,0BE00h
        mov     es,cx                   ; ES = bank 3
        mov     cx,4
@@tandyBank3Byte:
        push    cx
        mov     cx,2
        mov     al,0
@@tandyBank3Pixel:
        test    [bx+GLYPHBITS],ah
        jz      @@tandyBank3Paper
        or      al,dh
        jmp     @@tandyBank3Next
@@tandyBank3Paper:
        or      al,dl
@@tandyBank3Next:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    @@tandyBank3Pixel
        mov     es:[di],al
        dec     di
        pop     cx
        loop    @@tandyBank3Byte
        inc     bx
        add     di,0A1h                 ; back to the cell's first byte, one scanline down the bank (+160)
        pop     cx
        dec     cx
        jz      @@tandyDone
        jmp     @@tandyPass             ; dec/jz/jmp: loop cannot reach the pass's start
@@tandyDone:
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; pops the 10 bytes of arguments

; ===========================================================================
; VGAGLYPH -- displayMode 3: 320x200x256 (mode 13h) at A000:0, one byte a pixel,
; so a cell is 8 bytes wide.  Each glyph row is painted right to left, and the
; next scanline is reached by adding 14h paragraphs (320 bytes) to ES.
; ===========================================================================
VGAGLYPH LABEL NEAR
        push    bp
        mov     bp,sp
        push    ss                      ; SS and DS are restored before the return
        push    ds
        mov     ax,[bp+ARGROW]
        mov     bx,0A00h
        mul     bx
        mov     bx,[bp+ARGCOL]
        shl     bx,1
        shl     bx,1
        shl     bx,1
        add     ax,bx
        mov     di,ax                   ; DI = row*(8*320) + col*8, the cell's first pixel
        mov     dl,[bp+ARGBG]           ; DL = paper
        mov     dh,[bp+ARGFG]           ; DH = ink
        mov     cx,0A000h
        mov     es,cx                   ; ES = the mode-13h frame
        mov     cx,8                    ; 8 glyph rows
        xor     bx,bx                   ; BX = glyph row
        dec     di                      ; so that the add below reaches the row's last pixel
@@vgaRow:
        add     di,8                    ; DI = the row's rightmost pixel
        push    cx
        mov     ah,1                    ; AH = the pixel's bit in the glyph row, rightmost first
        mov     cx,8                    ; 8 pixels
@@vgaPixel:
        mov     al,dl                   ; paper
        test    [bx+GLYPHBITS],ah
        jz      @@vgaPut
        mov     al,dh                   ; unless the bit is set: ink
@@vgaPut:
        mov     es:[di],al
        dec     di                      ; the pixel to its left
        rol     ah,1
        loop    @@vgaPixel
        pop     cx
        inc     bx                      ; next glyph row
        mov     ax,es
        add     ax,14h                  ; ES += 320 bytes: the next scanline
        mov     es,ax
        loop    @@vgaRow
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; pops the 10 bytes of arguments

CODE    ENDS
        END
