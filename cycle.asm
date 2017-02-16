	processor 6502
	org $c000       ; 49152

screen  equ $05e0       ; Start 1000 bytes for screen character values
colmap  equ $d9e0       ; Start 1000 bytes for setting foreground color of chars

cmapoff equ $fb         ; Offset for color map
startcol equ $fd        ; Color table multiplier
baroff  equ $00        ; Raster bar offset for sin pos



        jsr $e544       ; Clear screen with kernal clear routine
        lda #00         ; Load accumulator with black color code
        sta $d021       ; Store at border color location

strloop:
        ldx #00         ; Read from byte 0
        lda text,x      ; Read from text label bytes at x offset into accumulator
        sta screen,x    ; Set screen RAM to char in accumulator
        inx             ; Increment x
        cpx #39         ; Is x 39?
        bne strloop+2   ; If x not equal to 39 (last char), loop

        lda #00         ; Load accumulator with value 0 (color index)
        sta startcol    ; Store accumulator value of 0 at startcol location (fd)
        lda #01         ; Load accumlator with 1 (delay value)
        sta delay       ; Store accumulator value of 1 into delay byte

        sei             ; Set interrupt disable bit
        lda #$7f        ; Load accumulator with 127 %01111111
        sta $dc0d       ; Disable CIA interrupts by putting 127 into mem address
        sta $dd0d
        and $d011       ; AND accumulator value with contents of mem at d011 (screen control register)
        sta $d011       ; Store that value back to d011, so clearing high bit (raster line bit)

        ldy #00         ; Load y register with 50 decimal, first 'screen' area line
        sty $d012       ; Store 50 at d012, contents of which is where interrupt should occur

        lda #<cycle   ; Store low byte of address of interrupt routine address
        sta $0314       ; at interrupt vector
        ldx #>cycle   ; Store high byte of address of routine
        stx $0315       ; at interrupt vector

        lda #$01        ; Load accumulator with 1 %00000001
        sta $d01a       ; Store accumulator at d01a, turning on raster interrupt again

        cli             ; Clear interrupt disable bit
        rts             ; Return (to basic)

cycle:
        dec delay       ; Decrement delay value
        bne return      ; If delay not equal to 0, branch to return
        lda #03         ; Load accumulator with 3
        sta delay       ; Store 3 into delay byte
        lda #39         ; Load 39 into accumulator
        sta cmapoff     ; Store 39 as offset for color map (last char)
        ldx startcol    ; Load x register with value in startcol address
nextchar:
        lda colors,x    ; Load accumulator with value in colors at startcol offset
        ldy cmapoff     ; Load y register with value in cmapoff address
        sta colmap,y    ; Store accumulator value in colmap mem + y reg offset
        txa             ; Transfer x register to accumulator
        adc #01         ; Add 01 to accumulator value
        and #07         ; And #07 (0111) with the accumulator value
        tax             ; Transfer accumulator back into x register
        dec cmapoff     ; Decrement cmapoffset value
        bpl nextchar    ; If cmapoff is not 0 loop nextchar

        lda startcol    ; Cycle back to start color for next update
        adc #01         ; Add 01 to accumulator value
        and #07         ; And 07 (0111) with the accumulator value
        sta startcol    ; Store accumulator value at startcol location

return:
        ldx baroff      ; Load x with current bar offset
        lda bar,x       ; Load accumulator with value in bar lookup at x offset
        adc #96         ; Add 50 to accumulator value
        sta ras1
        adc #58
        sta ras2
        inx
        stx baroff
        cpx #49         ; Compare x to 49, are we at end of bar lookup?
        bne setwt       ; 
        lda #00
        sta baroff
setwt:
        ;jmp $ea31
        lda #<widetop   ; Set low byte of next interrupt address
        sta $0314
        lda #>widetop   ; Set high byte
        sta $0315

        ldy ras1          ; Line to start next interrupt
        sty $d012       ; Store 50 at d012, contents of which is where interrupt should occur

        asl $d019       ; Shift left at d019, clearing interrupt flag
        jmp $ea81       ; Jump back to kernal interrupt processing

