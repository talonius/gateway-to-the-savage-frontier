; raster.asm -- the hand-assembled half of Raster, linked through {$L RASTER.OBJ}: the per-mode tile blitters and
; the scanline loops they share, the VGA palette upload, the EGA row flush, and the picture-data helpers Blit calls.
;
; Entry points, as raster.pas declares them.  Pascal convention: arguments are pushed in order, so the last lies
; nearest bp, and the callee pops them.
;   BlitCellCga, BlitCellCgaMasked, BlitCellEga, BlitCellEgaMasked, BlitCellTandy, BlitCellTandyMasked, BlitCellVga
;                   (screenX,screenY:Integer; tileIdx:Byte; gfx,dest:PImgBuf)                   NEAR, ret 0Eh
;   BlitCellVgaKeyed (transpColor:Byte; screenX,screenY:Integer; tileIdx:Byte; gfx,dest:PImgBuf) NEAR, ret 10h
;   BlitClippedCga, BlitClippedEga, BlitClippedTandy
;                   (saveUnder:PImgBuf; screenX,screenY:Integer; tileIdx,flag:Byte; gfx,dest:PImgBuf)  NEAR, ret 14h
;   BlitClippedVga  (transpColor:Byte; saveUnder:PImgBuf; ...as BlitClippedCga)                 NEAR, ret 16h
;   PrepareVgaPaletteImpl                                                                       NEAR
;   SetPaletteEntry(index:Word; red,green,blue:Byte)                                            FAR, ret 8
;   SetDefaultPalette                                                                           FAR
;   FlushEga(data:PBytes)                                                                       NEAR, ret 4
;   ShowPicEgaImpl(data:Pointer; screenRow,height,destOff,width:Word)                           NEAR, ret 0Ch
;   WriteEgaCellsImpl(src,dst:Pointer; count:Word), UnpackFivePlanesImpl(src,dst:Pointer; count:Word)
;                                                                                               NEAR, ret 0Ah
; Each is entered with DS = DGROUP and leaves SS and DS as it found them.
;
; The first nine EQUs are fixed DGROUP offsets.  The object's only DGROUP relocation is `mov ax,DATA`, so they must be
; changed whenever that storage moves.  The first four name GDVars' deferred-render span tables of the same name,
; EGAROWS is GDVars.fbRowOfs, and the last four are GDVars.dacTable, paletteWork, paletteShown and paletteFrame.

        LOCALS

SPANACTIVE    EQU 5DD2h   ; byte per view scanline: drawn since the last flush
SPANSCREENOFS EQU 5E7Ah   ; word per row: the screen byte of the leftmost dirty cell
SPANFIRSTOFS  EQU 5FCAh   ; word per row: picture offset of the first dirty byte, FFFFh when clean
SPANLASTOFS   EQU 611Ah   ; word per row: picture offset of the last dirty byte
EGAROWS       EQU 669Ah   ; EGA row table, word per screen scanline: its offset in A000h (GDVars.fbRowOfs)
DACTAB        EQU 0A0FCh  ; DAC levels for entries 16..31, three bytes each, expanded from PALWORK (GDVars.dacTable)
PALWORK       EQU 0A12Ch  ; the staged picture palette, a TPalette24 (GDVars.paletteWork)
PALSHOWN      EQU 0A144h  ; the palette the DAC last received; Blit's unit init zeroes it (GDVars.paletteShown)
PALFRAME      EQU 0A15Ch  ; the staged picture's currentFrame, 0 for none (GDVars.paletteFrame)

VIEWTOP    EQU 8                ; the view starts eight scanlines down
VIEWROWS   EQU 168              ; scanlines in the view, one span entry each
PALBYTES   EQU 24               ; SizeOf(TPalette24): two 4-bit levels per byte
DACFIRST   EQU 16               ; DAC entry of DACTAB's first triple; 16 and 17 stay SetDefaultPalette's

VIDEOSEG   EQU 0A000h           ; EGA/VGA display memory
SHADOWSEG  EQU 0A200h           ; EGA memory past the visible page, where rows are built
SEQINDEX   EQU 3C4h             ; sequencer index; register 2 is the map mask
GCINDEX    EQU 3CEh             ; graphics controller index; register 5 is the mode
DACWRITE   EQU 3C8h             ; DAC write index, data at the next port
STATUS1    EQU 3DAh             ; input status 1; bit 3 is vertical retrace

; TImgBuf (raster.pas) fields the blitters touch
imgHeight    EQU 0              ; scanlines
imgWidth     EQU 2              ; 8-pixel cells
imgFrameSize EQU 21h            ; bytes in one tile's frame
imgTransp    EQU 28h            ; far pointer to the mask plane, nil when opaque
imgData      EQU 2Ch            ; the pixels, inline after the header

