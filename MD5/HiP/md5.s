;APS00000088000000880000008800000088000000880000008800000088000000880000008800000088
; Inspired by https://github.com/calebstewart/md5/blob/main/md5.cpp

  ifnd __VASM
	incdir	include:
  endif

 	include exec/types.i
	include exec/execbase.i

	xdef @MD5_Init
	xdef @MD5_Update
	xdef @MD5_Final

pushm	macro
	ifc	"\1","all"
	movem.l	d0-a6,-(sp)
	else
	movem.l	\1,-(sp)
	endc
	endm

popm	macro
	ifc	"\1","all"
	movem.l	(sp)+,d0-a6
	else
	movem.l	(sp)+,\1
	endc
	endm

push	macro
	move.l	\1,-(sp)
	endm

pop	macro
	move.l	(sp)+,\1
	endm


ilword	macro
	ror	#8,\1
	swap	\1
	ror	#8,\1
	endm

ASSERT_ macro
    cmp.l   #\1,\2
    beq.b   *+4
    illegal
    endm

;TEST=1
;
    STRUCTURE MD5Ctx,0
        ULONG  ctx_a
        ULONG  ctx_b
        ULONG  ctx_c
        ULONG  ctx_d
        STRUCT ctx_block,16*4
        STRUCT ctx_buffer,64
        ULONG  ctx_lo
        ULONG  ctx_hi
        * Pairs of (block address, constant) for steps g,h,i
        STRUCT ctx_stepsGHI,3*16*8
        APTR   ctx_bodyFunc
    LABEL MD5Ctx_SIZEOF


	ifd TEST
main:
    lea     test1,a1
    move.l  #test1E-test1,d0
    bsr     .test
    ASSERT_  $5c5aa2ba,d0
    ASSERT_  $6e48a0e5,d1
    ASSERT_  $59c149cd,d2
    ASSERT_  $d4ce7a9e,d3

    lea     test2,a1
    move.l  #test2E-test2,d0
    bsr     .test
    ASSERT_  $337bc768,d0
    ASSERT_  $148e5e64,d1
    ASSERT_  $9a4319cb,d2
    ASSERT_  $bf87116b,d3

    lea     test3,a1
    move.l  #test3E-test3,d0
    bsr     .test
    ASSERT_  $879a8080,d0
    ASSERT_  $db643bae,d1
    ASSERT_  $dbc5c613,d2
    ASSERT_  $3008a7aa,d3

    lea     test4,a1
    move.l  #test4E-test4,d0
    bsr     .test
    ASSERT_  $78f4c9d9,d0
    ASSERT_  $24e13b51,d1
    ASSERT_  $4d1283b9,d2
    ASSERT_  $4b0f013b,d3

    moveq    #0,d0
    rts

.test
    lea     .ctx,a0
    pushm   d0/a1
    jsr     MD5_Init
    popm    d0/a1

    lea     .ctx,a0
;    lea     input,a1
;    move.l  #inputE-input,d0
    jsr      MD5_Update

    lea     .ctx,a0
    lea     .hash,a1
    jsr     MD5_Final
    movem.l .hash,d0-d3
    rts

.ctx    ds.b    MD5Ctx_SIZEOF
.hash   ds.b    16

;5c5aa2ba 6e48a0e5 59c149cd d4ce7a9e  test1b
;337bc768 148e5e64 9a4319cb bf87116b  test65b
;879a8080 db643bae dbc5c613 3008a7aa  test150b
;78f4c9d9 24e13b51 4d1283b9 4b0f013b  test10000b

test1   incbin  test1b
test1E
    even
test2   incbin  test65b
test2E
    even
test3   incbin  test150b
test3E
    even
test4   incbin  test10000b
test4E
    even

stepCount   dc.l    0

   endif ; TEST


* In:
*   a0 = context
@MD5_Init:
MD5_Init:
    pushm   d2-d7/a2-a6
    move.l  #$67452301,ctx_a(a0)
    move.l  #$efcdab89,ctx_b(a0)
    move.l  #$98badcfe,ctx_c(a0)
    move.l  #$10325476,ctx_d(a0)
    clr.l   ctx_lo(a0)
    clr.l   ctx_hi(a0)

    * Prepare block addressess into a table
    * for steps g,h,i
    lea     stepsG(pc),a1
    lea     stepBlockOffsetsGHI(pc),a3
    lea     ctx_stepsGHI(a0),a4
    moveq   #16+16+16-1,d0
    moveq   #0,d2
.1
    move.b  (a3)+,d2
    lea     ctx_block(a0,d2),a2
    move.l  a2,(a4)+        * store address
    move.l  (a1)+,(a4)+     * store constant
    dbf     d0,.1

    ; Select body implementation

    ; Reference
    ; lea     MD5_Body(pc),a2

    move.l  4.w,a1
    lea     MD5_Body_68040_dlx(pc),a2
    btst    #AFB_68040,AttnFlags+1(a1)
    bne     .x

    lea     MD5_Body_68020(pc),a2
    btst    #AFB_68020,AttnFlags+1(a1)
    bne     .x

    lea     MD5_Body_68000_dlx(pc),a2
.x
   ; lea     MD5_Body_small(pc),a2 ;;;;;;;;;;;;;;;;;;;;;;;;

    move.l  a2,ctx_bodyFunc(a0)
    popm   d2-d7/a2-a6
    rts

* In:
*   a0 = context
*   a1 = input data
*   d0 = input data size
@MD5_Update:
MD5_Update:
    pushm   d2-d7/a2-a6
    move.l  ctx_lo(a0),d1
    move.l  d1,d2
    * d1 = saved_lo
    add.l   d0,d2
    and.l   #$1fffffff,d2
    * d2 = (saved_lo + size) & 0x1fffffff
    move.l  d2,ctx_lo(a0)

    cmp.l   d1,d2
    bhs     .1
    * d2 < d1 (saved_lo)
    addq.l  #1,ctx_hi(a0)
.1
    ; ctx->hi += size >> 29;
    moveq   #29,d3
    move.l  d0,d4
    lsr.l   d3,d4
    add.l   d4,ctx_hi(a0)

	* used = saved_lo & 0x3f;
    and.l   #$3f,d1
    beq     .2
    * if (used){
        moveq   #64,d3
        sub.l   d1,d3
        * d3 = free - used
        cmp.l   d3,d0
        bhs     .22
        * size < free
            * memcpy(&ctx->buffer[used], data, size);
            lea     ctx_buffer(a0,d1),a2
            subq    #1,d0
            bmi     .cp1s
.cp1        move.b  (a1)+,(a2)+
            dbf     d0,.cp1
.cp1s
            rts
.22
		* memcpy(&ctx->buffer[used], data, free);
        move.l  d3,d4
        lea     ctx_buffer(a0,d1),a2
        subq    #1,d3
        bmi     .cp2s
.cp2    move.b  (a1)+,(a2)+
        dbf     d3,.cp2
.cp2s
		* data = (unsigned char *)data + free;
        add.l   d4,a1
		* size -= free;
        sub.l   d4,d0
        pushm   d0/a1
        lea     ctx_buffer(a0),a1
        moveq   #64,d0
        move.l  ctx_bodyFunc(a0),a2
        jsr     (a2)
        popm    d0/a1
    * }
