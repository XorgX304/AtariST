; vim: tabstop=4 shiftwidth=4 noexpandtab
; Atari ST Slide Show "The Eighties"
;
; code:  nanard    https://github.com/miniupnp/AtariST/the_80s
; music: Estrayk
; gfx:   jojo073

enable_music	equ 1
loadiff_store_current_line	equ 1
debug	equ 0
ready_led	equ	1


	; MACRO(S) DEFINITION(S)
	macro supexec		; 1 argument : subroutine address
	pea		\1(pc)
	move	#38,-(sp)	; Supexec
	trap	#14			; XBIOS
	addq.l	#6,sp
	endm

	if debug
	include '../asmlib/hatari.s'
	endif

	; CODE ENTRY POINT
	code

	move.l  4(sp),a5        ; address to basepage
    move.l  $0c(a5),d0      ; length of text segment
    add.l   $14(a5),d0      ; length of data segment
	add.l   $1c(a5),d0      ; length of bss segment
    ;add.l   #$1000,d0       ; length of stackpointer
	;add.l   #$100,d0        ; length of basepage
	add.l	#$1100,d0
	move.l  a5,d1           ; address to basepage
	add.l   d0,d1           ; end of program
	and.l   #-2,d1          ; make address even
	move.l  d1,sp           ; new stackspace

	move.l  d0,-(sp)        ; new size
	move.l  a5,-(sp)        ; memory block pointer
	;move.w  d0,-(sp)        ; ?
	clr.w	-(sp)
	move.w  #$4a,-(sp)      ; Mshrink
	trap    #1          	; GEMDOS
	lea 	12(sp),sp       ; http://toshyp.atari.org/en/00500c.html#Mshrink


	supexec backuppalette

	move.l	#framebuffer+255,d0
	;clr.b	d0
	sf	d0
	move.l	d0,framep

	dc.w $a000 ; Line-A init
	dc.w $a00a ; Line-A hide mouse

	move.w	#4,-(sp)	; Getrez
	trap	#14			; XBIOS
	move.w	d0,rezbackup

	move.w    #2,(sp)     ; Physbase
	trap      #14          ; XBIOS
	move.l	d0,physbase

	move.w    #3,(sp)     ; Logbase
	trap      #14          ; XBIOS
	move.l	d0,logbase

	moveq.l	#0,d0
	cmp.b	#4,machinetype
	bcs		.notfalcon
	move.w	#-1,(sp)
	move.w	#88,-(sp)	; Vsetmode() falcon
	trap	#14			; XBIOS
	addq.l	#2,sp
	andi.w	#$0030,d0	; keep VGA and PAL/NTCS bits
	ori.w	#$0182,d0	; VERTICAL | ST_COMPAT | 16color
	move.w	d0,(sp)
	move.w	#88,-(sp)
	trap	#14			; XBIOS
	lea	paletteb,a0
	move.l	a0,(sp)
	move.l	#$00ffffff,(a0)+	;	white
	move.l	#$00ff0000,(a0)+	;	red
	move.l	#$0000ff00,(a0)+	;	green
	move.w	#4,-(sp)	; count
	clr.w	-(sp)		; index
	move.w	#93,-(sp)	; VsetRGB (falcon)
	trap	#14			; XBIOS
	lea		10(sp),sp
	bra.s	.finished
	;move.w	#3,d0
.notfalcon
	move.w    d0,-(sp)    ; resolution (0=ST low, 1=ST Mid)
	move.l    physbase,-(sp)
	move.l    logbase,-(sp)
	move.w    #5,-(sp)     ; SetScreen
	trap      #14          ; XBIOS
	lea       14(sp),sp	; correct stack

	lea	paletteb,a0
	move.l	a0,-(sp)
	move.w	#$fff,(a0)+	;	white
	move.w	#$f00,(a0)+	;	red
	move.w	#$0f0,(a0)+	;	green
	move.w	#6,-(sp)	; Setpalette
	trap	#14			; XBIOS
	addq.l	#6,sp