; The cell and clipping blitters share one frame, and CopyRows / MaskRows / KeyRows run inside it.
; Arguments:
argDest    EQU 4                ; dest: PImgBuf
argGfx     EQU 8                ; gfx:  PImgBuf, the tile set
cellTile   EQU 0Ch              ; cell blitters: tileIdx
cellY      EQU 0Eh              ; cell blitters: screenY, in 8-scanline cells
cellX      EQU 10h              ; cell blitters: screenX, in cells
cellKey    EQU 12h              ; BlitCellVgaKeyed: the transparent color
clipFlag   EQU 0Ch              ; clipping blitters: bit 0 masked, bit 2 save what is covered
clipTile   EQU 0Eh              ; clipping blitters: tileIdx
clipY      EQU 10h              ; clipping blitters: screenY, may be negative
clipX      EQU 12h              ; clipping blitters: screenX, may be negative
argSave    EQU 14h              ; clipping blitters: saveUnder: PImgBuf
clipKey    EQU 18h              ; BlitClippedVga: the transparent color
; Locals, in a 1Eh-byte frame:
keyColor   EQU -2               ; byte
maskPtr    EQU -6               ; far pointer, copy of gfx^.transp
spanLeft   EQU -8               ; the screen byte recorded into SPANSCREENOFS
viewRow    EQU -0Ah             ; first scanline, indexes the span tables
rowCount   EQU -0Ch             ; scanlines to draw
destOff    EQU -0Eh             ; running offset into dest^.data
srcOff     EQU -10h             ; running offset into gfx^.data (and the mask)
rowBytes   EQU -12h             ; bytes copied per scanline
destSkip   EQU -14h             ; dest bytes right of the tile
leftBytes  EQU -16h             ; dest bytes left of the tile
skipRight  EQU -18h             ; tile bytes clipped off the right
skipLeft   EQU -1Ah             ; tile bytes clipped off the left
saveFlag   EQU -1Ch             ; byte: copy the covered pixels to saveUnder first
saveOff    EQU -1Eh             ; running offset into saveUnder^.data

DATA SEGMENT WORD PUBLIC                ; empty: gives `mov ax,DATA` DGROUP's paragraph
DATA ENDS

CODE SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE
        PUBLIC  BlitCellCga, BlitCellCgaMasked, BlitClippedCga
        PUBLIC  BlitCellEga, BlitCellEgaMasked, BlitClippedEga
        PUBLIC  BlitCellTandy, BlitCellTandyMasked, BlitClippedTandy
        PUBLIC  BlitCellVga, BlitCellVgaKeyed, BlitClippedVga
        PUBLIC  PrepareVgaPaletteImpl, SetPaletteEntry, SetDefaultPalette, FlushEga
        PUBLIC  ShowPicEgaImpl, WriteEgaCellsImpl, UnpackFivePlanesImpl

; The tile blitters.  The cell blitters, BlitCellCga through BlitCellVgaKeyed, draw tile tileIdx
; of gfx into dest at cell (screenX, screenY), whole or (the Masked ones) through the tile's mask.
; The clipping blitters, BlitClippedCga through BlitClippedVga, do the same for a tile that may
; hang off dest's edges, and can first save the pixels it covers into saveUnder.  The display
; mode fixes the bytes per 8-pixel cell: CGA 2, EGA 4, Tandy 4, VGA 8.  VGA has no mask plane;
; BlitCellVgaKeyed and BlitClippedVga key on a color instead.  BlitTileCell and BlitTileClipped
; (raster.pas) choose the entry by displayMode.

BlitCellCga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh                  ; the 1Eh-byte frame
        sub     sp,1Eh                  ; again: the frame is reserved twice
        push    ss                      ; SS and DS are restored before the return
        push    ds
        cld                             ; CopyRows' rep movsb copies forward
        les     di,[bp+argDest]         ; ES:DI = dest
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl                   ; viewRow = screenY * 8, the first scanline
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax         ; destOff = viewRow * dest width, in cells
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax       ; leftBytes = the dest cells left of the tile
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]          ; ES:DI = the tile set
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax        ; destSkip = the dest cells right of the tile
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1 ; spanLeft = the screen byte: 2 per cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = tile width * 2
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax        ; rowCount = the tile's scanlines
        shl     word ptr [bp+leftBytes],1 ; leftBytes and destSkip: cells to bytes
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax          ; srcOff = frameSize * tileIdx, the tile's frame
        shl     word ptr [bp+destOff],1 ; destOff to bytes
        mov     bx,[bp+viewRow]         ; BX = the first span-table row
        mov     cx,[bp+rowCount]        ; CX = the rows to draw
        mov     byte ptr [bp+saveFlag],0 ; nothing to save, nothing clipped
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    CopyRows                ; rowCount rows from scanline viewRow
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh                     ; pops the 14 bytes of arguments
BlitCellCga ENDP

; BlitCellCgaMasked: BlitCellCga through the tile's mask, which it records in maskPtr.
BlitCellCgaMasked PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        mov     ax,es:[di+imgTransp]    ; maskPtr = the tile set's mask plane
        mov     [bp+maskPtr],ax
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    MaskRows                ; through the mask; MaskRows needs no cld
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BlitCellCgaMasked ENDP

; BlitClippedCga: the tile may start left of or above dest (a negative screenX or screenY) and run
; past its right or bottom edge; only the part on dest is drawn.
BlitClippedCga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        push    ds                      ; DGROUP, kept past the lds below
        lds     si,[bp+argGfx]          ; DS:SI = the tile set
        les     di,[bp+argDest]         ; ES:DI = dest
        mov     ax,[si+imgTransp]       ; maskPtr = the tile set's mask plane
        mov     [bp+maskPtr],ax
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]
        cmp     ax,8000h                ; a negative x (unsigned above 8000h)
        jbe     @@xOnScreen
        mov     [bp+skipLeft],ax
        neg     word ptr [bp+skipLeft]  ; skipLeft = the tile cells left of dest's edge
        mov     word ptr [bp+leftBytes],0
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0
        mov     [bp+leftBytes],ax       ; leftBytes = x, the dest cells left of the tile