scroll:
        ldx sdelay
        dex
        bne continue

        lda soff
        sbc #01
        and #07
        bne cscroll

        lda #07
cscroll:
        sta soff

        lda $d016
        and #248
        adc soff
        sta $d016

        ldx #02
continue:
        stx sdelay

        lda #<widetop   ; Set low byte of next interrupt address
        sta $0314
        lda #>widetop   ; Set high byte
        sta $0315

        ldy ras1        ; Line to start next interrupt
        sty $d012       ; Store 50 at d012, contents of which is where interrupt should occur

        asl $d019
        jmp $ea81

shiftrow:
        ldx $00
        lda $05e1,x
        sta $05e0,x
        inx
        cpx #39
        bne shiftrow+2

        lda #<widetop   ; Set low byte of next interrupt address
        sta $0314
        lda #>widetop   ; Set high byte
        sta $0315

        ldy ras1        ; Line to start next interrupt
        sty $d012       ; Store 50 at d012, contents of which is where interrupt should occur

        asl $d019
        jmp $ea81

widetop:
        jsr latch      ; Wait 22 cycles... jsr is 6, so 28?
        lda #01         ; Load accumulator with 07 color yellow
        sta $d020       ; Set border to accumulator value
        sta $d021       ; Set background to accumulator value

        lda #<widebot   ; Set low byte of next interrupt address
        sta $0314
        lda #>widebot   ; Set high byte
        sta $0315
        
        ldy ras2        ; Line to start next interrupt
        sty $d012       ; Store 50 at d012, contents of which is where interrupt should occur

        asl $d019       ; Shift left at d019, clearing interrupt flag
        jmp $ea81       ; Jump back to kernal interrupt processing

widebot:
        jsr latch       ; Wait 22 cycles... jsr is 6, so 28
        lda #00         ; Load accumulator with 10 color yellow
        sta $d020       ; Set border to accumulator value
        sta $d021       ; Set background to accumulator value

        lda #<cycle   ; Set low byte of next interrupt address
        sta $0314
        lda #>cycle   ; Set high byte
        sta $0315
        
        ldy #00        ; Line to start next interrupt
        sty $d012       ; Store 50 at d012, contents of which is where interrupt should occur

        asl $d019       ; Shift left at d019, clearing interrupt flag
        ;jmp $ea81       ; Jump back to kernal interrupt processing
        jmp $ea31       ; Jump back to kernal interrupt processing

latch:  ldx #02            ; 2 cycles
lp:     dex              ; 2 cycles
        bne lp          ; 2 cycles + 1 if not equal
        rts              ; Return from subroutine, 6 cycles

text:   dc.b 41, 41, 41, 32, 32, 45, 45, 45
        dc.b 61, 27, 62, 32, 00, 01, $0C, $09 
        dc.b $13, 04, 01, $09, $12, $17, 01, $0C
        dc.b $0B, 05, $12, 32, 60, 29, 61, 45
        dc.b 45, 45, 32, 32, 40, 40, 40, 00
colors: dc.b 9, 41, 41, 32, 32, 45, 45, 45
delay:  dc.b 00
roff:   dc.b 05
bar:    dc.b 0, 0, 1, 2, 4, 6, 8, 10
        dc.b 13, 16, 19, 22, 25, 28, 31, 34
        dc.b 37, 40, 42, 44, 46, 48, 49, 50
        dc.b 50, 50, 50, 49, 48, 46, 44, 42
        dc.b 40, 37, 34, 31, 28, 25, 22, 19
        dc.b 16, 13, 10, 8, 6, 4, 2, 1
        dc.b 0, 0
ras1:   dc.b 75
ras2:   dc.b 125
sdelay: dc.b 02
soff:   dc.b 07