.finished

	; VT52 part

	supexec	mstedisablecache

	; to detect TOS version
	; $4f2 : _sysbase    Base of OS pointer (RAM or ROM TOS)
	; TOS version is the WORD at offset 2

	pea	msg1
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	addq.l	#6,sp

	; detect the machine (ST / STE / TT / Falcon / etc.)
	move.l	#'_MCH',d6
	supexec	get_cookie
	cmp.l	#-1,d0		; no cookie jar or no cookie found
	beq.s	.plainst
	swap	d0
	tst.w	d0
	beq.s	.plainst
	subq.w	#1,d0
	beq.s	.ste
	subq.w	#1,d0
	beq.s	.tt
	subq.w	#1,d0
	beq.s	.falcon
	; unknown machine
	pea		msgunknown
	bra.s	.printdetected
.plainst
	pea	msgst
	moveq	#0,d1
	bra.s	.printdetected
.ste
	btst	#20,d0
	bne.s	.megaste
	pea	msgste
	moveq	#1,d1
	bra.s	.printdetected
.tt
	pea	msgtt
	moveq	#3,d1
	bra.s	.printdetected
.falcon
	pea	msgfalcon
	moveq	#4,d1
	bra.s	.printdetected
.megaste
	pea	msgmegaste
	moveq	#2,d1

.printdetected
	move.b	d1,machinetype
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS

	; show FILE_ID.DIZ
	move.l	#msgloading,2(sp)
	trap	#1		; GEMDOS
	move.l	#fileiddiz,2(sp)
	trap	#1		; GEMDOS
	addq.l	#6,sp

	lea	fileiddiz,a0
	lea	filebuffer,a1
	bsr loadfile

	tst.w	d0
	bmi.s	.fileiddizerror

	pea	msgok
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	addq.l	#6,sp

	lea	filebuffer,a6
	bsr	printslow
	bra.s	.checkfiles

.fileiddizerror
	pea	msgnotfound
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	addq.l	#6,sp

.checkfiles
	lea	files,a6
.filecheckloop
	pea	msgcheck
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	move.l	a6,2(sp)
	trap	#1		; GEMDOS
	addq.l	#6,sp
	move.w	#0,-(sp)	; read-only
	move.l	a6,-(sp)	; fname
	move.w	#61,-(sp)	; Fopen
	trap	#1			; GEMDOS
	addq.l	#8,sp
	tst.l	d0
	bmi.s	.openerror
	move.w	d0,-(sp)	; handle
	move.w	#62,(sp)	; Fclose
	trap	#1			; GEMDOS
	move.l	#msgok,(sp)
	bra.s	.continue
.openerror
	pea		msgnotfound
.continue
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	addq.l	#6,sp
	lea		13(a6),a6	; 8+3+dot+null term = 13 chars
	tst.b	(a6)
	bne	.filecheckloop

	; Load font
	pea	msgfont
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	move.l	#fontfile,2(sp)
	trap	#1		; GEMDOS
	addq.l	#2,sp
	move.l	(sp)+,a0
	lea	filebuffer,a1
	bsr loadfile
	tst.w	d0
	bmi	.fontloadfailed

	; decode font IFF
	lea	filebuffer,a0
	move.l	framep,a1
	lea	palettec,a2
	bsr	loadiff

	; prepare (preshift font)

	lea	font,a1
	moveq.l	#0,d7	; char index
.charloop
	move.l	d7,-(sp)
	divu.w	#10,d7	; upperword = column, lower word = line
	move.w	#25*160,d0	; char height = 25
	mulu.w	d7,d0
	swap	d7
	lsl.w	#4,d7
	add.w	d7,d0
	move.l	framep,a0
	adda.w	d0,a0	; pointer to character

	move.l	a1,a2
	moveq.l	#0,d0
	; unshifted char
	move.w	#25-1,d1
.ccl1
	move.l	(a0)+,(a1)+	; 32 font pixels
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	d0,(a1)+	; 16 black pixels
	move.l	d0,(a1)+
	add.l	#144,a0
	dbra	d1,.ccl1

	; shifted by 2 pixels 7 times
	move.w	#7*25-1,d1
.ccl2
	rept 4
	move.w	(a2)+,d0
	lsr.w	#2,d0
	move.w	d0,(a1)+
	endr
	move.w	#8-1,d2