@@checkRight:
        add     ax,[si+imgWidth]        ; AX = x + tile width, the tile's right edge
        cmp     es:[di+imgWidth],ax
        jae     @@rightFits             ; dest is at least that wide
        sub     ax,es:[di+imgWidth]
        mov     [bp+skipRight],ax       ; skipRight = the tile cells past dest's right edge
        mov     word ptr [bp+destSkip],0
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax        ; destSkip = dest width - x - tile width
@@clipTop:
        mov     ax,[bp+clipY]
        cmp     ax,8000h                ; a negative y
        jbe     @@yOnScreen
        neg     ax
        mov     cx,3
        shl     ax,cl                   ; the scanlines above dest's top edge
        mov     bx,[si+imgHeight]
        mov     [bp+rowCount],bx
        sub     [bp+rowCount],ax        ; rowCount = the tile's scanlines below the edge
        mov     bx,[si+imgWidth]
        mul     bx
        mov     [bp+srcOff],ax          ; srcOff = the hidden scanlines' cells
        mov     word ptr [bp+destOff],0
        mov     word ptr [bp+viewRow],0
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0
        mov     cx,3
        shl     ax,cl
        mov     [bp+viewRow],ax         ; viewRow = y * 8
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax         ; destOff = viewRow * dest width, in cells
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]
        cmp     ax,es:[di+imgHeight]
        jbe     @@bottomFits            ; the tile ends above dest's bottom
        mov     ax,es:[di+imgHeight]
        sub     ax,[bp+viewRow]
        mov     [bp+rowCount],ax        ; rowCount = the scanlines left above the bottom
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]
        jb      @@offView               ; the tile is wholly left of dest
        cmp     ax,[bp+skipRight]
        jb      @@offView               ; or wholly right of it
        mov     ax,[bp+srcOff]
        cmp     ax,[si+imgFrameSize]
        ja      @@offView               ; srcOff, still in cells, beyond the frame size
        mov     ax,[bp+destOff]
        cmp     ax,es:[di+imgFrameSize]
        ja      @@offView               ; or destOff beyond dest's
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]
        ja      @@offView               ; rowCount went negative: wholly above or below
        jmp     @@draw
@@offView:
        pop     ds                      ; DGROUP again
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h                     ; pops the 20 bytes of arguments
@@draw:
        mov     ax,[bp+leftBytes]
        shl     ax,1                    ; the counts from cells to bytes, 2 per cell
        mov     [bp+leftBytes],ax
        mov     [bp+spanLeft],ax        ; spanLeft = the screen byte
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]
        sub     ax,[bp+skipRight]
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = the visible cells, in bytes
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]
        mov     [bp+saveOff],ax         ; saveOff = the first covered byte in saveUnder
        mov     ax,[si+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+clipTile]
        mul     bx
        add     [bp+srcOff],ax          ; srcOff += frameSize * tileIdx
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        pop     ds                      ; DS = DGROUP for the span tables
        test    byte ptr [bp+clipFlag],1 ; bit 0: masked
        jne     @@masked
        call    CopyRows                ; unmasked
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@masked:
        mov     byte ptr [bp+saveFlag],0
        test    byte ptr [bp+clipFlag],4 ; bit 2: save what is covered first
        je      @@noSave
        mov     byte ptr [bp+saveFlag],1
@@noSave:
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
BlitClippedCga ENDP

; The EGA, Tandy and VGA blitters repeat the CGA three at their own bytes per cell: each
; cells-to-bytes scaling is two shl's for EGA and Tandy (4 a cell) and three for VGA (8), where
; CGA has one.  EGA records spanLeft in cells, before the scaling, because an EGA screen byte
; holds one cell; the others record bytes.  BlitCellVgaKeyed and BlitClippedVga also store the
; transparent color and call KeyRows.
BlitCellEga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft = screenX: an EGA byte is one cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = tile width * 4
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BlitCellEga ENDP

BlitCellEgaMasked PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft = screenX: an EGA byte is one cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        mov     ax,es:[di+imgTransp]    ; maskPtr = the tile set's mask plane
        mov     [bp+maskPtr],ax
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BlitCellEgaMasked ENDP

BlitClippedEga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        push    ds
        lds     si,[bp+argGfx]
        les     di,[bp+argDest]
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]
        cmp     ax,8000h
        jbe     @@xOnScreen
        mov     [bp+skipLeft],ax
        neg     word ptr [bp+skipLeft]
        mov     word ptr [bp+leftBytes],0
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0
        mov     [bp+leftBytes],ax
@@checkRight:
        add     ax,[si+imgWidth]
        cmp     es:[di+imgWidth],ax
        jae     @@rightFits
        sub     ax,es:[di+imgWidth]
        mov     [bp+skipRight],ax
        mov     word ptr [bp+destSkip],0
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax
@@clipTop:
        mov     ax,[bp+clipY]
        cmp     ax,8000h
        jbe     @@yOnScreen
        neg     ax
        mov     cx,3
        shl     ax,cl
        mov     bx,[si+imgHeight]
        mov     [bp+rowCount],bx
        sub     [bp+rowCount],ax
        mov     bx,[si+imgWidth]
        mul     bx
        mov     [bp+srcOff],ax
        mov     word ptr [bp+destOff],0
        mov     word ptr [bp+viewRow],0
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0
        mov     cx,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]
        cmp     ax,es:[di+imgHeight]
        jbe     @@bottomFits
        mov     ax,es:[di+imgHeight]
        sub     ax,[bp+viewRow]
        mov     [bp+rowCount],ax
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]
        jb      @@offView
        cmp     ax,[bp+skipRight]
        jb      @@offView
        mov     ax,[bp+srcOff]
        cmp     ax,[si+imgFrameSize]
        ja      @@offView
        mov     ax,[bp+destOff]
        cmp     ax,es:[di+imgFrameSize]
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]
        ja      @@offView
        jmp     @@draw