.2
    cmp.l   #64,d0
    blo     .3
	* if (size >= 64) {
    push    d0
    * data = MD5_Body(ctx, data, size & ~(unsigned long)0x3f);
    and.l   #~$3f,d0
    move.l  ctx_bodyFunc(a0),a2
    jsr     (a2)
    * data pointer in a1 changed
    pop     d0
    and.l   #$3f,d0
.3
    ; memcpy(ctx->buffer, data, size);
    subq    #1,d0
    bmi     .skip
    lea     ctx_buffer(a0),a2
.cp move.b  (a1)+,(a2)+
    dbf     d0,.cp
.skip
    popm   d2-d7/a2-a6
    rts



* In:
*   a0 = context
* Out:
*   a1 = hash
*   
@MD5_Final:
MD5_Final:
    pushm   d2-d7/a2-a6
    push    a1
	* used = ctx->lo & 0x3f;
    moveq   #$3f,d0
    and.l   ctx_lo(a0),d0

	* ctx->buffer[used++] = 0x80;
    move.b  #$80,ctx_buffer(a0,d0);
    addq.l  #1,d0
    
	* free = 64 - used;
    moveq   #64,d1
    sub.l   d0,d1


	* if (free < 8) {
    cmp.w   #8,d1
    bhs     .1
		* memset(&ctx->buffer[used], 0, free);
        lea     ctx_buffer(a0,d0),a1
        move    d1,d2
        subq    #1,d2
        bmi     .cs
.c      clr.b   (a1)+
        dbf     d2,.c
.cs
		* MD5_Body(ctx, ctx->buffer, 64);
        lea     ctx_buffer(a0),a1
        moveq   #64,d0
        move.l  ctx_bodyFunc(a0),a2
        jsr     (a2)
		* used = 0;
	    * free = 64;
        moveq   #0,d0
        moveq   #64,d1
.1
    
	* memset(&ctx->buffer[used], 0, free - 8);
    lea     ctx_buffer(a0,d0),a1
    move    d1,d2
    subq    #8,d2
    subq    #1,d2
    bmi     .c2s
.c2 clr.b   (a1)+
    dbf     d2,.c2
.c2s
    move.l  ctx_lo(a0),d0
    lsl.l   #3,d0
    move.l  d0,ctx_lo(a0)

    move.b  d0,ctx_buffer+56(a0)
    lsr.l   #8,d0
    move.b  d0,ctx_buffer+57(a0)
    lsr.l   #8,d0
    move.b  d0,ctx_buffer+58(a0)
    lsr.l   #8,d0
    move.b  d0,ctx_buffer+59(a0)

    move.l  ctx_hi(a0),d0
    move.b  d0,ctx_buffer+60(a0)
    lsr.l   #8,d0
    move.b  d0,ctx_buffer+61(a0)
    lsr.l   #8,d0
    move.b  d0,ctx_buffer+62(a0)
    lsr.l   #8,d0
    move.b  d0,ctx_buffer+63(a0)

    lea     ctx_buffer(a0),a1
    moveq   #64,d0
    move.l  ctx_bodyFunc(a0),a2
    jsr     (a2)

    moveq   #4-1,d2
    lea     ctx_a(a0),a0
    pop     a1
.il move.l  (a0)+,d0
    ilword  d0
    move.l  d0,(a1)+
    dbf     d2,.il
    popm    d2-d7/a2-a6
    rts



; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp1 - output
; \6 tmp2
stepFa macro 
    move.l  (a1)+,\6    * read input

    ;((z) ^ ((x) & ((y) ^ (z))))
    move.l  \3,\5       * mix to \5
    ror.w   #8,\6       * ilword part 1
    eor.l   \4,\5       * \5 = c ^ d 
    swap    \6          * ilword part 2
    ror.w   #8,\6       * ilword part 3
    and.l   \2,\5       * \5 = (c ^ d) & b
    move.l  \6,(a6)+    * write to block buffer
    eor.l   \4,\5       * \5 = ((c ^ d) & b) ^ d

    add.l   \6,\5      * add block value
    add.l   \1,\5      * add ctx_a
    add.l   (a2)+,\5   * add constant
    endm



; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp1 - output
; \6 tmp2
; \7 constant
stepFa2 macro 
    move.l  (a1)+,\6    * read input

    ;((z) ^ ((x) & ((y) ^ (z))))
    move.l  \3,\5       * mix to \5
    ror.w   #8,\6       * ilword part 1
    eor.l   \4,\5       * \5 = c ^ d 
    swap    \6          * ilword part 2
    ror.w   #8,\6       * ilword part 3
    and.l   \2,\5       * \5 = (c ^ d) & b
    move.l  \6,(a6)+    * write to block buffer
    eor.l   \4,\5       * \5 = ((c ^ d) & b) ^ d

    add.l   \6,\5      * add block value
    add.l   \1,\5      * add ctx_a
    add.l   \7,\5      * add constant
    endm


; \1 a
; \2 b
; \3 c - output
; \4 d
; \5 tmp2
stepFb macro 
    move.l  (a1)+,\5    * read input

    ;((z) ^ ((x) & ((y) ^ (z))))
    ror.w   #8,\5       * ilword part 1
    eor.l   \4,\3       * 3 = c ^ d 
    swap    \5          * ilword part 2
    ror.w   #8,\5       * ilword part 3
    and.l   \2,\3       * 3 = (c ^ d) & b
    move.l  \5,(a6)+    * write to block buffer
    eor.l   \4,\3       * 3 = ((c ^ d) & b) ^ d

    add.l   \5,\3      * add block value
    add.l   \1,\3      * add ctx_a
    add.l   (a2)+,\3   * add constant
    endm

; \1 a
; \2 b
; \3 c - output
; \4 d
; \5 tmp2
; \6 constant
stepFb2 macro 
    move.l  (a1)+,\5    * read input

    ;((z) ^ ((x) & ((y) ^ (z))))
    ror.w   #8,\5       * ilword part 1
    eor.l   \4,\3       * 3 = c ^ d 
    swap    \5          * ilword part 2
    ror.w   #8,\5       * ilword part 3
    and.l   \2,\3       * 3 = (c ^ d) & b
    move.l  \5,(a6)+    * write to block buffer
    eor.l   \4,\3       * 3 = ((c ^ d) & b) ^ d

    add.l   \5,\3      * add block value
    add.l   \1,\3      * add ctx_a
    add.l   \6,\3      * add constant
    endm


; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - output
stepGa macro 
    move.l  (a2)+,a4   * read block address

    ;((y) ^ ((z) & ((x) ^ (y))))
    move.l  \2,\5
    eor.l   \3,\5       * \5 = b ^ c
    and.l   \4,\5       * \5 = (b ^ c) & d
    eor.l   \3,\5       * \5 = ((b ^ c) & d) ^ c

    add.l   \1,\5      * add ctx_a
    add.l   (a4),\5    * add block value
    add.l   (a2)+,\5   * add constant
    endm


; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - output
; \6 constant
; \7 block offset
stepGa2 macro 
    ;((y) ^ ((z) & ((x) ^ (y))))
    move.l  \2,\5
    eor.l   \3,\5       * \5 = b ^ c
    and.l   \4,\5       * \5 = (b ^ c) & d
    eor.l   \3,\5       * \5 = ((b ^ c) & d) ^ c

    add.l   \1,\5      * add ctx_a
    add.l   \7+ctx_block(a0),\5    * add block value
    add.l   \6,\5   * add constant
    endm

; \1 a
; \2 b - overwritten output
; \3 c
; \4 d
stepGb macro 
    move.l  (a2)+,a4   * read block address

    ;((y) ^ ((z) & ((x) ^ (y))))
;    move.l  \2,\5
    eor.l   \3,\2       * \2 = b ^ c
    and.l   \4,\2       * \2 = (b ^ c) & d
    eor.l   \3,\2       * \2 = ((b ^ c) & d) ^ c

    add.l   \1,\2      * add ctx_a
    add.l   (a4),\2    * add block value
    add.l   (a2)+,\2   * add constant
    endm

; \1 a
; \2 b - overwritten output
; \3 c
; \4 d
; \5 constant
; \6 block offset
stepGb2 macro 
    ;((y) ^ ((z) & ((x) ^ (y))))
    eor.l   \3,\2       * \2 = b ^ c
    and.l   \4,\2       * \2 = (b ^ c) & d
    eor.l   \3,\2       * \2 = ((b ^ c) & d) ^ c

    add.l   \1,\2      * add ctx_a
    add.l   \6+ctx_block(a0),\2    * add block value
    add.l   \5,\2     * add constant
    endm

; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - output
; \6 tmp 2 - intermediate result
stepHa macro 
    move.l  (a2)+,a4   * read block address

    ;(x) ^ (y) ^ (z)
    move.l  \2,\5       
    eor.l   \3,\5       * \5 = b ^ c
    move.l  \5,\6       * \6 = store for stepHb
    eor.l   \4,\5       * \5 = (b ^ c) ^ d

    add.l   \1,\5      * add ctx_a
    add.l   (a4),\5    * add block value
    add.l   (a2)+,\5   * add constant
    endm


; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - output
; \6 tmp 2 - intermediate result
; \7 constant
; \8 block offset
stepHa2 macro 
        ;(x) ^ (y) ^ (z)
    move.l  \2,\5       
    eor.l   \3,\5       * \5 = b ^ c
    move.l  \5,\6       * \6 = store for stepHb
    eor.l   \4,\5       * \5 = (b ^ c) ^ d

    add.l   \1,\5      * add ctx_a
    add.l   \8+ctx_block(a0),\5    * add block value
    add.l   \7,\5   * add constant
    endm

; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - output
stepHb macro 
    move.l  (a2)+,a4   * read block address

    ; use stepHa intermediate result in \5
    eor.l   \2,\5       * \5 = (b ^ c) ^ d

    add.l   \1,\5      * add ctx_a
    add.l   (a4),\5    * add block value
    add.l   (a2)+,\5   * add constant
    endm

; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - output
; \6 constant
; \7 block offset
stepHb2 macro 
    ; use stepHa intermediate result in \5
    eor.l   \2,\5       * \5 = (b ^ c) ^ d

    add.l   \1,\5      * add ctx_a
    add.l   \7+ctx_block(a0),\5    * add block value
    add.l   \6,\5   * add constant
    endm


; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - out
stepIa macro 
    move.l  (a2)+,a4   * read block address

    ;(y) ^ ((x) | ~(z))
    move.l  \4,\5
    not.l   \5          * \5 = ~d
    or.l    \2,\5       * \5 = (~d) | b
    eor.l   \3,\5       * \5 = ((~d) | b) ^ c

    add.l   \1,\5      * add ctx_a
    add.l   (a4),\5    * add block value
    add.l   (a2)+,\5   * add constant
    endm

; \1 a
; \2 b
; \3 c
; \4 d
; \5 tmp - out
; \6 constant
; \7 block offset
stepIa2 macro 
    ;(y) ^ ((x) | ~(z))
    move.l  \4,\5
    not.l   \5          * \5 = ~d
    or.l    \2,\5       * \5 = (~d) | b
    eor.l   \3,\5       * \5 = ((~d) | b) ^ c

    add.l   \1,\5      * add ctx_a
    add.l   \7+ctx_block(a0),\5    * add block value
    add.l   \6,\5   * add constant
    endm

; \1 a
; \2 b
; \3 c
; \4 d - overwritten, out
stepIb macro 
    move.l  (a2)+,a4   * read block address

    ;(y) ^ ((x) | ~(z))
    not.l   \4          * \4 = ~d
    or.l    \2,\4       * \4 = (~d) | b
    eor.l   \3,\4       * \4 = ((~d) | b) ^ c

    add.l   \1,\4      * add ctx_a
    add.l   (a4),\4    * add block value
    add.l   (a2)+,\4   * add constant
    endm

; \1 a
; \2 b
; \3 c
; \4 d - overwritten, out
; \5 constant
; \6 block offset
stepIb2 macro 
    ;(y) ^ ((x) | ~(z))
    not.l   \4          * \4 = ~d
    or.l    \2,\4       * \4 = (~d) | b
    eor.l   \3,\4       * \4 = ((~d) | b) ^ c

    add.l   \1,\4      * add ctx_a
    add.l   \6+ctx_block(a0),\4    * add block value
    add.l   \5,\4   * add constant
    endm

* Reference implementation
*
* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position
MD5_Body:
    ; ---------------------------------
    lea     (a1,d0.l),a3       * loop end
.loop
    ; ---------------------------------
    movem.l ctx_a(a0),d4/d5/d6/d7
    lea     stepsF(pc),a2
    ; Copy 64 bytes here 
    lea     ctx_block(a0),a6
    ; ---------------------------------
    moveq   #16/4-1,d3
.stepLoopF:
    *       A  B  C  D  t1 t2
    stepFa  d4,d5,d6,d7,d0,d1
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t1 t2
    stepFa  d7,d0,d5,d6,d2,d1
    swap    d2         * <<< 12
    ror.l   #4,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t1 t2
    stepFa  d6,d2,d0,d5,d7,d1
    swap    d7         * <<< 17
    rol.l   #1,d7
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    *       A  B  C  D  t1
    stepFb  d5,d6,d2,d0,d1
    swap    d2         * <<< 22
    rol.l   #6,d2      * <<<
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    dbf     d3,.stepLoopF
    ; ---------------------------------
    lea     ctx_stepsGHI(a0),a2
    moveq   #16/4-1,d3
.stepLoopG:
    *       A  B  C  D  t 
    stepGa  d4,d5,d6,d7,d0
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepGa  d7,d0,d5,d6,d2
    swap    d2         * <<< 9
    ror.l   #7,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepGa  d6,d2,d0,d5,d7
    swap    d7         * <<< 14
    ror.l   #2,d7
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    move.l  d7,d6      * rotate: c = b 
    *       A  B  C  D 
    stepGb  d5,d7,d2,d0
    swap    d7         * <<< 20
    rol.l   #4,d7      * <<<
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    dbf     d3,.stepLoopG
    ; ---------------------------------
    moveq   #16/4-1,d3
.stepLoopH:
    *       A  B  C  D  t  t2
    stepHa  d4,d5,d6,d7,d0,d2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepHb  d7,d0,d5,d6,d2
    swap    d2         * <<< 11
    ror.l   #5,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t  t2
    stepHa  d6,d2,d0,d5,d7,d4
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepHb  d5,d7,d2,d0,d4
    swap    d4         * <<< 23
    rol.l   #7,d4      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    dbf     d3,.stepLoopH
    ; ---------------------------------
    moveq   #16/4-1,d3
.stepLoopI:
    *       A  B  C  D  t
    stepIa  d4,d5,d6,d7,d0
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepIa  d7,d0,d5,d6,d2
    swap    d2         * <<< 10
    ror.l   #6,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepIa  d6,d2,d0,d5,d7
    swap    d7         * <<< 15
    ror.l   #1,d7
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    move.l  d0,d4      * rotate: a = d
    *       A  B  C  D 
    stepIb  d5,d7,d2,d0
    swap    d0         * <<< 21
    rol.l   #5,d0      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    ; ---------------------------------
    dbf     d3,.stepLoopI
    ; ---------------------------------
    add.l   d4,ctx_a(a0)
    add.l   d5,ctx_b(a0)
    add.l   d6,ctx_c(a0)
    add.l   d7,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1      * check if end of last block
    bne     .loop
    rts

* 68020/68030 specific
* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position
MD5_Body_68020:
    ; ---------------------------------
    lea     (a1,d0.l),a3       * loop end
.loop
    ; ---------------------------------
    movem.l ctx_a(a0),d4/d5/d6/d7
    lea     stepsF(pc),a2
    ; Copy 64 bytes here 
    lea     ctx_block(a0),a6
    ; ---------------------------------
    moveq   #16/4-1,d3
.stepLoopF:
    *       A  B  C  D  t1 t2
    stepFa  d4,d5,d6,d7,d0,d1
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t1 t2
    stepFa  d7,d0,d5,d6,d2,d1
    moveq   #12,d4
    rol.l   d4,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t1 t2
    stepFa  d6,d2,d0,d5,d7,d1
    moveq   #17,d4
    rol.l   d4,d7
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    *       A  B  C  D  t1
    stepFb  d5,d6,d2,d0,d1
    moveq   #22,d4
    rol.l   d4,d2
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    dbf     d3,.stepLoopF
    ; ---------------------------------
    lea     ctx_stepsGHI(a0),a2
    moveq   #16/4-1,d3
.stepLoopG:
    *       A  B  C  D  t 
    stepGa  d4,d5,d6,d7,d0
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepGa  d7,d0,d5,d6,d2
    moveq   #9,d4
    rol.l   d4,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepGa  d6,d2,d0,d5,d7
    moveq   #14,d4
    rol.l   d4,d7
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    move.l  d7,d6      * rotate: c = b 
    *       A  B  C  D 
    stepGb  d5,d7,d2,d0
    moveq   #20,d4
    rol.l   d4,d7
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    dbf     d3,.stepLoopG
    ; ---------------------------------
    moveq   #16/4-1,d3
.stepLoopH:
    *       A  B  C  D  t  t2
    stepHa  d4,d5,d6,d7,d0,d2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepHb  d7,d0,d5,d6,d2
    moveq   #11,d4
    rol.l   d4,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t  t2
    stepHa  d6,d2,d0,d5,d7,d4
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepHb  d5,d7,d2,d0,d4
    moveq   #23,d1
    rol.l   d1,d4
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    dbf     d3,.stepLoopH
    ; ---------------------------------
    moveq   #16/4-1,d3
.stepLoopI:
    *       A  B  C  D  t
    stepIa  d4,d5,d6,d7,d0
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    * d0 = new b - goes to b
    * d5 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepIa  d7,d0,d5,d6,d2
    moveq   #10,d4
    rol.l   d4,d2
    add.l   d0,d2      * tmp += b
    * d2 = new b - goes to b    
    * d0 = old b - goes to c
    ; ---------------------------------
    *       A  B  C  D  t
    stepIa  d6,d2,d0,d5,d7
    moveq   #15,d4
    rol.l   d4,d7
    add.l   d2,d7      * tmp += b
    * d7 = new b - goes to b    
    * d2 = old b - goes to c
    ; ---------------------------------
    move.l  d0,d4      * rotate: a = d
    *       A  B  C  D 
    stepIb  d5,d7,d2,d0
    moveq   #21,d1
    rol.l   d1,d0
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    ; ---------------------------------
    dbf     d3,.stepLoopI
    ; ---------------------------------
    add.l   d4,ctx_a(a0)
    add.l   d5,ctx_b(a0)
    add.l   d6,ctx_c(a0)
    add.l   d7,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1      * check if end of last block
    bne     .loop
    rts



* 68020/68030 specific
* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position
MD5_Body_68020_dlx:
    ; ---------------------------------
    lea     (a1,d0.l),a3       * loop end
.loop
    ; ---------------------------------
		;     @dreg d,c,b,a,out,temp,loop,shift
		; live reg d7 => d
		; live reg d6 => c
		; live reg d5 => b
		; live reg d4 => a
		; live reg d3 => out
		; live reg d2 => temp
		; live reg d1 => loop
		; live reg d0 => shift
    move.l  ctx_a(a0),d4
    move.l  ctx_b(a0),d5
    move.l  ctx_c(a0),d6
    move.l  ctx_d(a0),d7
    lea     stepsF(pc),a2
    ; Copy 64 bytes here 
    lea     ctx_block(a0),a6
    ; ---------------------------------
    moveq   #16/8-1,d1
.stepLoopF:
    stepFa  d4,d5,d6,d7,d3,d2
    rol.l   #7,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa  d7,d3,d5,d6,d4,d2
    moveq   #12,d0
    rol.l   d0,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa  d6,d4,d3,d5,d7,d2
    moveq   #17,d0
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepFa  d5,d7,d4,d3,d6,d2
    moveq   #22,d0
    rol.l   d0,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepFa  d3,d6,d7,d4,d5,d2
    rol.l   #7,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepFa  d4,d5,d6,d7,d3,d2
    moveq   #12,d0
    rol.l   d0,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa  d7,d3,d5,d6,d4,d2
    moveq   #17,d0
    rol.l   d0,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa  d6,d4,d3,d5,d7,d2
    moveq   #22,d0
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out


 REM
    move.l d5,1
    move.l d7,2
    move.l d4,3
    move.l d3,4
 EREM
    move.l  d4,d6
    move.l  d5,d4
    move.l  d7,d5
    move.l  d3,d7
    ; ---------------------------------
    dbf     d1,.stepLoopF
		;     @kill a,b,c,d,out,temp,loop,shift
    ; ---------------------------------
		;     @dreg d,c,b,a,out,temp,loop,shift
		; live reg d7 => d
		; live reg d6 => c
		; live reg d5 => b
		; live reg d4 => a
		; live reg d3 => out
		; live reg d2 => temp
		; live reg d1 => loop
		; live reg d0 => shift
    lea     ctx_stepsGHI(a0),a2
    moveq   #16/8-1,d1
.stepLoopG:
    stepGa  d4,d5,d6,d7,d3,d2
    rol.l   #5,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa  d7,d3,d5,d6,d4,d2
    moveq   #9,d0
    rol.l   d0,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa  d6,d4,d3,d5,d7,d2
    moveq   #14,d0
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepGa  d5,d7,d4,d3,d6,d2
    moveq   #20,d0
    rol.l   d0,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepGa  d3,d6,d7,d4,d5,d2
    rol.l   #5,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepGa  d4,d5,d6,d7,d3,d2
    moveq   #9,d0
    rol.l   d0,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa  d7,d3,d5,d6,d4,d2
    moveq   #14,d0
    rol.l   d0,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa  d6,d4,d3,d5,d7,d2
    moveq   #20,d0
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out


 REM
    move.l d5,1
    move.l d7,2
    move.l d4,3
    move.l d3,4
 EREM
    move.l  d4,d6
    move.l  d5,d4
    move.l  d7,d5
    move.l  d3,d7
    ; ---------------------------------
    dbf     d1,.stepLoopG
    ; ---------------------------------
		;     @kill a,b,c,d,out,temp,loop,shift
		;     @dreg d,c,b,a,out,temp,loop,shift
		; live reg d7 => d
		; live reg d6 => c
		; live reg d5 => b
		; live reg d4 => a
		; live reg d3 => out
		; live reg d2 => temp
		; live reg d1 => loop
		; live reg d0 => shift
    moveq   #16/8-1,d1
.stepLoopH:
    stepHa  d4,d5,d6,d7,d3,d2
    rol.l   #4,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepHa  d7,d3,d5,d6,d4,d2
    moveq   #11,d0
    rol.l   d0,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepHa  d6,d4,d3,d5,d7,d2
    swap    d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepHa  d5,d7,d4,d3,d6,d2
    moveq   #23,d0
    rol.l   d0,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepHa  d3,d6,d7,d4,d5,d2
    rol.l   #4,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepHa  d4,d5,d6,d7,d3,d2
    moveq   #11,d0
    rol.l   d0,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepHa  d7,d3,d5,d6,d4,d2
    swap    d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepHa  d6,d4,d3,d5,d7,d2
    moveq   #23,d0
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out

 REM
    move.l d5,1
    move.l d7,2
    move.l d4,3
    move.l d3,4
 EREM
    move.l  d4,d6
    move.l  d5,d4
    move.l  d7,d5
    move.l  d3,d7
    ; ---------------------------------
    dbf     d1,.stepLoopH
    ; ---------------------------------
		;     @kill a,b,c,d,out,temp,loop,shift
		;     @dreg d,c,b,a,out,temp,loop,shift
		; live reg d7 => d
		; live reg d6 => c
		; live reg d5 => b
		; live reg d4 => a
		; live reg d3 => out
		; live reg d2 => temp
		; live reg d1 => loop
		; live reg d0 => shift
    moveq   #16/8-1,d1
.stepLoopI:
    stepIa  d4,d5,d6,d7,d3,d2
    rol.l   #6,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa  d7,d3,d5,d6,d4,d2
    moveq   #10,d0
    rol.l   d0,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa  d6,d4,d3,d5,d7,d2
    moveq   #15,d0
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepIa  d5,d7,d4,d3,d6,d2
    moveq   #21,d0
    rol.l   d0,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepIa  d3,d6,d7,d4,d5,d2
    rol.l   #6,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepIa  d4,d5,d6,d7,d3,d2
    moveq   #10,d0
    rol.l   d0,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa  d7,d3,d5,d6,d4,d2
    moveq   #15,d0
    rol.l   d0,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa  d6,d4,d3,d5,d7,d2
    moveq   #21,d0
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
 REM
    move.l d5,1
    move.l d7,2
    move.l d4,3
    move.l d3,4
 EREM
    move.l  d4,d6
    move.l  d5,d4
    move.l  d7,d5
    move.l  d3,d7
    ; ---------------------------------
    dbf     d1,.stepLoopI
		;     @kill a,b,c,d,out,temp,loop,shift
    ; ---------------------------------
    add.l   d4,ctx_a(a0)
    add.l   d5,ctx_b(a0)
    add.l   d6,ctx_c(a0)
    add.l   d7,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1      * check if end of last block
    bne     .loop
    rts




* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position

    cnop    0,4                * alignment
MD5_Body_small:
    lea     (a1,d0.l),a3       * loop end
.loop
    ; ---------------------------------
    movem.l ctx_a(a0),d4/d5/d6/d7
    lea     .steps(pc),a2
    ; First loop: copy data
    lea     ctx_block(a0),a6
    ; ---------------------------------
    moveq   #0,d1
    moveq   #16-1,d3
.stepLoopF:
    ;((z) ^ ((x) & ((y) ^ (z))))
    move.l  d6,d0
    eor.l   d7,d0       * d0 = c ^ d 
    and.l   d5,d0       * d0 = (c ^ d) & b
    eor.l   d7,d0       * d0 = ((c ^ d) & b) ^ d
    ; ---------------------------------
    move.l  (a1)+,d2
    ilword  d2
    move.l  d2,(a6)+
    add.l   d2,d0
    ; ---------------------------------
    add.l   (a2)+,d0
    add.l   d4,d0       * add ctx_a
    move.w  (a2)+,d2
    rol.l   d2,d0
    ; ---------------------------------
    move.l   d7,d4      * a = d
    move.l   d6,d7      * d = c
    move.l   d5,d6      * c = b
    add.l    d0,d5      * b = new sum, add ctx_b
    ; ---------------------------------
    dbf     d3,.stepLoopF
    ; ---------------------------------
    moveq   #16-1,d3
.stepLoopG:
    ;((y) ^ ((z) & ((x) ^ (y))))
    move.l  d5,d0
    eor.l   d6,d0       * d0 = b ^ c
    and.l   d7,d0       * d0 = (b ^ c) & d
    eor.l   d6,d0       * d0 = ((b ^ c) & d) ^ c
    ; ---------------------------------
    move.b  (a2)+,d1
    move.b  (a2)+,d2
    add.l   ctx_block(a0,d1),d0
    ; ---------------------------------
    add.l   (a2)+,d0
    add.l   d4,d0       * add ctx_a
    rol.l   d2,d0
    ; ---------------------------------
    move.l   d7,d4      * a = d
    move.l   d6,d7      * d = c
    move.l   d5,d6      * c = b
    add.l    d0,d5      * b = new sum, add ctx_b
    ; ---------------------------------
    dbf     d3,.stepLoopG
    ; ---------------------------------
    moveq   #16-1,d3
.stepLoopH:
    ;(x) ^ (y) ^ (z)
    move.l  d5,d0       
    eor.l   d6,d0       * d0 = b ^ c
    eor.l   d7,d0       * d0 = (b ^ c) ^ d
    ; ---------------------------------
    move.b  (a2)+,d1
    move.b  (a2)+,d2
    add.l   ctx_block(a0,d1),d0
    ; ---------------------------------
    add.l   (a2)+,d0
    add.l   d4,d0       * add ctx_a
    rol.l   d2,d0
    ; ---------------------------------
    move.l   d7,d4      * a = d
    move.l   d6,d7      * d = c
    move.l   d5,d6      * c = b
    add.l    d0,d5      * b = new sum, add ctx_b
    ; ---------------------------------
    dbf     d3,.stepLoopH
    ; ---------------------------------
    moveq   #16-1,d3
.stepLoopI:
    ;(y) ^ ((x) | ~(z))
    move.l  d7,d0
    not.l   d0          * d0 = ~d
    or.l    d5,d0       * d0 = (~d) | b
    eor.l   d6,d0       * d0 = ((~d) | b) ^ c
    ; ---------------------------------
    move.b  (a2)+,d1
    move.b  (a2)+,d2
    add.l   ctx_block(a0,d1),d0
    ; ---------------------------------
    add.l   (a2)+,d0
    add.l   d4,d0       * add ctx_a
    rol.l   d2,d0
    ; ---------------------------------
    move.l   d7,d4      * a = d
    move.l   d6,d7      * d = c
    move.l   d5,d6      * c = b
    add.l    d0,d5      * b = new sum, add ctx_b
    ; ---------------------------------
    dbf     d3,.stepLoopI
    ; ---------------------------------
    add.l   d4,ctx_a(a0)
    add.l   d5,ctx_b(a0)
    add.l   d6,ctx_c(a0)
    add.l   d7,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1
    bne     .loop
    rts



* 64 steps
.steps:
;         dc.w 0<<2
         dc.l $d76aa478 
         dc.w 7

;         dc.w 1<<2
         dc.l $e8c7b756 
         dc.w 12

;         dc.w 2<<2
         dc.l $242070db 
         dc.w 17

;         dc.w 3<<2
         dc.l $c1bdceee 
         dc.w 22

;         dc.w 4<<2
         dc.l $f57c0faf 
         dc.w 7

;         dc.w 5<<2
         dc.l $4787c62a 
         dc.w 12

;         dc.w 6<<2
         dc.l $a8304613 
         dc.w 17

;         dc.w 7<<2
         dc.l $fd469501 
         dc.w 22

;         dc.w 8<<2
         dc.l $698098d8 
         dc.w 7

;         dc.w 9<<2
         dc.l $8b44f7af 
         dc.w 12

;         dc.w 10<<2
         dc.l $ffff5bb1 
         dc.w 17

;         dc.w 11<<2
         dc.l $895cd7be 
         dc.w 22

;         dc.w 12<<2
         dc.l $6b901122 
         dc.w 7

;         dc.w 13<<2
         dc.l $fd987193 
         dc.w 12

;         dc.w 14<<2
         dc.l $a679438e 
         dc.w 17

;         dc.w 15<<2
         dc.l $49b40821 
         dc.w 22

         dc.b 1<<2
         dc.b 5
         dc.l $f61e2562 

         dc.b 6<<2
         dc.b 9
         dc.l $c040b340 

         dc.b 11<<2
         dc.b 14
         dc.l $265e5a51 

         dc.b 0<<2
         dc.b 20
         dc.l $e9b6c7aa 

         dc.b 5<<2
         dc.b 5
         dc.l $d62f105d 

         dc.b 10<<2
         dc.b 9
         dc.l $02441453 

         dc.b 15<<2
         dc.b 14
         dc.l $d8a1e681 

         dc.b 4<<2
         dc.b 20
         dc.l $e7d3fbc8 

         dc.b 9<<2
         dc.b 5
         dc.l $21e1cde6 

         dc.b 14<<2
         dc.b 9
         dc.l $c33707d6 

         dc.b 3<<2
         dc.b 14
         dc.l $f4d50d87 

         dc.b 8<<2
         dc.b 20
         dc.l $455a14ed 

         dc.b 13<<2
         dc.b 5
         dc.l $a9e3e905 

         dc.b 2<<2
         dc.b 9
         dc.l $fcefa3f8 

         dc.b 7<<2
         dc.b 14
         dc.l $676f02d9 

         dc.b 12<<2
         dc.b 20
         dc.l $8d2a4c8a 

         dc.b 5<<2
         dc.b 4
         dc.l $fffa3942 

         dc.b 8<<2
         dc.b 11
         dc.l $8771f681 

         dc.b 11<<2
         dc.b 16
         dc.l $6d9d6122 

         dc.b 14<<2
         dc.b 23
         dc.l $fde5380c 

         dc.b 1<<2
         dc.b 4
         dc.l $a4beea44 

         dc.b 4<<2
         dc.b 11
         dc.l $4bdecfa9 

         dc.b 7<<2
         dc.b 16
         dc.l $f6bb4b60 

         dc.b 10<<2
         dc.b 23
         dc.l $bebfbc70 

         dc.b 13<<2
         dc.b 4
         dc.l $289b7ec6 

         dc.b 0<<2
         dc.b 11
         dc.l $eaa127fa 

         dc.b 3<<2
         dc.b 16
         dc.l $d4ef3085 

         dc.b 6<<2
         dc.b 23
         dc.l $04881d05 

         dc.b 9<<2
         dc.b 4
         dc.l $d9d4d039 

         dc.b 12<<2
         dc.b 11
         dc.l $e6db99e5 

         dc.b 15<<2
         dc.b 16
         dc.l $1fa27cf8 

         dc.b 2<<2
         dc.b 23
         dc.l $c4ac5665 

         dc.b 0<<2
         dc.b 6
         dc.l $f4292244 

         dc.b 7<<2
         dc.b 10
         dc.l $432aff97 

         dc.b 14<<2
         dc.b 15
         dc.l $ab9423a7 

         dc.b 5<<2
         dc.b 21
         dc.l $fc93a039 

         dc.b 12<<2
         dc.b 6
         dc.l $655b59c3 

         dc.b 3<<2
         dc.b 10
         dc.l $8f0ccc92 

         dc.b 10<<2
         dc.b 15
         dc.l $ffeff47d 

         dc.b 1<<2
         dc.b 21
         dc.l $85845dd1 

         dc.b 8<<2
         dc.b 6
         dc.l $6fa87e4f 

         dc.b 15<<2
         dc.b 10
         dc.l $fe2ce6e0 

         dc.b 6<<2
         dc.b 15
         dc.l $a3014314 

         dc.b 13<<2
         dc.b 21
         dc.l $4e0811a1 

         dc.b 4<<2
         dc.b 6
         dc.l $f7537e82 

         dc.b 11<<2
         dc.b 10
         dc.l $bd3af235 

         dc.b 2<<2
         dc.b 15
         dc.l $2ad7d2bb 

         dc.b 9<<2
         dc.b 21
         dc.l $eb86d391 

         dc   -1 ; END


* 68000 specific
*
* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position
MD5_Body_68000:
    ; ---------------------------------
    lea     (a1,d0.l),a3       * loop end
.loop
    ; ---------------------------------
    movem.l ctx_a(a0),d4/d5/d6/d7
    lea     ctx_block(a0),a6
    lea     steps(pc),a2
    ; ---------------------------------
    stepFa2 d4,d5,d6,d7,d0,d1,(a2)+
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,(a2)+
    swap    d2         * <<< 12
    ror.l   #4,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,(a2)+
    swap    d7         * <<< 17
    rol.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,(a2)+
    swap    d2         * <<< 22
    rol.l   #6,d2      * <<<
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    stepFa2 d4,d5,d6,d7,d0,d1,(a2)+
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,(a2)+
    swap    d2         * <<< 12
    ror.l   #4,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,(a2)+
    swap    d7         * <<< 17
    rol.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,(a2)+
    swap    d2         * <<< 22
    rol.l   #6,d2      * <<<
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    stepFa2 d4,d5,d6,d7,d0,d1,(a2)+
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,(a2)+
    swap    d2         * <<< 12
    ror.l   #4,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,(a2)+
    swap    d7         * <<< 17
    rol.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,(a2)+
    swap    d2         * <<< 22
    rol.l   #6,d2      * <<<
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    stepFa2 d4,d5,d6,d7,d0,d1,(a2)+
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,(a2)+
    swap    d2         * <<< 12
    ror.l   #4,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,(a2)+
    swap    d7         * <<< 17
    rol.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,(a2)+
    swap    d2         * <<< 22
    rol.l   #6,d2      * <<<
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    stepGa2 d4,d5,d6,d7,d0,(a2)+,1<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,(a2)+,6<<2
    swap    d2         * <<< 9
    ror.l   #7,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,(a2)+,11<<2
    swap    d7         * <<< 14
    ror.l   #2,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,(a2)+,0<<2
    swap    d7         * <<< 20
    rol.l   #4,d7      * <<<
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepGa2 d4,d5,d6,d7,d0,(a2)+,5<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,(a2)+,10<<2
    swap    d2         * <<< 9
    ror.l   #7,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,(a2)+,15<<2
    swap    d7         * <<< 14
    ror.l   #2,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,(a2)+,4<<2
    swap    d7         * <<< 20
    rol.l   #4,d7      * <<<
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepGa2 d4,d5,d6,d7,d0,(a2)+,9<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,(a2)+,14<<2
    swap    d2         * <<< 9
    ror.l   #7,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,(a2)+,3<<2
    swap    d7         * <<< 14
    ror.l   #2,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,(a2)+,8<<2
    swap    d7         * <<< 20
    rol.l   #4,d7      * <<<
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepGa2 d4,d5,d6,d7,d0,(a2)+,13<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,(a2)+,2<<2
    swap    d2         * <<< 9
    ror.l   #7,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,(a2)+,7<<2
    swap    d7         * <<< 14
    ror.l   #2,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,(a2)+,12<<2
    swap    d7         * <<< 20
    rol.l   #4,d7      * <<<
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    stepHa2 d4,d5,d6,d7,d0,d2,(a2)+,5<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,(a2)+,8<<2
    swap    d2         * <<< 11
    ror.l   #5,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,(a2)+,11<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,(a2)+,14<<2
    swap    d4         * <<< 23
    rol.l   #7,d4      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepHa2 d4,d5,d6,d7,d0,d2,(a2)+,1<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,(a2)+,4<<2
    swap    d2         * <<< 11
    ror.l   #5,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,(a2)+,7<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,(a2)+,10<<2
    swap    d4         * <<< 23
    rol.l   #7,d4      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepHa2 d4,d5,d6,d7,d0,d2,(a2)+,13<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,(a2)+,0<<2
    swap    d2         * <<< 11
    ror.l   #5,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,(a2)+,3<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,(a2)+,6<<2
    swap    d4         * <<< 23
    rol.l   #7,d4      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepHa2 d4,d5,d6,d7,d0,d2,(a2)+,9<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,(a2)+,12<<2
    swap    d2         * <<< 11
    ror.l   #5,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,(a2)+,15<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,(a2)+,2<<2
    swap    d4         * <<< 23
    rol.l   #7,d4      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    stepIa2 d4,d5,d6,d7,d0,(a2)+,0<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,(a2)+,7<<2
    swap    d2         * <<< 10
    ror.l   #6,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,(a2)+,14<<2
    swap    d7         * <<< 15
    ror.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,(a2)+,5<<2
    swap    d0         * <<< 21
    rol.l   #5,d0      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    stepIa2 d4,d5,d6,d7,d0,(a2)+,12<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,(a2)+,3<<2
    swap    d2         * <<< 10
    ror.l   #6,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,(a2)+,10<<2
    swap    d7         * <<< 15
    ror.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,(a2)+,1<<2
    swap    d0         * <<< 21
    rol.l   #5,d0      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    stepIa2 d4,d5,d6,d7,d0,(a2)+,8<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,(a2)+,15<<2
    swap    d2         * <<< 10
    ror.l   #6,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,(a2)+,6<<2
    swap    d7         * <<< 15
    ror.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,(a2)+,13<<2
    swap    d0         * <<< 21
    rol.l   #5,d0      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    stepIa2 d4,d5,d6,d7,d0,(a2)+,4<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,(a2)+,11<<2
    swap    d2         * <<< 10
    ror.l   #6,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,(a2)+,2<<2
    swap    d7         * <<< 15
    ror.l   #1,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,(a2)+,9<<2
    swap    d0         * <<< 21
    rol.l   #5,d0      * <<<
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    ; ---------------------------------
    add.l   d4,ctx_a(a0)
    add.l   d5,ctx_b(a0)
    add.l   d6,ctx_c(a0)
    add.l   d7,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1      * check if end of last block
    bne     .loop
    rts

* FSUAE 68000 kick 1.3: 
* - norm: 7400ms
* - dlx: 7320ms
* - dlx with stepHb2: 7200 ms
* - dlx indirect constants: 7140 ms
 

* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position
MD5_Body_68000_dlx:
    ; ---------------------------------
    lea     (a1,d0.l),a3       * loop end
.loop
    lea     steps(pc),a2
    ; ---------------------------------
		;     @dreg d,c,b,a,out,temp
		; live reg d7 => d
		; live reg d6 => c
		; live reg d5 => b
		; live reg d4 => a
		; live reg d3 => out
		; live reg d2 => temp
    move.l  ctx_a(a0),d4
    move.l  ctx_b(a0),d5
    move.l  ctx_c(a0),d6
    move.l  ctx_d(a0),d7
    lea     ctx_block(a0),a6
    ; ---------------------------------
    stepFa2 d4,d5,d6,d7,d3,d2,(a2)+
    rol.l   #7,d3      * <<< 7
    add.l   d5,d3      * add ctx_b, b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa2 d7,d3,d5,d6,d4,d2,(a2)+
    swap    d4         * <<< 12
    ror.l   #4,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa2 d6,d4,d3,d5,d7,d2,(a2)+
    swap    d7         * <<< 17
    rol.l   #1,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepFa2 d5,d7,d4,d3,d6,d2,(a2)+  ;;;;;;;;
    swap    d6         * <<< 22
    rol.l   #6,d6      * <<<
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepFa2 d3,d6,d7,d4,d5,d2,(a2)+
    rol.l   #7,d5      * <<< 7
    add.l   d6,d5      * add ctx_b, b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepFa2 d4,d5,d6,d7,d3,d2,(a2)+
    swap    d3         * <<< 12
    ror.l   #4,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa2 d7,d3,d5,d6,d4,d2,(a2)+
    swap    d4         * <<< 17
    rol.l   #1,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa2 d6,d4,d3,d5,d7,d2,(a2)+
    swap    d7         * <<< 22
    rol.l   #6,d7      * <<<
    add.l   d4,d7      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepFa2 d5,d7,d4,d3,d6,d2,(a2)+
    rol.l   #7,d6      * <<< 7
    add.l   d7,d6      * add ctx_b, b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepFa2 d3,d6,d7,d4,d5,d2,(a2)+
    swap    d5         * <<< 12
    ror.l   #4,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepFa2 d4,d5,d6,d7,d3,d2,(a2)+
    swap    d3         * <<< 17
    rol.l   #1,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa2 d7,d3,d5,d6,d4,d2,(a2)+
    swap    d4         * <<< 22
    rol.l   #6,d4      * <<<
    add.l   d3,d4      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa2 d6,d4,d3,d5,d7,d2,(a2)+
    rol.l   #7,d7      * <<< 7
    add.l   d4,d7      * add ctx_b, b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepFa2 d5,d7,d4,d3,d6,d2,(a2)+
    swap    d6         * <<< 12
    ror.l   #4,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepFa2 d3,d6,d7,d4,d5,d2,(a2)+
    swap    d5         * <<< 17
    rol.l   #1,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepFa2 d4,d5,d6,d7,d3,d2,(a2)+
    swap    d3         * <<< 22
    rol.l   #6,d3      * <<<
    add.l   d5,d3      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    ; ---------------------------------
    stepGa2 d7,d3,d5,d6,d4,(a2)+,1<<2
    rol.l   #5,d4      * <<< 5
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa2 d6,d4,d3,d5,d7,(a2)+,6<<2
    swap    d7         * <<< 9
    ror.l   #7,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepGa2 d5,d7,d4,d3,d6,(a2)+,11<<2
    swap    d6         * <<< 14
    ror.l   #2,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepGa2 d3,d6,d7,d4,d5,(a2)+,0<<2
    swap    d5         * <<< 20
    rol.l   #4,d5      * <<<
    add.l   d6,d5      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepGa2 d4,d5,d6,d7,d3,(a2)+,5<<2
    rol.l   #5,d3      * <<< 5
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa2 d7,d3,d5,d6,d4,(a2)+,10<<2
    swap    d4         * <<< 9
    ror.l   #7,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa2 d6,d4,d3,d5,d7,(a2)+,15<<2
    swap    d7         * <<< 14
    ror.l   #2,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepGa2 d5,d7,d4,d3,d6,(a2)+,4<<2
    swap    d6         * <<< 20
    rol.l   #4,d6      * <<<
    add.l   d7,d6      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepGa2 d3,d6,d7,d4,d5,(a2)+,9<<2
    rol.l   #5,d5      * <<< 5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepGa2 d4,d5,d6,d7,d3,(a2)+,14<<2
    swap    d3         * <<< 9
    ror.l   #7,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa2 d7,d3,d5,d6,d4,(a2)+,3<<2
    swap    d4         * <<< 14
    ror.l   #2,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa2 d6,d4,d3,d5,d7,(a2)+,8<<2
    swap    d7         * <<< 20
    rol.l   #4,d7      * <<<
    add.l   d4,d7      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepGa2 d5,d7,d4,d3,d6,(a2)+,13<<2
    rol.l   #5,d6      * <<< 5
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepGa2 d3,d6,d7,d4,d5,(a2)+,2<<2
    swap    d5         * <<< 9
    ror.l   #7,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepGa2 d4,d5,d6,d7,d3,(a2)+,7<<2
    swap    d3         * <<< 14
    ror.l   #2,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa2 d7,d3,d5,d6,d4,(a2)+,12<<2
    swap    d4         * <<< 20
    rol.l   #4,d4      * <<<
    add.l   d3,d4      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    ; --------------------------------
    
    stepHa2 d6,d4,d3,d5,d7,d2,(a2)+,5<<2
    rol.l   #4,d7      * <<< 4
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d5,d7,d4,d3,d2,(a2)+,8<<2
		;     @rename temp out
    swap    d2         * <<< 11
    ror.l   #5,d2
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d6 => out
		; live reg d5 => temp
    stepHa2 d3,d2,d7,d4,d6,d5,(a2)+,11<<2
    swap    d6         * <<< 16
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d4,d6,d2,d7,d5,(a2)+,14<<2
		;     @rename temp out
    swap    d5         * <<< 23
    rol.l   #7,d5      * <<<
    add.l   d6,d5      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d4 => out
		; live reg d3 => temp
    stepHa2 d7,d5,d6,d2,d4,d3,(a2)+,1<<2
    rol.l   #4,d4      * <<< 4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d2,d4,d5,d6,d3,(a2)+,4<<2
		;     @rename temp out
    swap    d3         * <<< 11
    ror.l   #5,d3
    add.l   d4,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d7 => out
		; live reg d2 => temp
    stepHa2 d6,d3,d4,d5,d7,d2,(a2)+,7<<2
    swap    d7         * <<< 16
    add.l   d3,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d5,d7,d3,d4,d2,(a2)+,10<<2
		;     @rename temp out
    swap    d2         * <<< 23
    rol.l   #7,d2      * <<<
    add.l   d7,d2      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d6 => out
		; live reg d5 => temp
    stepHa2 d4,d2,d7,d3,d6,d5,(a2)+,13<<2
    rol.l   #4,d6      * <<< 4
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d3,d6,d2,d7,d5,(a2)+,0<<2
		;     @rename temp out
    swap    d5         * <<< 11
    ror.l   #5,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d4 => out
		; live reg d3 => temp
    stepHa2 d7,d5,d6,d2,d4,d3,(a2)+,3<<2
    swap    d4         * <<< 16
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d2,d4,d5,d6,d3,(a2)+,6<<2
		;     @rename temp out
    swap    d3         * <<< 23
    rol.l   #7,d3      * <<<
    add.l   d4,d3      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d7 => out
		; live reg d2 => temp
    stepHa2 d6,d3,d4,d5,d7,d2,(a2)+,9<<2
    rol.l   #4,d7      * <<< 4
    add.l   d3,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d5,d7,d3,d4,d2,(a2)+,12<<2
		;     @rename temp out
    swap    d2         * <<< 11
    ror.l   #5,d2
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d6 => out
		; live reg d5 => temp
    stepHa2 d4,d2,d7,d3,d6,d5,(a2)+,15<<2
    swap    d6         * <<< 16
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d3,d6,d2,d7,d5,(a2)+,2<<2
		;     @rename temp out
    swap    d5         * <<< 23
    rol.l   #7,d5      * <<<
    add.l   d6,d5      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d4 => out
		; live reg d3 => temp
    ; ---------------------------------
    stepIa2 d7,d5,d6,d2,d4,(a2)+,0<<2
    rol.l   #6,d4      * tmp <<< 6
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa2 d2,d4,d5,d6,d7,(a2)+,7<<2
    swap    d7         * <<< 10
    ror.l   #6,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d2 => out
    stepIa2 d6,d7,d4,d5,d2,(a2)+,14<<2
    swap    d2         * <<< 15
    ror.l   #1,d2
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepIa2 d5,d2,d7,d4,d6,(a2)+,5<<2
    swap    d6         * <<< 21
    rol.l   #5,d6      * <<<
    add.l   d2,d6      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepIa2 d4,d6,d2,d7,d5,(a2)+,12<<2
    rol.l   #6,d5      * tmp <<< 6
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa2 d7,d5,d6,d2,d4,(a2)+,3<<2
    swap    d4         * <<< 10
    ror.l   #6,d4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa2 d2,d4,d5,d6,d7,(a2)+,10<<2
    swap    d7         * <<< 15
    ror.l   #1,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d2 => out
    stepIa2 d6,d7,d4,d5,d2,(a2)+,1<<2
    swap    d2         * <<< 21
    rol.l   #5,d2      * <<<
    add.l   d7,d2      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepIa2 d5,d2,d7,d4,d6,(a2)+,8<<2
    rol.l   #6,d6      * tmp <<< 6
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepIa2 d4,d6,d2,d7,d5,(a2)+,15<<2
    swap    d5         * <<< 10
    ror.l   #6,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa2 d7,d5,d6,d2,d4,(a2)+,6<<2
    swap    d4         * <<< 15
    ror.l   #1,d4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa2 d2,d4,d5,d6,d7,(a2)+,13<<2
    swap    d7         * <<< 21
    rol.l   #5,d7      * <<<
    add.l   d4,d7      * d0: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d2 => out
    stepIa2 d6,d7,d4,d5,d2,(a2)+,4<<2
    rol.l   #6,d2      * tmp <<< 6
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepIa2 d5,d2,d7,d4,d6,(a2)+,11<<2
    swap    d6         * <<< 10
    ror.l   #6,d6
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepIa2 d4,d6,d2,d7,d5,(a2)+,2<<2
    swap    d5         * <<< 15
    ror.l   #1,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa2 d7,d5,d6,d2,d4,(a2)+,9<<2
    swap    d4         * <<< 21
    rol.l   #5,d4      * <<<
    add.l   d5,d4
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    ; ---------------------------------
    add.l   d2,ctx_a(a0)
    add.l   d4,ctx_b(a0)
    add.l   d5,ctx_c(a0)
    add.l   d6,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1      * check if end of last block
    bne     .loop
    rts
		;     @kill a,b,c,d,out,temp

* 68040/68060 specific
*
* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position
MD5_Body_68040:
    ; ---------------------------------
    lea     (a1,d0.l),a3       * loop end
.loop
    ; ---------------------------------
    movem.l ctx_a(a0),d4/d5/d6/d7
    lea     ctx_block(a0),a6
    ; ---------------------------------
    stepFa2 d4,d5,d6,d7,d0,d1,#$d76aa478
    moveq   #7,d3
    rol.l   d3,d0
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,#$e8c7b756
    moveq   #12,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,#$242070db
    moveq   #17,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,#$c1bdceee
    moveq   #22,d3
    rol.l   d3,d2
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    stepFa2 d4,d5,d6,d7,d0,d1,#$f57c0faf
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,#$4787c62a
    moveq   #12,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,#$a8304613
    moveq   #17,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,#$fd469501
    moveq   #22,d3
    rol.l   d3,d2
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    stepFa2 d4,d5,d6,d7,d0,d1,#$698098d8
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,#$8b44f7af
    moveq   #12,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,#$ffff5bb1
    moveq   #17,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,#$895cd7be
    moveq   #22,d3
    rol.l   d3,d2
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    stepFa2 d4,d5,d6,d7,d0,d1,#$6b901122
    rol.l   #7,d0      * <<< 7
    add.l   d5,d0      * add ctx_b, b = new sum
    stepFa2 d7,d0,d5,d6,d2,d1,#$fd987193
    moveq   #12,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepFa2 d6,d2,d0,d5,d7,d1,#$a679438e
    moveq   #17,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    move.l  d2,d7      * rotate: d = c
    stepFb2 d5,d6,d2,d0,d1,#$49b40821
    moveq   #22,d3
    rol.l   d3,d2
    move.l  d6,d5      * new b
    add.l   d2,d5      * rotate: b = new sum
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    stepGa2 d4,d5,d6,d7,d0,#$f61e2562,1<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,#$c040b340,6<<2
    moveq   #9,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,#$265e5a51,11<<2
    moveq   #14,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,#$e9b6c7aa,0<<2
    moveq   #20,d3
    rol.l   d3,d7
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepGa2 d4,d5,d6,d7,d0,#$d62f105d,5<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,#$02441453,10<<2
    moveq   #9,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,#$d8a1e681,15<<2
    moveq   #14,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,#$e7d3fbc8,4<<2
    moveq   #20,d3
    rol.l   d3,d7
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepGa2 d4,d5,d6,d7,d0,#$21e1cde6,9<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,#$c33707d6,14<<2
    moveq   #9,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,#$f4d50d87,3<<2
    moveq   #14,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,#$455a14ed,8<<2
    moveq   #20,d3
    rol.l   d3,d7
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepGa2 d4,d5,d6,d7,d0,#$a9e3e905,13<<2
    rol.l   #5,d0      * <<< 5
    add.l   d5,d0      * tmp += b
    stepGa2 d7,d0,d5,d6,d2,#$fcefa3f8,2<<2
    moveq   #9,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepGa2 d6,d2,d0,d5,d7,#$676f02d9,7<<2
    moveq   #14,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d7,d6      * rotate: c = b 
    stepGb2 d5,d7,d2,d0,#$8d2a4c8a,12<<2
    moveq   #20,d3
    rol.l   d3,d7
    move.l  d6,d5      * new b
    add.l   d7,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    stepHa2 d4,d5,d6,d7,d0,d2,#$fffa3942,5<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,#$8771f681,8<<2
    moveq   #11,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,#$6d9d6122,11<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,#$fde5380c,14<<2
    moveq   #23,d3
    rol.l   d3,d4
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepHa2 d4,d5,d6,d7,d0,d2,#$a4beea44,1<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,#$4bdecfa9,4<<2
    moveq   #11,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,#$f6bb4b60,7<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,#$bebfbc70,10<<2
    moveq   #23,d3
    rol.l   d3,d4
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepHa2 d4,d5,d6,d7,d0,d2,#$289b7ec6,13<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,#$eaa127fa,0<<2
    moveq   #11,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,#$d4ef3085,3<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,#$04881d05,6<<2
    moveq   #23,d3
    rol.l   d3,d4
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    stepHa2 d4,d5,d6,d7,d0,d2,#$d9d4d039,9<<2
    rol.l   #4,d0      * <<< 4
    add.l   d5,d0      * tmp += b
    stepHb2 d7,d0,d5,d6,d2,#$e6db99e5,12<<2
    moveq   #11,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepHa2 d6,d2,d0,d5,d7,d4,#$1fa27cf8,15<<2
    swap    d7         * <<< 16
    add.l   d2,d7      * tmp += b
    stepHb2 d5,d7,d2,d0,d4,#$c4ac5665,2<<2
    moveq   #23,d3
    rol.l   d3,d4
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d4,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    move.l  d0,d4      * rotate: a = d
    ; ---------------------------------
    stepIa2 d4,d5,d6,d7,d0,#$f4292244,0<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,#$432aff97,7<<2
    moveq   #10,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,#$ab9423a7,14<<2
    moveq   #15,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,#$fc93a039,5<<2
    moveq   #21,d3
    rol.l   d3,d0
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    stepIa2 d4,d5,d6,d7,d0,#$655b59c3,12<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,#$8f0ccc92,3<<2
    moveq   #10,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,#$ffeff47d,10<<2
    moveq   #15,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,#$85845dd1,1<<2
    moveq   #21,d3
    rol.l   d3,d0
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    stepIa2 d4,d5,d6,d7,d0,#$6fa87e4f,8<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,#$fe2ce6e0,15<<2
    moveq   #10,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,#$a3014314,6<<2
    moveq   #15,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,#$4e0811a1,13<<2
    moveq   #21,d3
    rol.l   d3,d0
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    stepIa2 d4,d5,d6,d7,d0,#$f7537e82,4<<2
    rol.l   #6,d0      * tmp <<< 6
    add.l   d5,d0      * tmp += b
    stepIa2 d7,d0,d5,d6,d2,#$bd3af235,11<<2
    moveq   #10,d3
    rol.l   d3,d2
    add.l   d0,d2      * tmp += b
    stepIa2 d6,d2,d0,d5,d7,#$2ad7d2bb,2<<2
    moveq   #15,d3
    rol.l   d3,d7
    add.l   d2,d7      * tmp += b
    move.l  d0,d4      * rotate: a = d
    stepIb2 d5,d7,d2,d0,#$eb86d391,9<<2
    moveq   #21,d3
    rol.l   d3,d0
    move.l  d7,d5      * new b
    move.l  d7,d6      * rotate: c = b 
    add.l   d0,d5      * rotate: b = new sum
    move.l  d2,d7      * rotate: d = c
    ; ---------------------------------
    add.l   d4,ctx_a(a0)
    add.l   d5,ctx_b(a0)
    add.l   d6,ctx_c(a0)
    add.l   d7,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1      * check if end of last block
    bne     .loop
    rts


* In:
*   a0 = context
*   a1 = input data
*   d0 = input length
* Out:
*   a1 = input data, new position
MD5_Body_68040_dlx:
    ; ---------------------------------
    lea     (a1,d0.l),a3       * loop end
		;     @dreg d,c,b,a,out,temp,shift,shift15
		; live reg d7 => d
		; live reg d6 => c
		; live reg d5 => b
		; live reg d4 => a
		; live reg d3 => out
		; live reg d2 => temp
		; live reg d1 => shift
		; live reg d0 => shift15
    moveq   #15,d0    * use free reg for rol constant
.loop
    ; ---------------------------------
    move.l  ctx_a(a0),d4
    move.l  ctx_b(a0),d5
    move.l  ctx_c(a0),d6
    move.l  ctx_d(a0),d7
    lea     ctx_block(a0),a6
    ; ---------------------------------
    stepFa2 d4,d5,d6,d7,d3,d2,#$d76aa478
    rol.l   #7,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa2 d7,d3,d5,d6,d4,d2,#$e8c7b756
    moveq   #12,d1
    rol.l   d1,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa2 d6,d4,d3,d5,d7,d2,#$242070db
    moveq   #17,d1
    rol.l   d1,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepFa2 d5,d7,d4,d3,d6,d2,#$c1bdceee  ;;;;;;;;
    moveq   #22,d1
    rol.l   d1,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepFa2 d3,d6,d7,d4,d5,d2,#$f57c0faf
    rol.l   #7,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepFa2 d4,d5,d6,d7,d3,d2,#$4787c62a
    moveq   #12,d1
    rol.l   d1,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa2 d7,d3,d5,d6,d4,d2,#$a8304613
    moveq   #17,d1
    rol.l   d1,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa2 d6,d4,d3,d5,d7,d2,#$fd469501
    moveq   #22,d1
    rol.l   d1,d7
    add.l   d4,d7      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepFa2 d5,d7,d4,d3,d6,d2,#$698098d8
    rol.l   #7,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepFa2 d3,d6,d7,d4,d5,d2,#$8b44f7af
    moveq   #12,d1
    rol.l   d1,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepFa2 d4,d5,d6,d7,d3,d2,#$ffff5bb1
    moveq   #17,d1
    rol.l   d1,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepFa2 d7,d3,d5,d6,d4,d2,#$895cd7be
    moveq   #22,d1
    rol.l   d1,d4
    add.l   d3,d4      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepFa2 d6,d4,d3,d5,d7,d2,#$6b901122
    rol.l   #7,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepFa2 d5,d7,d4,d3,d6,d2,#$fd987193
    moveq   #12,d1
    rol.l   d1,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepFa2 d3,d6,d7,d4,d5,d2,#$a679438e
    moveq   #17,d1
    rol.l   d1,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepFa2 d4,d5,d6,d7,d3,d2,#$49b40821
    moveq   #22,d1
    rol.l   d1,d3
    add.l   d5,d3      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    ; ---------------------------------
    stepGa2 d7,d3,d5,d6,d4,#$f61e2562,1<<2
    rol.l   #5,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa2 d6,d4,d3,d5,d7,#$c040b340,6<<2
    moveq   #9,d1
    rol.l   d1,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepGa2 d5,d7,d4,d3,d6,#$265e5a51,11<<2
    moveq   #14,d1
    rol.l   d1,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepGa2 d3,d6,d7,d4,d5,#$e9b6c7aa,0<<2
    moveq   #20,d1
    rol.l   d1,d5
    add.l   d6,d5      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepGa2 d4,d5,d6,d7,d3,#$d62f105d,5<<2
    rol.l   #5,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa2 d7,d3,d5,d6,d4,#$02441453,10<<2
    moveq   #9,d1
    rol.l   d1,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa2 d6,d4,d3,d5,d7,#$d8a1e681,15<<2
    moveq   #14,d1
    rol.l   d1,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepGa2 d5,d7,d4,d3,d6,#$e7d3fbc8,4<<2
    moveq   #20,d1
    rol.l   d1,d6
    add.l   d7,d6      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepGa2 d3,d6,d7,d4,d5,#$21e1cde6,9<<2
    rol.l   #5,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepGa2 d4,d5,d6,d7,d3,#$c33707d6,14<<2
    moveq   #9,d1
    rol.l   d1,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa2 d7,d3,d5,d6,d4,#$f4d50d87,3<<2
    moveq   #14,d1
    rol.l   d1,d4
    add.l   d3,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepGa2 d6,d4,d3,d5,d7,#$455a14ed,8<<2
    moveq   #20,d1
    rol.l   d1,d7
    add.l   d4,d7      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepGa2 d5,d7,d4,d3,d6,#$a9e3e905,13<<2
    rol.l   #5,d6
    add.l   d7,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepGa2 d3,d6,d7,d4,d5,#$fcefa3f8,2<<2
    moveq   #9,d1
    rol.l   d1,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d3 => out
    stepGa2 d4,d5,d6,d7,d3,#$676f02d9,7<<2
    moveq   #14,d1
    rol.l   d1,d3
    add.l   d5,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepGa2 d7,d3,d5,d6,d4,#$8d2a4c8a,12<<2
    moveq   #20,d1
    rol.l   d1,d4
    add.l   d3,d4      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    ; --------------------------------
    
    stepHa2 d6,d4,d3,d5,d7,d2,#$fffa3942,5<<2
    rol.l   #4,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d5,d7,d4,d3,d2,#$8771f681,8<<2
		;     @rename temp out
    moveq   #11,d1
    rol.l   d1,d2
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d6 => out
		; live reg d5 => temp
    stepHa2 d3,d2,d7,d4,d6,d5,#$6d9d6122,11<<2
    ;moveq   #16,@shift
    ;rol.l   @shift,@out
    swap    d6
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d4,d6,d2,d7,d5,#$fde5380c,14<<2
		;     @rename temp out
    moveq   #23,d1
    rol.l   d1,d5
    add.l   d6,d5      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d4 => out
		; live reg d3 => temp
    stepHa2 d7,d5,d6,d2,d4,d3,#$a4beea44,1<<2
    rol.l   #4,d4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d2,d4,d5,d6,d3,#$4bdecfa9,4<<2
		;     @rename temp out
    moveq   #11,d1
    rol.l   d1,d3
    add.l   d4,d3      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d7 => out
		; live reg d2 => temp
    stepHa2 d6,d3,d4,d5,d7,d2,#$f6bb4b60,7<<2
    ;moveq   #16,@shift
    ;rol.l   @shift,@out
    swap    d7
    add.l   d3,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d5,d7,d3,d4,d2,#$bebfbc70,10<<2
		;     @rename temp out
    moveq   #23,d1
    rol.l   d1,d2
    add.l   d7,d2      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d6 => out
		; live reg d5 => temp
    stepHa2 d4,d2,d7,d3,d6,d5,#$289b7ec6,13<<2
    rol.l   #4,d6
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d3,d6,d2,d7,d5,#$eaa127fa,0<<2
		;     @rename temp out
    moveq   #11,d1
    rol.l   d1,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d4 => out
		; live reg d3 => temp
    stepHa2 d7,d5,d6,d2,d4,d3,#$d4ef3085,3<<2
    ;moveq   #16,@shift
    ;rol.l   @shift,@out
    swap    d4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d2,d4,d5,d6,d3,#$04881d05,6<<2
		;     @rename temp out
    moveq   #23,d1
    rol.l   d1,d3
    add.l   d4,d3      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d7 => out
		; live reg d2 => temp
    stepHa2 d6,d3,d4,d5,d7,d2,#$d9d4d039,9<<2
    rol.l   #4,d7
    add.l   d3,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d5,d7,d3,d4,d2,#$e6db99e5,12<<2
		;     @rename temp out
    moveq   #11,d1
    rol.l   d1,d2
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d6 => out
		; live reg d5 => temp
    stepHa2 d4,d2,d7,d3,d6,d5,#$1fa27cf8,15<<2
    ;moveq   #16,@shift
    ;rol.l   @shift,@out
    swap    d6
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
    stepHb2 d3,d6,d2,d7,d5,#$c4ac5665,2<<2
		;     @rename temp out
    moveq   #23,d1
    rol.l   d1,d5
    add.l   d6,d5      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out,temp
		; live reg d4 => out
		; live reg d3 => temp
    ; ---------------------------------
    stepIa2 d7,d5,d6,d2,d4,#$f4292244,0<<2
    rol.l   #6,d4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa2 d2,d4,d5,d6,d7,#$432aff97,7<<2
    moveq   #10,d1
    rol.l   d1,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d2 => out
    stepIa2 d6,d7,d4,d5,d2,#$ab9423a7,14<<2
    rol.l   d0,d2
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepIa2 d5,d2,d7,d4,d6,#$fc93a039,5<<2
    moveq   #21,d1
    rol.l   d1,d6
    add.l   d2,d6      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepIa2 d4,d6,d2,d7,d5,#$655b59c3,12<<2
    rol.l   #6,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa2 d7,d5,d6,d2,d4,#$8f0ccc92,3<<2
    moveq   #10,d1
    rol.l   d1,d4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa2 d2,d4,d5,d6,d7,#$ffeff47d,10<<2
    rol.l   d0,d7
    add.l   d4,d7      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d2 => out
    stepIa2 d6,d7,d4,d5,d2,#$85845dd1,1<<2
    moveq   #21,d1
    rol.l   d1,d2
    add.l   d7,d2      * rotate: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepIa2 d5,d2,d7,d4,d6,#$6fa87e4f,8<<2
    rol.l   #6,d6
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepIa2 d4,d6,d2,d7,d5,#$fe2ce6e0,15<<2
    moveq   #10,d1
    rol.l   d1,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa2 d7,d5,d6,d2,d4,#$a3014314,6<<2
    rol.l   d0,d4
    add.l   d5,d4      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    stepIa2 d2,d4,d5,d6,d7,#$4e0811a1,13<<2
    moveq   #21,d1
    rol.l   d1,d7
    add.l   d4,d7      * d0: b = new sum
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d2 => out
    stepIa2 d6,d7,d4,d5,d2,#$f7537e82,4<<2
    rol.l   #6,d2
    add.l   d7,d2      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d6 => out
    stepIa2 d5,d2,d7,d4,d6,#$bd3af235,11<<2
    moveq   #10,d1
    rol.l   d1,d6
    add.l   d2,d6      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d5 => out
    stepIa2 d4,d6,d2,d7,d5,#$2ad7d2bb,2<<2
    rol.l   d0,d5
    add.l   d6,d5      * tmp += b
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d4 => out
    stepIa2 d7,d5,d6,d2,d4,#$eb86d391,9<<2
    moveq   #21,d1
    rol.l   d1,d4
    add.l   d5,d4
		;     @kill   a
		;     @rename d a
		;     @rename c d
		;     @rename b c
		;     @rename out b
		;     @dreg   out
		; live reg d7 => out
    ; ---------------------------------
    add.l   d2,ctx_a(a0)
    add.l   d4,ctx_b(a0)
    add.l   d5,ctx_c(a0)
    add.l   d6,ctx_d(a0)
    ; ---------------------------------
    cmp.l   a3,a1      * check if end of last block
    bne     .loop
    rts
		;     @kill a,b,c,d,out,temp,shift

* 64 steps
steps:
stepsF:
         dc.l $d76aa478
         dc.l $e8c7b756
         dc.l $242070db
         dc.l $c1bdceee
         dc.l $f57c0faf
         dc.l $4787c62a
         dc.l $a8304613
         dc.l $fd469501
         dc.l $698098d8
         dc.l $8b44f7af
         dc.l $ffff5bb1
         dc.l $895cd7be
         dc.l $6b901122
         dc.l $fd987193
         dc.l $a679438e
         dc.l $49b40821
stepsG:         
         dc.l $f61e2562 
         dc.l $c040b340 
         dc.l $265e5a51 
         dc.l $e9b6c7aa 
         dc.l $d62f105d 
         dc.l $02441453 
         dc.l $d8a1e681 
         dc.l $e7d3fbc8 
         dc.l $21e1cde6 
         dc.l $c33707d6 
         dc.l $f4d50d87 
         dc.l $455a14ed 
         dc.l $a9e3e905 
         dc.l $fcefa3f8 
         dc.l $676f02d9 
         dc.l $8d2a4c8a 
stepsH:         
         dc.l $fffa3942 
         dc.l $8771f681 
         dc.l $6d9d6122 
         dc.l $fde5380c 
         dc.l $a4beea44 
         dc.l $4bdecfa9 
         dc.l $f6bb4b60 
         dc.l $bebfbc70 
         dc.l $289b7ec6 
         dc.l $eaa127fa 
         dc.l $d4ef3085 
         dc.l $04881d05 
         dc.l $d9d4d039 
         dc.l $e6db99e5 
         dc.l $1fa27cf8 
         dc.l $c4ac5665 
stepsI:         
         dc.l $f4292244 
         dc.l $432aff97 
         dc.l $ab9423a7 
         dc.l $fc93a039 
         dc.l $655b59c3 
         dc.l $8f0ccc92 
         dc.l $ffeff47d 
         dc.l $85845dd1 
         dc.l $6fa87e4f 
         dc.l $fe2ce6e0 
         dc.l $a3014314 
         dc.l $4e0811a1 
         dc.l $f7537e82 
         dc.l $bd3af235 
         dc.l $2ad7d2bb 
         dc.l $eb86d391 

stepBlockOffsetsGHI:
         dc.b 1<<2
         dc.b 6<<2
         dc.b 11<<2
         dc.b 0<<2
         dc.b 5<<2
         dc.b 10<<2
         dc.b 15<<2
         dc.b 4<<2
         dc.b 9<<2
         dc.b 14<<2
         dc.b 3<<2
         dc.b 8<<2
         dc.b 13<<2
         dc.b 2<<2
         dc.b 7<<2
         dc.b 12<<2
         dc.b 5<<2
         dc.b 8<<2
         dc.b 11<<2
         dc.b 14<<2
         dc.b 1<<2
         dc.b 4<<2
         dc.b 7<<2
         dc.b 10<<2
         dc.b 13<<2
         dc.b 0<<2
         dc.b 3<<2
         dc.b 6<<2
         dc.b 9<<2
         dc.b 12<<2
         dc.b 15<<2
         dc.b 2<<2
         dc.b 0<<2
         dc.b 7<<2
         dc.b 14<<2
         dc.b 5<<2
         dc.b 12<<2
         dc.b 3<<2
         dc.b 10<<2
         dc.b 1<<2
         dc.b 8<<2
         dc.b 15<<2
         dc.b 6<<2
         dc.b 13<<2
         dc.b 4<<2
         dc.b 11<<2
         dc.b 2<<2
         dc.b 9<<2