.ccl2b
	move.w	-8(a2),d0
	swap	d0
	move.w	(a2)+,d0
	lsr.l	#2,d0
	move.w	d0,(a1)+
	dbra	d2,.ccl2b
	dbra	d1,.ccl2

	move.l	(sp)+,d7	; char index
	addq.l	#1,d7
	cmp.w	#64,d7
	blt.s	.charloop

	pea		msgok
	bra.s	.continuef

.fontloadfailed
	pea		msgnotfound
.continuef
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	addq.l	#6,sp

	; load first IFF
	lea	files,a6
	pea	msgloading
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	move.l	a6,2(sp)
	trap	#1		; GEMDOS
	addq.l	#2,sp
	move.l	(sp)+,a0
	lea	filebuffer,a1
	bsr loadfile
	tst.w	d0
	bpl.s	.firstfileok

	pea		msgnotfound
	move.w	#9,-(sp)	; Cconws
	trap	#1			; GEMDOS
	move.w	#7,(sp)		; Crawcin
	trap	#1			; GEMDOS
	addq.l	#6,sp
	bra	errorend

.firstfileok
	; decode IFF
	lea	filebuffer,a0
	move.l	framep,a1
	lea	palettea,a2
	bsr	loadiff

	pea	msgok
	move.w	#9,-(sp)	; Cconws
	trap	#1		; GEMDOS
	addq.l	#6,sp

	if ready_led
	; "status" led at the bottom of the screen. Color 15
	move.l	framep,a1
	add.l	#160*228+152,a1
	moveq.l	#-1,d0
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	lea	152(a1),a1
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	endif

	; fade out

	moveq.l	#-1,d7
.fadeloop:
	lea	paletteb,a0
	move.l	a0,-(sp)
	move.w	d7,d1
	lsr.w	#1,d1
	move.w	d1,(a0)+	;	white
	move.w	d1,d2
	and.w	#$f00,d2	;	red
	move.w	d2,(a0)+
	move.w	d1,d2
	and.w	#$0f0,d2
	move.w	d2,(a0)+	;	green
	move.w	#6,-(sp)	; Setpalette
	trap	#14			; XBIOS
	move.w	#37,(sp)    ; Vsync
	trap	#14         ; XBIOS
	addq.l	#6,sp

	sub.w	#$1111,d7
	bcc.s	.fadeloop

	; copy palettea => paletteb
	lea		palettea,a0
	lea		paletteb-palettea(a0),a1
	rept	16/2
	move.l	(a0)+,(a1)+
	endr

	; starting for real...

	supexec	install		; install interrupt handlers
	;clr.l	-(sp)			; supervisor mode
	;move.w	#$20,-(sp)		;
	;trap	#1			;
	;addq.l	#6,sp			;
	;move.l	d0,oldusp		; store old user stack pointer

	supexec setvideo

	if	enable_music
	supexec	MUSIC+0			; init music
	endif

	; "main" loop
.loop
	lea		13(a6),a6		; advance 1 filename
	tst.b	(a6)
	bne.s	.tryload
	lea	files,a6		; Loop to first file

.tryload
	if ready_led
	move.w #$0fb0,palettec+30	; yellow = LOADING
	endif

	move.l	a6,a0
	lea	filebuffer,a1
	bsr loadfile
	tst.l	d0
	bmi.s	.loop	; try next file

	move.l	a6,-(sp)	; push filename pointer
	move.w	d0,-(sp)	; push byte count

	if ready_led
	move.w #$00f0,palettec+30	; green = READY
	endif

	move.w	#8*50,d7	; Maximum time between images
.waitkey
	move.w    #37,-(sp)    ; Vsync
	trap      #14          ; XBIOS
	move.w	#11,(sp)	; Cconis = Character console is waiting
	trap	#1			; GEMDOS   Check whether a character is waiting in the standard input buffer
	addq.l	#2,sp
	subq.w	#1,d7
	beq.s	.nextimage
	tst.w	d0
	beq.s	.waitkey

	move.w	#7,-(sp)	; Crawcin = Read a character unbuffered from standard input device
	trap	#1			; GEMDOS
	addq.l	#2,sp
	swap	d0			; scancode