@@offView:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@draw:
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax        ; spanLeft = x in cells, before the scaling
        mov     ax,[bp+leftBytes]
        shl     ax,1
        shl     ax,1                    ; the counts from cells to bytes, 4 per cell
        mov     [bp+leftBytes],ax
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]
        sub     ax,[bp+skipRight]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]
        mov     [bp+saveOff],ax
        mov     ax,[si+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+clipTile]
        mul     bx
        add     [bp+srcOff],ax
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        pop     ds
        test    byte ptr [bp+clipFlag],1
        jne     @@masked
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@masked:
        mov     byte ptr [bp+saveFlag],0
        test    byte ptr [bp+clipFlag],4
        je      @@noSave
        mov     byte ptr [bp+saveFlag],1
@@noSave:
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
BlitClippedEga ENDP

BlitCellTandy PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1 ; spanLeft = the screen byte: 4 per cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BlitCellTandy ENDP

BlitCellTandyMasked PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1 ; spanLeft = the screen byte: 4 per cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        mov     ax,es:[di+imgTransp]    ; maskPtr = the tile set's mask plane
        mov     [bp+maskPtr],ax
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BlitCellTandyMasked ENDP

BlitClippedTandy PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        push    ds
        lds     si,[bp+argGfx]
        les     di,[bp+argDest]
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]
        cmp     ax,8000h
        jbe     @@xOnScreen
        mov     [bp+skipLeft],ax
        neg     word ptr [bp+skipLeft]
        mov     word ptr [bp+leftBytes],0
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0
        mov     [bp+leftBytes],ax
@@checkRight:
        add     ax,[si+imgWidth]
        cmp     es:[di+imgWidth],ax
        jae     @@rightFits
        sub     ax,es:[di+imgWidth]
        mov     [bp+skipRight],ax
        mov     word ptr [bp+destSkip],0
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax
@@clipTop:
        mov     ax,[bp+clipY]
        cmp     ax,8000h
        jbe     @@yOnScreen
        neg     ax
        mov     cx,3
        shl     ax,cl
        mov     bx,[si+imgHeight]
        mov     [bp+rowCount],bx
        sub     [bp+rowCount],ax
        mov     bx,[si+imgWidth]
        mul     bx
        mov     [bp+srcOff],ax
        mov     word ptr [bp+destOff],0
        mov     word ptr [bp+viewRow],0
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0
        mov     cx,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]
        cmp     ax,es:[di+imgHeight]
        jbe     @@bottomFits
        mov     ax,es:[di+imgHeight]
        sub     ax,[bp+viewRow]
        mov     [bp+rowCount],ax
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]
        jb      @@offView
        cmp     ax,[bp+skipRight]
        jb      @@offView
        mov     ax,[bp+srcOff]
        cmp     ax,[si+imgFrameSize]
        ja      @@offView
        mov     ax,[bp+destOff]
        cmp     ax,es:[di+imgFrameSize]
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]
        ja      @@offView
        jmp     @@draw
@@offView:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@draw:
        mov     ax,[bp+leftBytes]
        shl     ax,1
        shl     ax,1
        mov     [bp+leftBytes],ax
        mov     [bp+spanLeft],ax        ; spanLeft = the screen byte: 4 per cell
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]
        sub     ax,[bp+skipRight]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]
        mov     [bp+saveOff],ax
        mov     ax,[si+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+clipTile]
        mul     bx
        add     [bp+srcOff],ax
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        pop     ds
        test    byte ptr [bp+clipFlag],1
        jne     @@masked
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@masked:
        mov     byte ptr [bp+saveFlag],0
        test    byte ptr [bp+clipFlag],4
        je      @@noSave
        mov     byte ptr [bp+saveFlag],1
@@noSave:
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
BlitClippedTandy ENDP

BlitCellVga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1 ; spanLeft = the screen byte: 8 per cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax        ; rowBytes = tile width * 8
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BlitCellVga ENDP

BlitCellVgaKeyed PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        mov     al,[bp+cellKey]         ; the transparent color
        mov     [bp+keyColor],al        ; into the frame, where KeyRows reads it
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1 ; spanLeft = the screen byte: 8 per cell
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        mov     ax,es:[di+imgTransp]    ; copied, but KeyRows reads no mask
        mov     [bp+maskPtr],ax
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    KeyRows                 ; keyed on the color instead of a mask
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     10h                     ; pops the 16 bytes of arguments
BlitCellVgaKeyed ENDP

BlitClippedVga PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        push    ds
        mov     al,[bp+clipKey]         ; the transparent color
        mov     [bp+keyColor],al        ; into the frame, where KeyRows reads it
        lds     si,[bp+argGfx]
        les     di,[bp+argDest]
        mov     ax,[si+imgTransp]       ; copied, but KeyRows reads no mask
        mov     [bp+maskPtr],ax
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]
        cmp     ax,8000h
        jbe     @@xOnScreen
        mov     [bp+skipLeft],ax
        neg     word ptr [bp+skipLeft]
        mov     word ptr [bp+leftBytes],0
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0
        mov     [bp+leftBytes],ax
@@checkRight:
        add     ax,[si+imgWidth]
        cmp     es:[di+imgWidth],ax
        jae     @@rightFits
        sub     ax,es:[di+imgWidth]
        mov     [bp+skipRight],ax
        mov     word ptr [bp+destSkip],0
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax
@@clipTop:
        mov     ax,[bp+clipY]
        cmp     ax,8000h
        jbe     @@yOnScreen
        neg     ax
        mov     cx,3
        shl     ax,cl
        mov     bx,[si+imgHeight]
        mov     [bp+rowCount],bx
        sub     [bp+rowCount],ax
        mov     bx,[si+imgWidth]
        mul     bx
        mov     [bp+srcOff],ax
        mov     word ptr [bp+destOff],0
        mov     word ptr [bp+viewRow],0
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0
        mov     cx,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]
        cmp     ax,es:[di+imgHeight]
        jbe     @@bottomFits
        mov     ax,es:[di+imgHeight]
        sub     ax,[bp+viewRow]
        mov     [bp+rowCount],ax
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]
        jb      @@offView
        cmp     ax,[bp+skipRight]
        jb      @@offView
        mov     ax,[bp+srcOff]
        cmp     ax,[si+imgFrameSize]
        ja      @@offView
        mov     ax,[bp+destOff]
        cmp     ax,es:[di+imgFrameSize]
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]
        ja      @@offView
        jmp     @@draw
