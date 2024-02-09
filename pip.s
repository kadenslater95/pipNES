.segment "HEADER"
	
	.byte	"NES", $1A	; iNES header identifier
	.byte	2		; 2x 16KB PRG code
	.byte	1		; 1x  8KB CHR data
	.byte	$01, $00	; mapper 0, vertical mirroring

;;;;;;;;;;;;;;;

;;; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

.segment "ZEROPAGE"

pipstep: .res 1, $00

.segment "CODE"
reset:

	sei			; disable IRQs
	cld			; disable decimal mode
	ldx	#$40
	stx	$4017		; dsiable APU frame IRQ
	ldx	#$ff		; Set up stack
	txs			;  +
	inx			; now X = 0
	stx	$2000		; disable NMI
	stx	$2001		; disable rendering
	stx	$4010		; disable DMC IRQs

	;; first wait for vblank to make sure PPU is ready
vblankwait1:
	bit	$2002
	bpl	vblankwait1

clear_memory:
	lda	#$00
	sta	$0000, x
	sta	$0100, x
	sta	$0300, x
	sta	$0400, x
	sta	$0500, x
	sta	$0600, x
	sta	$0700, x
	lda	#$fe
	sta	$0200, x	; move all sprites off screen
	inx
	bne	clear_memory

	;; second wait for vblank, PPU is ready after this
vblankwait2:
	bit	$2002
	bpl	vblankwait2

load_palettes:
	lda	$2002		; read PPU status to reset the high/low latch
	lda	#$3f
	sta	$2006
	lda	#$00
	sta	$2006
	ldx	#$00
@loop:
	lda	palette, x	; load palette byte
	sta	$2007		; write to PPU
	inx			; set index to next byte
	cpx	#$20
	bne	@loop		; if x = $20, 32 bytes copied, all done

load_sprites:
	ldx	#$00		; start at 0
@loop:
	lda	sprites, x	; load data from address (sprites + x)
	sta	$0200, x	; store into RAM address ($0200 + x)
	inx			; x = x + 1
	cpx	#$18		; copmare x to hex $20, decimal 32
	bne	@loop

	lda	#%10010000	; enable NMI, sprites from Pattern Table 0
	sta	$2000

	lda	#%00011110	; enable sprites
	sta	$2001
	
forever:
	jmp	forever

nmi:
	lda	#$00		; set the low byte (00) of the RAM address
	sta	$2003
	lda	#$02		; set the high byte (02) of the RAM address 
	sta	$4014		; start the transfer

latch_controller:
	lda	#$01
	sta	$4016
	lda	#$00
	sta	$4016		; tell both controllers to latch buttons


read_a:
	lda	$4016		; player 1 - A
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)
@done:


read_b:
	lda	$4016		; player 1 - B
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)

	;; change out tiles for spike pip
	lda #$09
	sta $0201

	lda #$0a
	sta $0205

	lda #$0b
	sta $0209

	lda #$19
	sta $020d

	lda #$1a
	sta $0211

	jmp b_is_pressed
@done:


	lda #$00
	sta $0201

	lda #$01
	sta $0205

	lda #$02
	sta $0209

	lda #$13
	sta $020d

	lda #$14
	sta $0211


read_select:
	lda	$4016		; player 1 - Select
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)
@done:


read_start:
	lda	$4016		; player 1 - Start
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)
@done:


read_up:
	lda	$4016		; player 1 - Up
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)
@done:

read_down:
	lda	$4016		; player 1 - Down
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)
@done:


read_left:	
	lda	$4016		; player 1 - Left
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)
	;; add instructions here to do something when button IS pressed
	
	;; move all 4 sprites one pixel to the right by subracting 1
	lda	$0203		; load sprite 0 X-position
	sec			; make sure the carry flag is clear
	sbc	#$01		; a = a - 1
	sta	$0203		; save sprite 0 X-position
	sta	$020f		; save sprite 3 X-position

	lda	$0207		; load sprite 1 X-position
	sec			; sub one from it
	sbc	#$01		;  .
	sta	$0207		; save sprite 1 X-position
	sta	$0213		; save sprite 4 X-position

	lda	$020b		; load sprite 2 X-position
	sec			; sub one from it
	sbc	#$01		;  .
	sta	$020b		; save sprite 2 X-position
	sta	$0217		; save sprite 5 X-position
@done:

read_right:
	lda	$4016		; player 1 - Right
	and	#%00000001	; only look at bit 0
	beq	@done		; branch to @done if button is NOT pressed (0)
	;; add instructions here to do something when button IS pressed
	
	lda pipstep
	asl
	clc
	adc pipstep
	clc
	adc #$10
	tax

	;; move all 4 sprites one pixel to the right by adding 1
	lda	$0203		; load sprite 0 X-position
	clc			; make sure the carry flag is clear
	adc	#$01		; a = a + 1
	sta	$0203		; save sprite 0 X-position
	sta	$020f		; save sprite 3 X-position
	stx $020d		; replace sprite 3 tile with current pipstep

	lda	$0207		; load sprite 1 X-position
	clc			; add one to it
	adc	#$01		;  .
	sta	$0207		; save sprite 1 X-position
	sta	$0213		; save sprite 4 X-position
	inx
	stx $0211		; replace sprite 4 tile with current pipstep

	lda	$020b		; load sprite 2 X-position
	clc			; add one to it
	adc	#$01		;  .
	sta	$020b		; save sprite 2 X-position
	sta	$0217		; save sprite 5 X-position

	ldx pipstep
	inx
	cpx #$03
	bne @nfrx
	ldx #$00
@nfrx:
	stx pipstep
@done:

b_is_pressed:

	rti			; return from interrupt

palette:
	;; Background palette
	.byte	$00,$31,$32,$33
	.byte	$00,$35,$36,$37
	.byte	$0F,$39,$3A,$3B
	.byte	$0F,$3D,$3E,$0F
	;; Sprite palette
	.byte $00,$0F,$08,$36
	.byte	$00,$02,$38,$3C
	.byte	$00,$1C,$15,$14
	.byte	$00,$02,$38,$3C

sprites:
	; Pip Starting Sprite
     ;vert tile pal horiz
  .byte $a0, $03, $00, $80
  .byte $a0, $04, $00, $88
  .byte $a0, $05, $00, $90
  .byte $a8, $13, $00, $80
  .byte $a8, $14, $00, $88
  .byte $a8, $12, $00, $90

;;;;;;;;;;;;;;  
  
.segment "VECTORS"

	;; When an NMI happens (once per frame if enabled) the label nmi:
	.word	nmi
	;; When the processor first turns on or is reset, it will jump to the
	;; label reset:
	.word	reset
	;; External interrupt IRQ is not used in this tutorial 
	.word	0
  
;;;;;;;;;;;;;;  

.segment "CHARS"
	.incbin	"pip_chr.bin"	; includes 8KB graphics from SMB1