; http://www.atari-wiki.com/?title=Atari_ST_Scancode_diagram_by_Unseen_Menace
	cmp.b	#1,d0	; ESC
	beq.s	end

.nextimage
	if ready_led
	move.w #$00bf,palettec+30	; blue = WORKING
	endif

	move.w	(sp)+,d0	; pop byte count
	lea	filebuffer,a0
	move.l	framep,a1
	lea	palettea,a2
	bsr	loadiff

	lea		palettea,a0
	lea		paletteb-palettea(a0),a1
	moveq.l	#8-1,d0
.palcpyl
	move.l	(a0)+,(a1)+
	dbra	d0,.palcpyl

	move.l	(sp)+,a6	; pop filename pointer
	bra		.loop


end:
	if	enable_music
	supexec MUSIC+4			; de-init music
	endif
	supexec uninstall

errorend:
	; restore palette
	pea	palettebackup
	move.w	#6,-(sp)	; Setpalette
	trap	#14			; XBIOS
	addq.l	#6,sp

	move.w    rezbackup,-(sp)    ; resolution (0=ST low, 1=ST Mid)
	move.l    physbase,-(sp)
	move.l    logbase,-(sp)
	move.w    #5,-(sp)     ; SetScreen
	trap      #14          ; XBIOS

	clr (sp)
	trap #1		; Pterm0

	; ------------------------------------------------------

	; subroutines

	; arguments :
	; d0 = character (ascii)
	; d1 = X position
	; trashes d0-d1/a0-a1
putchar
	cmp.w	#-32,d1
	blt.s	.exit
	cmp.w	#320,d1
	bge.s	.exit

	; TODO : to upper case
	sub.w	#32,d0
	lsl.w	#4,d0	; *16
	eor.w	d1,d0
	and.w	#%1111111111110001,d0
	eor.w	d1,d0
	mulu.w	#25*3*4,d0
	lea		font,a0
	adda.l	d0,a0
	move.l	framep,a1
	add.l	#160*201,a1

	move.w	#25-1,d0
	cmp.w	#-16,d1
	blt.s	.skiptwowords
	cmp.w	#0,d1
	blt.s	.skiponeword

	move.w	d1,d0
	lsr.w	#1,d0
	and.w	#-8,d0
	adda.w	d0,a1

	move.w	#25-1,d0
	cmp.w	#320-16,d1
	bge.s	.skiplasttwowords
	cmp.w	#320-32,d1
	bge.s	.skiplastoneword
	cmp.w	#320-48,d1
	bge		.donotaddzero

.looplinea
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	rept	2*2
	move.l	(a0)+,(a1)+
	endr
	moveq.l	#0,d1
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	add.l	#160-32,a1
	dbra	d0,.looplinea
.exit
	rts

.skiponeword
	moveq.l	#0,d1
.looplineb
	addq.l	#8,a0
	rept	2*2
	move.l	(a0)+,(a1)+
	endr
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	add.l	#160-24,a1
	dbra	d0,.looplineb
	rts

.skiptwowords
	moveq.l	#0,d1
.looplinec
	add.l	#16,a0
	rept	2
	move.l	(a0)+,(a1)+
	endr
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	add.l	#160-16,a1
	dbra	d0,.looplinec
	rts

.skiplastoneword
.looplined
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	rept	2
	move.l	(a0)+,(a1)+
	endr
	addq.l	#8,a0
	add.l	#160-16,a1
	dbra	d0,.looplined
	rts

.skiplasttwowords
.looplinee
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	add.l	#16,a0
	add.l	#160-8,a1
	dbra	d0,.looplinee
	rts

.donotaddzero
.loopline
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	move.l	(a0)+,d1
	or.l	d1,(a1)+
	rept	2*2
	move.l	(a0)+,(a1)+
	endr
	add.l	#160-24,a1
	dbra	d0,.loopline
	rts

	; *** putchar end ***

	; argument : a6
printslow
	pea	$00020040	; 2 = Cconout