@@offView:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h                     ; pops the 22 bytes of arguments
@@draw:
        mov     ax,[bp+leftBytes]
        shl     ax,1
        shl     ax,1
        shl     ax,1
        mov     [bp+leftBytes],ax
        mov     [bp+spanLeft],ax        ; spanLeft = the screen byte: 8 per cell
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]
        sub     ax,[bp+skipRight]
        shl     ax,1
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]
        mov     [bp+saveOff],ax
        mov     ax,[si+imgFrameSize]
        xor     bx,bx
        mov     bl,[bp+clipTile]
        mul     bx
        add     [bp+srcOff],ax
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        pop     ds
        test    byte ptr [bp+clipFlag],1
        jne     @@masked
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h
@@masked:
        mov     byte ptr [bp+saveFlag],0
        test    byte ptr [bp+clipFlag],4
        je      @@noSave
        mov     byte ptr [bp+saveFlag],1
@@noSave:
        call    KeyRows                 ; the masked flag selects the keyed loop
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h
BlitClippedVga ENDP

; The scanline loops, entered from a cell or clipping blitter's frame with BX = viewRow and CX = rowCount
; and DS = DGROUP.  Each marks its row dirty and widens the row's dirty range for FlushView.
; CopyRows copies; MaskRows ANDs the mask in and ORs the tile over it; KeyRows skips every
; tile byte equal to keyColor.  On an equal offset CopyRows rewrites the row's first and last
; entries and the others leave them (ja/jb against jae/jbe).
; Note: CopyRows never adds skipLeft or skipRight to srcOff, so a tile clipped at a side and drawn
; unmasked is read at the clipped width's stride.

CopyRows PROC NEAR
@@row:
        mov     byte ptr [bx+SPANACTIVE],1 ; mark scanline BX dirty
        shl     bx,1                    ; BX indexes the word tables
        mov     ax,[bp+leftBytes]
        add     [bp+destOff],ax         ; step over dest's bytes left of the tile
        mov     ax,[bp+destOff]
        cmp     ax,[bx+SPANFIRSTOFS]
        ja      @@spanKnown             ; a new first byte when at or below the one recorded
        mov     [bx+SPANFIRSTOFS],ax
        mov     ax,[bp+spanLeft]
        mov     [bx+SPANSCREENOFS],ax   ; with the span's left screen byte
@@spanKnown:
        push    ds
        lds     si,[bp+argGfx]          ; DS:SI = the tile's row in gfx^.data
        les     di,[bp+argDest]         ; ES:DI = its place in dest^.data
        add     si,imgData
        add     si,[bp+srcOff]
        add     di,imgData
        add     di,[bp+destOff]
        push    cx
        mov     cx,[bp+rowBytes]
        rep movsb                       ; copy the row
        pop     cx
        pop     ds                      ; DGROUP again
        mov     ax,[bp+rowBytes]
        add     [bp+srcOff],ax
        add     [bp+destOff],ax
        mov     ax,[bp+destOff]
        dec     ax
        cmp     ax,[bx+SPANLASTOFS]
        jb      @@endKnown              ; a new last byte when at or above the one recorded
        mov     [bx+SPANLASTOFS],ax
@@endKnown:
        mov     ax,[bp+destSkip]
        add     [bp+destOff],ax         ; step over dest's bytes right of the tile
        shr     bx,1
        inc     bx                      ; next scanline
        loop    @@row
        ret
CopyRows ENDP

MaskRows PROC NEAR
@@row:
        mov     byte ptr [bx+SPANACTIVE],1 ; mark scanline BX dirty
        shl     bx,1                    ; BX indexes the word tables
        mov     ax,[bp+skipLeft]
        add     [bp+srcOff],ax          ; skip the tile bytes left of dest's edge
        mov     ax,[bp+leftBytes]
        add     [bp+destOff],ax
        mov     ax,[bp+destOff]
        cmp     ax,[bx+SPANFIRSTOFS]
        jae     @@spanKnown             ; a new first byte only when below the one recorded
        mov     [bx+SPANFIRSTOFS],ax
        mov     ax,[bp+spanLeft]
        mov     [bx+SPANSCREENOFS],ax
@@spanKnown:
        push    ds
        les     di,[bp+argDest]         ; ES:DI = the row's place in dest, less imgData
        add     di,[bp+destOff]
        push    cx
        mov     cx,[bp+rowBytes]        ; CX = bytes in the row
@@pixel:
        cmp     byte ptr [bp+saveFlag],0 ; saveFlag: copy the covered byte to saveUnder first
        je      @@noSave
        lds     si,[bp+argSave]
        add     si,[bp+saveOff]
        mov     al,es:[di+imgData]
        mov     [si+imgData],al
@@noSave:
        lds     si,[bp+maskPtr]         ; DS:SI = the mask byte
        add     si,[bp+srcOff]
        mov     ah,[si]                 ; AH = mask: 1 bits let dest show through
        lds     si,[bp+argGfx]
        add     si,[bp+srcOff]
        mov     al,[si+imgData]         ; AL = the tile byte
        and     es:[di+imgData],ah      ; clear what the tile covers
        or      es:[di+imgData],al      ; and draw it
        inc     word ptr [bp+srcOff]
        inc     word ptr [bp+saveOff]
        inc     word ptr [bp+destOff]
        inc     di
        loop    @@pixel
        pop     cx
        pop     ds                      ; DGROUP again
        mov     ax,[bp+destOff]
        dec     ax
        cmp     ax,[bx+SPANLASTOFS]
        jbe     @@endKnown              ; a new last byte only when above the one recorded
        mov     [bx+SPANLASTOFS],ax