.loop
	move.b	(a6)+,3(sp)
	beq.s	.breakloop
	trap	#1		; GEMDOS
	cmp.b	#10,3(sp)	; LF ?
	beq.s	.lf
	move.b	(a6)+,3(sp)
	beq.s	.breakloop
	trap	#1		; GEMDOS
	cmp.b	#10,3(sp)	; LF ?
	beq.s	.lf
	move.b	(a6)+,3(sp)
	beq.s	.breakloop
	trap	#1		; GEMDOS
	cmp.b	#10,3(sp)	; LF ?
	beq.s	.lf
	move.b	(a6)+,3(sp)
	beq.s	.breakloop
	trap	#1		; GEMDOS
	cmp.b	#10,3(sp)	; LF ?
	bne.s	.notlf
.lf
	move.b	#7,3(sp)	; BEL
	trap	#1		; GEMDOS
.notlf
	move.w    #37,-(sp)    ; Vsync
	trap      #14          ; XBIOS
	addq.l	#2,sp
	bra	.loop
.breakloop
	addq.l	#4,sp
	rts

	; thanks to zerkman for the trick.
	; we write to $ff8e21 just as we are on a Mega Ste
	; If we are not, this will trigger a BUS ERROR
	; that we recover without problem :)
mstedisablecache
	move.l	$008.w,d0	; save Bus error vector
	move.l	#mybuserror,$008.w
	clr.b	$ffff8e21.w	; disable cache and set 8MHz
	move.l	d0,$008.w	; restore Bus error vector
	rts

mybuserror
	; 68000 Bus or Address error exception stack frame :
	; $00   R/W | I/N | FUNCTION CODE
	; $02   ACCESS ADDRESS HIGH
	; $04   ACCESS ADDRESS LOW
	; $06   INSTRUCTION REGISTER
	; $08   STATUS REGISTER
	; $0A   PC HIGH
	; $0C   PC LOW
	; 68010 Bus and Address error stack frame :
	; $00   STATUS REGISTER
	; $02   PC HIGH
	; $04   PC LOW
	; $06   1 0 0 0 | VECTOR OFFSET ($8xxx)
	; $08   SPECIAL STATUS WORD
	; ...
	cmp.w	#$7008,6(sp)
	beq.s	.is68040accesserrorframe
	cmp.w	#$8008,6(sp)
	beq.s	.is68010frame
	cmp.w	#$A008,6(sp)
	beq.s	.is68020shortframe
	cmp.w	#$B008,6(sp)
	beq.s	.is68020longframe
	addq.l	#8,sp
	rte
.is68010frame
	clr.w	8(sp)
	rte
.is68040accesserrorframe
.is68020shortframe
.is68020longframe
	add.l	#4,2(sp)	; skip clr.w instruction
	rte

backuppalette
	lea	$ffff8240.w,a0
	lea palettebackup,a1
cpypal
	move.w	#15,d0
.palcpyloop:
	move.w	(a0)+,(a1)+
	dbra	d0,.palcpyloop
	rts

setvideo
	cmp.b	#4,machinetype
	bcs		.notfalcon
	move.w	#$59,-(sp)	; VgetMonitor check monitortype (falcon)
	trap	#14	; XBIOS
	addq.l	#2,sp
	cmp.w	#2,d0
	beq.s	.isvga
		* from 'Screen Pain'
		* Monitor: RGB/TV
		* 320*240, 16 Farben, 50.0 Hz, 15625 Hz
		MOVE.L   #$3E0033,$FFFF8282.W
        MOVE.L   #$A0003,$FFFF8286.W
        MOVE.L   #$1C0036,$FFFF828A.W
        MOVE.L   #$2710265,$FFFF82A2.W
        MOVE.L   #$2F0057,$FFFF82A6.W
        MOVE.L   #$237026B,$FFFF82AA.W
        MOVE.W   #$200,$FFFF820A.W
        MOVE.W   #$181,$FFFF82C0.W
        CLR.W    $FFFF8266.W
        MOVE.B   #$0,$FFFF8260.W
        MOVE.W   #$0,$FFFF82C2.W
        MOVE.W   #$50,$FFFF8210.W
	if 0
	bra.s	.notfalcon