@@endKnown:
        mov     ax,[bp+destSkip]
        add     [bp+destOff],ax
        mov     ax,[bp+skipRight]
        add     [bp+srcOff],ax          ; skip the tile bytes past dest's right edge
        add     [bp+saveOff],ax
        shr     bx,1
        inc     bx
        dec     cx
        je      @@done
        jmp     @@row                   ; next scanline: dec/je/jmp, as loop cannot reach
@@done:
        ret
MaskRows ENDP

KeyRows PROC NEAR
@@row:
        mov     byte ptr [bx+SPANACTIVE],1 ; mark scanline BX dirty
        shl     bx,1                    ; BX indexes the word tables
        mov     ax,[bp+skipLeft]
        add     [bp+srcOff],ax          ; skip the tile bytes left of dest's edge
        mov     ax,[bp+leftBytes]
        add     [bp+destOff],ax
        mov     ax,[bp+destOff]
        cmp     ax,[bx+SPANFIRSTOFS]
        jae     @@spanKnown             ; a new first byte only when below the one recorded
        mov     [bx+SPANFIRSTOFS],ax
        mov     ax,[bp+spanLeft]
        mov     [bx+SPANSCREENOFS],ax
@@spanKnown:
        push    ds
        les     di,[bp+argDest]
        add     di,[bp+destOff]
        push    cx
        mov     cx,[bp+rowBytes]
@@pixel:
        cmp     byte ptr [bp+saveFlag],0 ; saveFlag: copy the covered byte to saveUnder first
        je      @@noSave
        lds     si,[bp+argSave]
        add     si,[bp+saveOff]
        mov     al,es:[di+imgData]
        mov     [si+imgData],al
@@noSave:
        lds     si,[bp+argGfx]
        add     si,[bp+srcOff]
        mov     al,[si+imgData]
        cmp     al,[bp+keyColor]        ; the transparent color leaves dest as it is
        je      @@keyed
        mov     es:[di+imgData],al      ; any other color is drawn
@@keyed:
        inc     word ptr [bp+srcOff]
        inc     word ptr [bp+saveOff]
        inc     word ptr [bp+destOff]
        inc     di
        loop    @@pixel
        pop     cx
        pop     ds                      ; DGROUP again
        mov     ax,[bp+destOff]
        dec     ax
        cmp     ax,[bx+SPANLASTOFS]
        jbe     @@endKnown              ; a new last byte only when above the one recorded
        mov     [bx+SPANLASTOFS],ax
@@endKnown:
        mov     ax,[bp+destSkip]
        add     [bp+destOff],ax
        mov     ax,[bp+skipRight]
        add     [bp+srcOff],ax          ; skip the tile bytes past dest's right edge
        add     [bp+saveOff],ax
        shr     bx,1
        inc     bx
        dec     cx
        je      @@done
        jmp     @@row                   ; next scanline: dec/je/jmp, as loop cannot reach
@@done:
        ret
KeyRows ENDP

; PrepareVgaPaletteImpl: when a picture palette is staged (PALFRAME nonzero) and differs from
; the one last shown, expand its 4-bit levels into DACTAB and program DAC entries 18..31 once
; vertical retrace is active.  Its first 24 levels are the bytes' low nibbles, the next 24
; their high nibbles.  Entries 16 and 17 are SetDefaultPalette's.

PrepareVgaPaletteImpl PROC NEAR
        push    ss                      ; SS and DS are restored before the return
        push    ds
        cmp     word ptr ds:[PALFRAME],0 ; no picture frame staged:
        je      @@done                  ; nothing to upload
        xor     bx,bx                   ; BX = palette byte
        mov     cl,2                    ; dead store: CL is set again below
@@compare:
        mov     al,[bx+PALWORK]
        cmp     al,[bx+PALSHOWN]
        jne     @@changed               ; a byte differs: expand and upload
        inc     bx
        cmp     bx,PALBYTES
        jb      @@compare
        jmp     @@done                  ; all 24 equal: the DAC already shows it
@@changed:
        xor     bx,bx
        mov     cl,2                    ; CL = 2: a 4-bit level times 4 is a 6-bit DAC level
@@expand:
        mov     al,[bx+PALWORK]
        mov     [bx+PALSHOWN],al        ; remember what the DAC will show
        and     al,0Fh
        shl     al,cl
        mov     [bx+DACTAB],al          ; the low level into the first 24 DAC bytes
        mov     al,[bx+PALWORK]
        and     al,0F0h
        shr     al,cl
        mov     [bx+DACTAB+PALBYTES],al ; the high level into the next 24
        inc     bx
        cmp     bx,PALBYTES
        jb      @@expand
        push    ds                      ; reloads DS with DGROUP, which it already holds
        mov     ax,DATA
        mov     ds,ax
        mov     si,DACTAB+2*3           ; DS:SI = entry 18's levels; 16 and 17 are SetDefaultPalette's
        mov     cx,16-2                 ; CX = entries 18..31
        cld                             ; lodsb walks forward
@@retrace:
        mov     dx,STATUS1
        in      al,dx
        test    al,8                    ; bit 3: vertical retrace
        je      @@retrace               ; wait until retrace is active, then load every entry
        mov     dx,DACWRITE
        mov     bl,DACFIRST+2           ; BL = DAC entry
@@dacEntry:
        mov     al,bl
        out     dx,al                   ; select the entry
        inc     dx                      ; DX = 3C9h, DAC data
        lodsb
        out     dx,al                   ; red
        lodsb
        out     dx,al                   ; green
        lodsb
        out     dx,al                   ; blue
        inc     bl
        dec     dx                      ; DX = the write index again
        loop    @@dacEntry
        pop     ds
@@done:
        pop     ds
        pop     ss
        ret
PrepareVgaPaletteImpl ENDP

; SetPaletteEntry(index, red, green, blue): one DAC entry through the video BIOS.  CbtMap calls
; it.

SetPaletteEntry PROC FAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        mov     bx,[bp+0Ch]             ; BX = DAC entry
        mov     ax,1010h                ; INT 10h AX=1010h: set one DAC register
        mov     dh,[bp+0Ah]             ; DH = red
        mov     ch,[bp+8]               ; CH = green
        mov     cl,[bp+6]               ; CL = blue, each 0..3Fh
        int     10h                     ; video BIOS
        pop     ds
        pop     ss
        pop     bp
        ret     8                       ; FAR: pops the 8 bytes of arguments
SetPaletteEntry ENDP

; SetDefaultPalette: DAC entries 16 and 17, the two colors no picture palette overrides.
; GameInit calls it in mode 3.

SetDefaultPalette PROC FAR
        push    ss
        push    ds
        mov     bx,DACFIRST             ; entry 16: red 3Ch, green 30h, blue 10h
        mov     ax,1010h
        mov     dh,3Ch
        mov     ch,30h
        mov     cl,10h
        int     10h                     ; video BIOS: set one DAC register
        mov     bx,DACFIRST+1           ; entry 17: red 3Ch, green 24h, blue 10h
        mov     ax,1010h
        mov     dh,3Ch
        mov     ch,24h
        mov     cl,10h
        int     10h
        pop     ds
        pop     ss
        ret                             ; FAR, no arguments
SetDefaultPalette ENDP

; FlushEga(data): FlushView's mode 1.  Each dirty view row's span of the picture's pixels, data
; (four plane bytes per cell, interleaved), is written plane by plane into SHADOWSEG, then
; latch-copied to the visible page in write mode 1.  It leaves the span tables for FlushView to
; reset.

FlushEga PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        cld                             ; movsb walks forward
        mov     bx,-1                   ; BX = view scanline, from 0 after the inc
@@nextRow:
        inc     bx
        cmp     bx,VIEWROWS-1
        jbe     @@flushRow              ; rows 0..VIEWROWS-1
        pop     ds
        pop     ss
        pop     bp
        ret     4                       ; every row done
rowDest dw      0                       ; data, not code: the row's A000h offset
@@flushRow:
        mov     al,[bx+SPANACTIVE]
        or      al,al                   ; row untouched since the last flush:
        je      @@nextRow               ; skip it
        mov     ax,SHADOWSEG
        mov     es,ax                   ; ES = the off-screen page the row is built in
        mov     dx,SEQINDEX
        mov     al,2
        out     dx,al                   ; sequencer register 2, the map mask
        inc     dx                      ; DX = 3C5h, sequencer data
        push    bx
        shl     bx,1
        mov     di,[bx+SPANSCREENOFS]   ; DI = the span's left screen byte
        inc     di                      ; the view starts one byte in from the screen's left
        mov     ax,di
        add     di,[bx+EGAROWS+VIEWTOP*2] ; DI = the span's start in the SHADOWSEG row
        add     ax,[bx+EGAROWS+VIEWTOP*2] ; and the same offset for the visible page
        mov     cs:rowDest,ax           ; kept in CS: DS, ES, BP and DI are all in use below
        mov     cx,[bx+SPANLASTOFS]     ; last dirty byte
        mov     si,[bx+SPANFIRSTOFS]    ; first dirty byte, picture offsets
        sub     cx,si
        inc     cx
        shr     cx,1
        shr     cx,1                    ; CX = the span's cells: four plane bytes each
        push    ds
        lds     bx,[bp+4]               ; DS:BX = data, the picture's pixels
        add     bx,si
        mov     si,bx                   ; DS:SI = plane 0 of the first dirty cell
        push    bp
        mov     bp,di                   ; BP = the span's start in SHADOWSEG, for each plane
        mov     ah,cl                   ; AH = cell count, reloaded for each plane
        mov     al,1
        out     dx,al                   ; map mask: plane 0 only
@@plane0:
        movsb                           ; one plane byte per cell
        add     si,3                    ; over the other planes' bytes
        loop    @@plane0
        inc     bx                      ; the next plane's bytes start one further on
        mov     si,bx
        mov     di,bp
        mov     al,2
        out     dx,al                   ; plane 1
        mov     cl,ah
@@plane1:
        movsb
        add     si,3
        loop    @@plane1
        inc     bx
        mov     si,bx
        mov     di,bp
        mov     al,4
        out     dx,al                   ; plane 2
        mov     cl,ah
@@plane2:
        movsb
        add     si,3
        loop    @@plane2
        inc     bx
        mov     si,bx
        mov     di,bp
        mov     al,8
        out     dx,al                   ; plane 3
        mov     cl,ah