.isvga
	* Monitor: VGA
	* 320*240, 16 Farben, 60.0 Hz, 31470 Hz
        MOVE.L   #$170011,$FFFF8282.W
        MOVE.L   #$2020E,$FFFF8286.W
        MOVE.L   #$D0012,$FFFF828A.W
        MOVE.L   #$41903FF,$FFFF82A2.W
        MOVE.L   #$3F003D,$FFFF82A6.W
        MOVE.L   #$3FD0415,$FFFF82AA.W
        MOVE.W   #$200,$FFFF820A.W
        MOVE.W   #$186,$FFFF82C0.W
        CLR.W    $FFFF8266.W
        MOVE.B   #$0,$FFFF8260.W
        MOVE.W   #$5,$FFFF82C2.W
        MOVE.W   #$50,$FFFF8210.W
	endif
.notfalcon
	move.l	framep,d0
	lsr.l	#8,d0
	move.b	d0,$ffff8203.w	; Video base medium
	lsr.w	#8,d0
	move.b	d0,$ffff8201.w	; Video base high
	rts

install
	move.l	#hbl199,$120
	or.b 	#1,$fffffa07.w 	;enable Timer B
	or.b 	#1,$fffffa13.w	;interrupt mask
	move.l	$70,oldvbl+2
	move.l	#vbl,$70
	move.b 	#0,$fffffa1b.w 	;Timer B stop
	move.b	$484.w,conterm_backup
	move.b	#$8,$484.w		; key click OFF
	rts

uninstall:
	move.l	oldvbl+2,$70
	move.b 	#0,$fffffa1b.w 	;Timer B stop
	move.b	conterm_backup,$484.w
	rts

	; Interrupt handlers
vbl
	move.l	#hbl199,$120
	movem.l	d0-d1/a0-a1,-(sp)			; SAVE registers
	move.w	loadiff_current_line,d0
	;addq.w	#1,d0
	move.w	#199,d1
	;cmp.w	d1,d0
	cmp.w	#196,d0		; take a margin
	bge.s	.nopalswap
	move.l	#hbl,$120
	addq.w	#1,d0
	sub.w	d0,d1
	move.b	d1,hblcount2
	move.w	d0,d1
.nopalswap
	move.b 	#0,$fffffa1b.w 	;Timer stop
	move.b	d1,$fffffa21.w 	;Counter value
	move.b 	#8,$fffffa1b.w 	;Timer start

	if debug
	;move.w	#$00f,$ffff8240.w	; blue
	move.w	#$000,$ffff8240.w	; black
	endif
	if	enable_music
	bsr 	MUSIC+8			; call music
	endif
	; set palettea
	lea		palettea,a0
	lea		$ffff8240.w,a1
	rept	16/2
	move.l	(a0)+,(a1)+
	endr

	; scrolltext
	if debug
	move.w	#$b00,$ffff8240.w	; red
	endif
	move.w	tmppos,d0
	move.w	tmppos+2,d1
	sub.w	#48,d1
.scrollloop
	movem.w	d0-d1,-(sp)
	lea		scrolltext,a0
	move.b	(a0,d0),d0
	and.w	#$ff,d0
	bsr		putchar
	movem.w	(sp)+,d0-d1
	addq.w	#1,d0
	cmp.w	#scrolltextlen,d0
	blt.s	.ok
	moveq.l	#0,d0
.ok
	add.w	#32+2,d1
	cmp.w	#320,d1
	blt.s	.scrollloop

	sub.w	#4,tmppos+2
	bge.s	.okc
	add.w	#32+2,tmppos+2
	move.w	tmppos,d0
	addq.w	#1,d0
	cmp.w	#scrolltextlen,d0
	blt.s	.okb
	moveq.l	#0,d0
.okb
	move.w	d0,tmppos
.okc

	if debug
	move.w	#$000,$ffff8240.w	; black
	endif
	movem.l	(sp)+,d0-d1/a0-a1	; restore registers
	;rte	; skip system VBL routine
oldvbl
	jmp $0.l
tmppos
	dc.w	0
	dc.w	320*2

hbl
	move.w	#$2700,sr	; disable interrupts
	move.l	#hbl199,$120
	move.b 	#0,$fffffa1b.w 	;Timer B stop
	move.b	hblcount2,$fffffa21.w 	; timer B data : Counter value
	move.b 	#8,$fffffa1b.w 	;Timer B start : Event count mode
	; set paletteb
	movem.l	d0/a0-a1,-(sp)
	lea		paletteb,a0
	lea		$ffff8240.w,a1
	rept 8
	move.l	(a0)+,(a1)+
	endr
	movem.l	(sp)+,d0/a0-a1
	bclr 	#0,$fffffa0f.w 	; acknowledge interrupt
	rte

hbl199
	move.w	#$2700,sr	; disable interrupts
	movem.l	d0/a0-a1,-(sp)

	if debug
	move.w	#$00f,$ffff8240.w	; blue
	endif

	cmp.b	#3,machinetype	; TT or Falcon ?
	bcc.s	.skipborderopen

	lea		$fffffa1b.w,a0
	move.b 	#0,(a0)			; fffa1b Timer B stop
	move.b	#200,6(a0)	 	; fffa21 Timer B data : Counter value
	move.b	#8,(a0)			; fffa1b Timer B start : Event count mode
	move.b	6(a0),d0
.wait
	cmp.b	6(a0),d0
	beq.s	.wait

	eor.b	#2,$ffff820a.w		; 50Hz/60Hz switch
	if debug
	move.w	#$0f0,$ffff8240.w	; green
	or.l	d0,d0
	or.l	d0,d0
	else
	moveq.l	#2,d0
.loop1
	nop
	dbra	d0,.loop1
	endif
	eor.b	#2,$ffff820a.w		; 50Hz/60Hz switch
.skipborderopen

	;set palettec (from color index 1 to 15, skip color 0)
	lea		palettec+2,a0
	lea		$ffff8242.w,a1
	move.w	#14,d0
.loop
	move.w	(a0)+,(a1)+
	dbra	d0,.loop

	bclr 	#0,$fffffa0f.w 	; acknowledge interrupt
	movem.l	(sp)+,d0/a0-a1
	rte

	; includes

	include '../asmlib/loadfile.s'
	include '../show_iff/loadiff.s'
	include '../asmlib/getcooki.s'
	code
MUSIC
	incbin	'TELEPHO3.SND'; SNDH file

	data
fileiddiz
	dc.b	'FILE_ID.DIZ',0
	; see http://toshyp.atari.org/en/VT_52_terminal.html
msg1
	dc.b	27,'E',27,'e'	; clear screen, show cursor
msgdetect
	dc.b	'Detecting machine : ',0
msgloading
	dc.b 	"Loading ",0
msgfont
	dc.b	"Loading font ",0
msgok
	dc.b	27,'b',2	; Forground color 2=green
	dc.b	' OK',27,'b',3,13,10,7,0
msgcheck
	dc.b	'Checking ',0
msgnotfound
	dc.b	27,'b',1	; Forground color 1 = red
	dc.b	' NOT FOUND',27,'b',3,13,10,7,0
msgunknown
	dc.b	'Unknown',13,10,0
msgst
	dc.b	'ST',13,10,0
msgste
	dc.b	'STe',13,10,0
msgmegaste
	dc.b	'Mega STe.',13,10,0
msgfalcon
	dc.b	'Falcon 030',13,10,0
msgtt
	dc.b	'TT 030',13,10,0
files	;   '12345678.123',0,''	; 13 characters per entry
	dc.b	'80.IFF',0,'      '
	dc.b	'MIEDO01.IFF',0,' '
	dc.b	'SUPERDH2.IFF',0,''
	dc.b	'BARCO1.IFF',0,'  '
	dc.b	'BATMAN.IFF',0,'  '
	dc.b	'BRUCE.IFF',0,'   '
	dc.b	'FERRARIW.IFF',0
	dc.b	'PANDA.IFF',0,'   '
	dc.b	'RACHEL.IFF',0,'  '
	dc.b	'REPLCANT.IFF',0
	dc.b	'RIPLEY.IFF',0,'  '
	dc.b	'ROBOCOP.IFF',0,' '
	dc.b	'STORMTRO.IFF',0
	dc.b	'SUPERMAN.IFF',0
	dc.b	'T800B.IFF',0,'   '
	dc.b	0