@@plane3:
        movsb
        add     si,3
        loop    @@plane3
        mov     al,0Fh
        out     dx,al                   ; map mask: all four planes again
        mov     dx,GCINDEX
        mov     al,5
        out     dx,al                   ; graphics controller register 5, the mode
        inc     dx
        mov     al,1
        out     dx,al                   ; write mode 1: each write stores the latches
        mov     bx,VIDEOSEG
        mov     es,bx                   ; ES = the visible page
        mov     bx,SHADOWSEG
        mov     ds,bx                   ; DS = SHADOWSEG
        mov     si,bp                   ; DS:SI = the built span
        mov     di,cs:rowDest           ; ES:DI = its place on screen
        mov     cl,ah
        rep movsb                       ; latch copy: each byte moves all four planes
        xor     al,al
        out     dx,al                   ; write mode 0 again
        pop     bp                      ; the frame again
        pop     ds                      ; DGROUP
        pop     bx                      ; the row
        jmp     @@nextRow
FlushEga ENDP

; ShowPicEgaImpl: Blit's ShowPic in EGA mode.  height rows from screenRow on, each width cells
; of four interleaved plane bytes from data, to A000h at byte column destOff.

ShowPicEgaImpl PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        cld
        mov     ax,VIDEOSEG
        mov     es,ax                   ; ES = EGA display memory
        mov     dx,SEQINDEX
        mov     al,2
        out     dx,al                   ; sequencer register 2, the map mask
        inc     dx                      ; DX = 3C5h, sequencer data
        mov     si,[bp+0Ch]             ; SI = data's offset; its segment is loaded per row
        mov     bx,[bp+0Ah]
        shl     bx,1                    ; BX = screenRow, indexing EGAROWS words
        mov     cx,[bp+8]               ; CX = height, the rows left
@@row:
        push    cx
        mov     cx,[bp+4]               ; CX = width, the cells in this row
        mov     di,[bx+EGAROWS]         ; DI = the scanline's offset in A000h
        add     di,[bp+6]               ; plus destOff, the first byte column
        push    ds
        mov     ds,[bp+0Eh]             ; DS:SI = the next cell of data
@@cell:
        mov     al,1
        out     dx,al                   ; plane 0
        lodsb
        mov     es:[di],al              ; same screen byte for all four planes
        mov     al,2
        out     dx,al                   ; plane 1
        lodsb
        mov     es:[di],al
        mov     al,4
        out     dx,al                   ; plane 2
        lodsb
        mov     es:[di],al
        mov     al,8
        out     dx,al                   ; plane 3
        lodsb
        stosb                           ; the last plane also steps DI to the next byte
        loop    @@cell
        pop     ds                      ; DGROUP, for the next row's EGAROWS read
        pop     cx
        add     bx,2                    ; next scanline
        loop    @@row
        mov     al,0Fh
        out     dx,al                   ; map mask: all four planes again
        pop     ds
        pop     ss
        pop     bp
        ret     0Ch                     ; pops the 12 bytes of arguments
ShowPicEgaImpl ENDP

; WriteEgaCellsImpl: count cells of four interleaved plane bytes to EGA memory at dst, one
; byte per plane; Blit writes a decoded picture row with it.

WriteEgaCellsImpl PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        cld
        mov     dx,SEQINDEX
        mov     al,2
        out     dx,al
        inc     dx                      ; DX = 3C5h, sequencer data; register 2 selected
        lds     si,[bp+0Ah]             ; DS:SI = src, four plane bytes per cell
        les     di,[bp+6]               ; ES:DI = dst, in display memory
        mov     cx,[bp+4]               ; CX = count, the cells
@@cell:
        mov     al,1
        out     dx,al                   ; plane 0
        lodsb
        mov     es:[di],al
        mov     al,2
        out     dx,al                   ; plane 1
        lodsb
        mov     es:[di],al
        mov     al,4
        out     dx,al                   ; plane 2
        lodsb
        mov     es:[di],al
        mov     al,8
        out     dx,al                   ; plane 3
        movsb                           ; the last plane also steps DI
        loop    @@cell
        mov     al,0Fh
        out     dx,al                   ; map mask: all four planes again
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; pops the 10 bytes of arguments
WriteEgaCellsImpl ENDP

; UnpackFivePlanesImpl: five bit planes of count bytes each, back to back at src, become count*8
; bytes of color 0..31 at dst; Blit unpacks picture data with it.  The plane offsets are
; summed in BL, so count*4 must stay below 100h.

UnpackFivePlanesImpl PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        cld
        les     di,[bp+6]               ; ES:DI = dst, one byte per pixel
        mov     cx,[bp+4]
        lds     si,[bp+0Ah]             ; DS:SI = src, plane 0's first byte
        mov     dx,cx                   ; DX = count, the bytes in each plane
        shl     cx,1
        shl     cx,1
        shl     cx,1                    ; CX = count * 8 pixels
        mov     ah,80h                  ; AH = the pixel's bit, leftmost first
        xor     bh,bh                   ; BX = BL: plane offsets are formed in a byte
@@pixel:
        xor     al,al
        test    [si],ah                 ; plane 0: color bit 0
        je      @@plane1
        inc     al
@@plane1:
        mov     bl,dl                   ; BL = count: plane 1 lies count bytes on
        test    [bx+si],ah
        je      @@plane2
        or      al,2
@@plane2:
        add     bl,dl                   ; the next plane, count bytes further
        test    [bx+si],ah
        je      @@plane3
        or      al,4
@@plane3:
        add     bl,dl
        test    [bx+si],ah
        je      @@plane4
        or      al,8
@@plane4:
        add     bl,dl
        test    [bx+si],ah
        je      @@store
        or      al,10h
@@store:
        stosb                           ; the 5-bit color
        ror     ah,1                    ; next bit; CF when it wraps past bit 0
        jae     @@sameByte              ; no carry: same source bytes
        inc     si                      ; eight pixels done: the next byte of each plane
@@sameByte:
        loop    @@pixel
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah                     ; pops the 10 bytes of arguments
UnpackFivePlanesImpl ENDP


CODE ENDS
END