fontfile
	dc.b	'KNIGHT6.IFF',0

scrolltext
	dc.b	' WELCOME TO OUR FIRST RELEASE CALLED'
	dc.b	'      THE 80S       '
	dc.b	'THE CREDITS FOR THIS AWESOME SLIDESHOW ARE'
	dc.b	'     CODING BY NANARD      GFX BY JOJO073'
	dc.b	'     MUSIC COMPOSED IN 1988 BY KARSTEN OBARSKI'
	dc.b	' AND CONVERTED TO YM2149F BY ESTRAYK       '
	dc.b	'THE FAMOUS FONT  BY MING OF THE KNIGHT HAWKS'
	dc.b	'            ALL PICTURES HAVE BEEN PIXELED BY '
	dc.b	'JOJO073 IN DELUXEPAINT 16 COL'
	dc.b	'     HOPE YOU LIKE THEM!      '
	dc.b	'RESPECTS TO :   OXYGENE   NO EXTRA   PARADOX   '
	dc.b	'CHECKPOINT   RNO   DHS   LAMERS   THE PIXEL TWINS   '
	dc.b	'DUNE   AMIGAWAVE   GENESIS PROJECT   SECTOR ONE   '
	dc.b	'OXYRON   BATMAN GROUP   CAPSULE   CREAM   '
	dc.b	'KALISTO   ECHELON   '
	dc.b	'AND ALL WE FORGOT  !!!             '
	dc.b	'SOME WORDS FROM NANARD WHILE YOU ARE ENJOYING '
	dc.b	'TRUE 16 COLORS PIXELART :   '
	dc.b	"I'M VERY HAPPY TO RELEASE MY FIRST PRODUCTION FOR "
	dc.b	'THE ATARI ST.  LEARNING 68K ASM IS EASY THANKS TO '
	dc.b	'ALL THOSES WHO HAVE DISCOVERED THE MARVELOUS '
	dc.b	'POSSIBILITIES OF THIS MACHINE AND ARE STILL PUSHING '
	dc.b	"THE FRONTIERS TOWARD THE HORIZON.  "
	dc.b	"I'D LIKE TO THANKS ESPECIALLY HATARI AUTHORS, "
	dc.b	'ZERKMAN AND ATARIJOOKIE   '
	dc.b	'STAY ATARI!!!               '
	dc.b	'ESTRAYK AT KEYBOARD...         '
	dc.b	'HI! GUYS.  I JUST WANT SEND A SPECIAL GREETING TO '
	dc.b	'!CUBE  FOR HIS HELP WITH MAXYMISER.     '
	dc.b	'ALSO TELL THAT THIS SONG IS A TRIBUTE TO KARSTEN OBARSKI'
	dc.b	"     I HOPE YOU LIKE REMEMBER THE GOOD OLD 80'S TIMES "
	dc.b	"LISTENING DIZ SONG                      "
	dc.b	"GREETS TO NANARD FOR HIS PATIENCE MAKING THIS SLIDESHOW "
	dc.b	"COMPATIBLE WITH MY ATARI MEGASTE.   C U SOON!          "
	dc.b	"SOME FEW WORDS FROM JOJO073...    "
	dc.b	"I LIKE THE PIXEL ART AND A BIG GREETING TO "
	dc.b	"THE GFX RIPPER    BYE                           "
scrolltextend

scrolltextlen	equ	scrolltextend-scrolltext

	bss
	align	2
;oldusp
;	ds.l	1
palettebackup
	ds.w	16
palettea
	ds.w	16
paletteb
	ds.w	16
palettec
	ds.w	16
rezbackup
	ds.w	1
logbase
	ds.l	1
physbase
	ds.l	1
framep
	ds.l	1
font
	ds.w	8*64*25*3*4	; 64 chars in 32*25 => 25*3*4 words. preshifted
filebuffer
	ds.b	32000
hblcount2
	ds.b	1
conterm_backup
	ds.b	1
machinetype
	ds.b	1	; 0 = ST, 1 = STe, 2 = Mega STe, 3 = TT030, 4 = Falcon
framebuffer
	ds.b	160*248
