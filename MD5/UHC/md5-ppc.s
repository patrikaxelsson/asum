# Fast implementation of MD5 in PowerPC assembler. Based on the portable
# solar MD5 implementation from:
# https://openwall.info/wiki/people/solar/software/public-domain-source-code/md5

	.set	ctx_a,0
	.set	ctx_b,4
	.set	ctx_c,8
	.set	ctx_d,12
	.set	ctx_buffer,80
	.set	ctx_lo,144
	.set	ctx_hi,148

	.ifdef	__ELF__
	.set	_memcpy,memcpy
	.set	_memset,memset
	.endif

	.text
	.align	2
# In: r3 struct MD5Ctx *ctx
# In: r4 const void *data
# In: r5 size_t size
_body:
	.set	s_ctx,136
	.set	s_size,144
	stwu	r1,-112(r1)
	stmw	r13,24(r1)
	stw	r3,s_ctx(r1)
	stw	r5,s_size(r1)
	mr	r13,r4          # data
	lwz	r14,ctx_a(r3)
	lwz	r16,ctx_b(r3)
	lwz	r17,ctx_c(r3)
	lwz	r15,ctx_d(r3)
.loop:
	mr	r7,r14          # saved_a
	mr	r8,r16          # saved_b
	mr	r9,r17          # saved_c
	mr	r10,r15         # saved_d
	# STEP F0
	xor	r6,r15,r17
	li	r20,0           # 0 in SET(0)
	and	r6,r6,r16
	lwbrx	r20,r20,r13     # x0 = SET(0)
	xor	r6,r6,r15
	add	r6,r6,r20
	lis	r12,-10389
	addi	r12,r12,-23432
	add	r6,r6,r12
	add	r14,r6,r14
	rotlwi	r14,r14,7
	add	r14,r16,r14
	# STEP F1
	xor	r6,r17,r16
	li	r27,4           # 1 in SET(1)
	and	r6,r6,r14
	lwbrx	r27,r27,r13     # x1 = SET(1)
	xor	r6,r6,r17
	add	r6,r6,r27
	lis	r12,-5944
	addi	r12,r12,-18602
	add	r6,r6,r12
	add	r15,r6,r15
	rotlwi	r15,r15,12
	add	r15,r15,r14
	# STEP F2
	xor	r6,r16,r14
	li	r5,8            # 2 in SET(2)
	and	r6,r6,r15
	lwbrx	r5,r5,r13       # x2 = SET(2)
	xor	r6,r6,r16
	add	r6,r6,r5
	lis	r12,9248
	addi	r12,r12,28891
	add	r6,r6,r12
	add	r17,r6,r17
	rotlwi	r17,r17,17
	add	r17,r15,r17
	# STEP F3
	xor	r6,r15,r14
	li	r25,12          # 3 in SET(3)
	and	r6,r6,r17
	lwbrx	r25,r25,r13     # x3 = SET(3)
	xor	r6,r6,r14
	add	r6,r6,r25
	lis	r12,-15938
	addi	r12,r12,-12562
	add	r6,r6,r12
	add	r16,r6,r16
	rotlwi	r16,r16,22
	add	r16,r17,r16
	# STEP F4
	xor	r6,r15,r17
	li	r3,16            # 4 in SET(4)
	and	r6,r6,r16
	lwbrx	r3,r3,r13        # x4 = SET(4)
	xor	r6,r6,r15
	add	r6,r6,r3
	lis	r12,-2692
	addi	r12,r12,4015
	add	r6,r6,r12
	add	r14,r6,r14
	rotlwi	r14,r14,7
	add	r14,r16,r14
	# STEP F5
	xor	r6,r17,r16
	li	r23,20          # 5 in SET(5)
	and	r6,r6,r14
	lwbrx	r23,r23,r13     # x5 = SET(5)
	xor	r6,r6,r17
	add	r6,r6,r23
	lis	r12,18312
	addi	r12,r12,-14806
	add	r6,r6,r12
	add	r15,r6,r15
	rotlwi	r15,r15,12
	add	r15,r15,r14
	# STEP F6
	xor	r6,r16,r14
	li	r30,24          # 6 in SET(6)
	and	r6,r6,r15
	lwbrx	r30,r30,r13     # x6 = SET(6)
	xor	r6,r6,r16
	add	r6,r6,r30
	lis	r12,-22480
	addi	r12,r12,17939
	add	r6,r6,r12
	add	r17,r6,r17
	rotlwi	r17,r17,17
	add	r17,r15,r17
	# STEP F7
	xor	r6,r15,r14
	li	r21,28          # 7 in SET(7)
	and	r6,r6,r17
	lwbrx	r21,r21,r13     # x7 = SET(7)
	xor	r6,r6,r14
	add	r6,r6,r21
	lis	r12,-697
	addi	r12,r12,-27391
	add	r6,r6,r12
	add	r16,r6,r16
	rotlwi	r16,r16,22
	add	r16,r17,r16
	# STEP F8
	xor	r6,r15,r17
	li	r28,32          # 8 in SET(8)
	and	r6,r6,r16
	lwbrx	r28,r28,r13     # x8 = SET(8)
	xor	r6,r6,r15
	add	r6,r6,r28
	lis	r12,27009
	addi	r12,r12,-26408
	add	r6,r6,r12
	add	r14,r6,r14
	rotlwi	r14,r14,7
	add	r14,r16,r14
	# STEP F9
	xor	r4,r17,r16
	li	r6,36           # 9 in SET(9)
	and	r4,r4,r14
	lwbrx	r6,r6,r13       # x9 = SET(9)
	xor	r4,r4,r17
	add	r4,r4,r6
	lis	r12,-29883
	addi	r12,r12,-2129
	add	r4,r4,r12
	add	r15,r4,r15
	rotlwi	r15,r15,12
	add	r15,r15,r14
	# STEP F10
	xor	r4,r16,r14
	li	r26,40          # 10 in SET(10)
	and	r4,r4,r15
	lwbrx	r26,r26,r13     # x10 = SET(10)
	xor	r4,r4,r16
	add	r4,r4,r26
	lis	r12,-1
	addi	r12,r12,23473
	add	r4,r4,r12
	add	r17,r4,r17
	rotlwi	r17,r17,17
	add	r17,r15,r17
	# STEP F11
	xor	r31,r15,r14
	li	r4,44           # 11 in SET(11)
	and	r31,r31,r17
	lwbrx	r4,r4,r13       # x11 = SET(11)
	xor	r31,r31,r14
	add	r31,r31,r4
	lis	r12,-30371
	addi	r12,r12,-10306
	add	r31,r31,r12
	add	r16,r31,r16
	rotlwi	r16,r16,22
	add	r16,r17,r16
	# STEP F12
	xor	r31,r15,r17
	li	r24,48          # 12 in SET(12)
	and	r31,r31,r16
	lwbrx	r24,r24,r13     # x12 = SET(12)
	xor	r31,r31,r15
	add	r31,r31,r24
	lis	r12,27536
	addi	r12,r12,4386
	add	r31,r31,r12
	add	r14,r31,r14
	rotlwi	r14,r14,7
	add	r14,r16,r14
	# STEP F13
	xor	r29,r17,r16
	li	r31,52          # 13 in SET(13)
	and	r29,r29,r14
	lwbrx	r31,r31,r13     # x13 = SET(13)
	xor	r29,r29,r17
	add	r29,r29,r31
	lis	r12,-616
	addi	r12,r12,29075
	add	r29,r29,r12
	add	r15,r29,r15
	rotlwi	r15,r15,12
	add	r15,r15,r14
	# STEP F14
	xor	r29,r16,r14
	li	r22,56          # 14 in SET(14)
	and	r29,r29,r15
	lwbrx	r22,r22,r13     # x14 = SET(14)
	xor	r29,r29,r16
	add	r29,r29,r22
	lis	r12,-22919
	addi	r12,r12,17294
	add	r29,r29,r12
	add	r17,r29,r17
	rotlwi	r17,r17,17
	add	r17,r15,r17
	# STEP F15
	xor	r19,r15,r14
	li	r29,60          # 15 in SET(15)
	and	r19,r19,r17
	lwbrx	r29,r29,r13     # x15 = SET(15)
	xor	r19,r19,r14
	add	r19,r19,r29
	lis	r12,18868
	addi	r12,r12,2081
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,22
	add	r16,r17,r16
	xor	r19,r17,r16
	and	r19,r19,r15
	xor	r19,r19,r17
	add	r19,r19,r27
	lis	r12,-2530
	addi	r12,r12,9570
	add	r19,r19,r12
	add	r14,r19,r14
	rotlwi	r14,r14,5
	add	r14,r16,r14
	xor	r19,r16,r14
	and	r19,r19,r17
	xor	r19,r19,r16
	add	r19,r19,r30
	lis	r12,-16319
	addi	r12,r12,-19648
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,9
	add	r15,r15,r14
	xor	r19,r15,r14
	and	r19,r19,r16
	xor	r19,r19,r14
	add	r19,r19,r4
	lis	r12,9822
	addi	r12,r12,23121
	add	r19,r19,r12
	add	r17,r19,r17
	rotlwi	r17,r17,14
	add	r17,r15,r17
	xor	r19,r15,r17
	and	r19,r19,r14
	xor	r19,r19,r15
	add	r19,r19,r20
	lis	r12,-5705
	addi	r12,r12,-14422
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,20
	add	r16,r17,r16
	xor	r19,r17,r16
	and	r19,r19,r15
	xor	r19,r19,r17
	add	r19,r19,r23
	lis	r12,-10705
	addi	r12,r12,4189
	add	r19,r19,r12
	add	r14,r19,r14
	rotlwi	r14,r14,5
	add	r14,r16,r14
	xor	r19,r16,r14
	and	r19,r19,r17
	xor	r19,r19,r16
	add	r19,r19,r26
	lis	r12,580
	addi	r12,r12,5203
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,9
	add	r15,r15,r14
	xor	r19,r15,r14
	and	r19,r19,r16
	xor	r19,r19,r14
	add	r19,r19,r29
	lis	r12,-10078
	addi	r12,r12,-6527
	add	r19,r19,r12
	add	r17,r19,r17
	rotlwi	r17,r17,14
	add	r17,r15,r17
	xor	r19,r15,r17
	and	r19,r19,r14
	xor	r19,r19,r15
	add	r19,r19,r3
	lis	r12,-6188
	addi	r12,r12,-1080
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,20
	add	r16,r17,r16
	xor	r19,r17,r16
	and	r19,r19,r15
	xor	r19,r19,r17
	add	r19,r19,r6
	lis	r12,8674
	addi	r12,r12,-12826
	add	r19,r19,r12
	add	r14,r19,r14
	rotlwi	r14,r14,5
	add	r14,r16,r14
	xor	r19,r16,r14
	and	r19,r19,r17
	xor	r19,r19,r16
	add	r19,r19,r22
	lis	r12,-15561
	addi	r12,r12,2006
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,9
	add	r15,r15,r14
	xor	r19,r15,r14
	and	r19,r19,r16
	xor	r19,r19,r14
	add	r19,r19,r25
	lis	r12,-2859
	addi	r12,r12,3463
	add	r19,r19,r12
	add	r17,r19,r17
	rotlwi	r17,r17,14
	add	r17,r15,r17
	xor	r19,r15,r17
	and	r19,r19,r14
	xor	r19,r19,r15
	add	r19,r19,r28
	lis	r12,17754
	addi	r12,r12,5357
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,20
	add	r16,r17,r16
	xor	r19,r17,r16
	and	r19,r19,r15
	xor	r19,r19,r17
	add	r19,r19,r31
	lis	r12,-22044
	addi	r12,r12,-5883
	add	r19,r19,r12
	add	r14,r19,r14
	rotlwi	r14,r14,5
	add	r14,r16,r14
	xor	r19,r16,r14
	and	r19,r19,r17
	xor	r19,r19,r16
	add	r19,r19,r5
	lis	r12,-784
	addi	r12,r12,-23560
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,9
	add	r15,r15,r14
	xor	r19,r15,r14
	and	r19,r19,r16
	xor	r19,r19,r14
	add	r19,r19,r21
	lis	r12,26479
	addi	r12,r12,729
	add	r19,r19,r12
	add	r17,r19,r17
	rotlwi	r17,r17,14
	add	r17,r15,r17
	xor	r19,r15,r17
	and	r19,r19,r14
	xor	r19,r19,r15
	add	r19,r19,r24
	lis	r12,-29398
	addi	r12,r12,19594
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,20
	add	r16,r17,r16
	xor	r19,r17,r16
	xor	r18,r19,r15
	add	r18,r18,r23
	lis	r12,-6
	addi	r12,r12,14658
	add	r18,r18,r12
	add	r14,r18,r14
	rotlwi	r14,r14,4
	add	r14,r16,r14
	xor	r19,r19,r14
	add	r19,r19,r28
	lis	r12,-30862
	addi	r12,r12,-2431
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,11
	add	r15,r15,r14
	xor	r19,r15,r14
	xor	r18,r19,r16
	add	r18,r18,r4
	lis	r12,28061
	addi	r12,r12,24866
	add	r18,r18,r12
	add	r17,r18,r17
	rotlwi	r17,r17,16
	add	r17,r15,r17
	xor	r19,r19,r17
	add	r19,r19,r22
	lis	r12,-539
	addi	r12,r12,14348
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,23
	add	r16,r17,r16
	xor	r19,r17,r16
	xor	r18,r19,r15
	add	r18,r18,r27
	lis	r12,-23361
	addi	r12,r12,-5564
	add	r18,r18,r12
	add	r14,r18,r14
	rotlwi	r14,r14,4
	add	r14,r16,r14
	xor	r19,r19,r14
	add	r19,r19,r3
	lis	r12,19423
	addi	r12,r12,-12375
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,11
	add	r15,r15,r14
	xor	r19,r15,r14
	xor	r18,r19,r16
	add	r18,r18,r21
	lis	r12,-2373
	addi	r12,r12,19296
	add	r18,r18,r12
	add	r17,r18,r17
	rotlwi	r17,r17,16
	add	r17,r15,r17
	xor	r19,r19,r17
	add	r19,r19,r26
	lis	r12,-16704
	addi	r12,r12,-17296
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,23
	add	r16,r17,r16
	xor	r19,r17,r16
	xor	r18,r19,r15
	add	r18,r18,r31
	lis	r12,10395
	addi	r12,r12,32454
	add	r18,r18,r12
	add	r14,r18,r14
	rotlwi	r14,r14,4
	add	r14,r16,r14
	xor	r19,r19,r14
	add	r19,r19,r20
	lis	r12,-5471
	addi	r12,r12,10234
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,11
	add	r15,r15,r14
	xor	r19,r15,r14
	xor	r18,r19,r16
	add	r18,r18,r25
	lis	r12,-11025
	addi	r12,r12,12421
	add	r18,r18,r12
	add	r17,r18,r17
	rotlwi	r17,r17,16
	add	r17,r15,r17
	xor	r19,r19,r17
	add	r19,r19,r30
	lis	r12,1160
	addi	r12,r12,7429
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,23
	add	r16,r17,r16
	xor	r19,r17,r16
	xor	r18,r19,r15
	add	r18,r18,r6
	lis	r12,-9771
	addi	r12,r12,-12231
	add	r18,r18,r12
	add	r14,r18,r14
	rotlwi	r14,r14,4
	add	r14,r16,r14
	xor	r19,r19,r14
	add	r19,r19,r24
	lis	r12,-6436
	addi	r12,r12,-26139
	add	r19,r19,r12
	add	r15,r19,r15
	rotlwi	r15,r15,11
	add	r15,r15,r14
	xor	r19,r15,r14
	xor	r18,r19,r16
	add	r18,r18,r29
	lis	r12,8098
	addi	r12,r12,31992
	add	r18,r18,r12
	add	r17,r18,r17
	rotlwi	r17,r17,16
	add	r17,r15,r17
	xor	r19,r19,r17
	add	r19,r19,r5
	lis	r12,-15188
	addi	r12,r12,22117
	add	r19,r19,r12
	add	r16,r19,r16
	rotlwi	r16,r16,23
	add	r16,r17,r16
	nor	r19,r15,r15
	or	r19,r19,r16
	xor	r19,r19,r17
	add	r20,r19,r20
	lis	r12,-3031
	addi	r12,r12,8772
	add	r20,r20,r12
	add	r14,r20,r14
	rotlwi	r14,r14,6
	add	r14,r16,r14
	nor	r20,r17,r17
	or	r20,r20,r14
	xor	r20,r20,r16
	add	r21,r20,r21
	lis	r12,17195
	addi	r12,r12,-105
	add	r21,r21,r12
	add	r15,r21,r15
	rotlwi	r15,r15,10
	add	r15,r15,r14
	nor	r21,r16,r16
	or	r21,r21,r15
	xor	r21,r21,r14
	add	r22,r21,r22
	lis	r12,-21612
	addi	r12,r12,9127
	add	r22,r22,r12
	add	r17,r22,r17
	rotlwi	r17,r17,15
	add	r17,r15,r17
	nor	r22,r14,r14
	or	r22,r22,r17
	xor	r22,r22,r15
	add	r23,r22,r23
	lis	r12,-876
	addi	r12,r12,-24519
	add	r23,r23,r12
	add	r16,r23,r16
	rotlwi	r16,r16,21
	add	r16,r17,r16
	nor	r23,r15,r15
	or	r23,r23,r16
	xor	r23,r23,r17
	add	r24,r23,r24
	lis	r12,25947
	addi	r12,r12,22979
	add	r24,r24,r12
	add	r14,r24,r14
	rotlwi	r14,r14,6
	add	r14,r16,r14
	nor	r24,r17,r17
	or	r24,r24,r14
	xor	r24,r24,r16
	add	r25,r24,r25
	lis	r12,-28915
	addi	r12,r12,-13166
	add	r25,r25,r12
	add	r15,r25,r15
	rotlwi	r15,r15,10
	add	r15,r15,r14
	nor	r25,r16,r16
	or	r25,r25,r15
	xor	r25,r25,r14
	add	r26,r25,r26
	lis	r12,-16
	addi	r12,r12,-2947
	add	r26,r26,r12
	add	r17,r26,r17
	rotlwi	r17,r17,15
	add	r17,r15,r17
	nor	r26,r14,r14
	or	r26,r26,r17
	xor	r26,r26,r15
	add	r27,r26,r27
	lis	r12,-31356
	addi	r12,r12,24017
	add	r27,r27,r12
	add	r16,r27,r16
	rotlwi	r16,r16,21
	add	r16,r17,r16
	nor	r27,r15,r15
	or	r27,r27,r16
	xor	r27,r27,r17
	add	r28,r27,r28
	lis	r12,28584
	addi	r12,r12,32335
	add	r28,r28,r12
	add	r14,r28,r14
	rotlwi	r14,r14,6
	add	r14,r16,r14
	nor	r28,r17,r17
	or	r28,r28,r14
	xor	r28,r28,r16
	add	r29,r28,r29
	lis	r12,-467
	addi	r12,r12,-6432
	add	r29,r29,r12
	add	r15,r29,r15
	rotlwi	r15,r15,10
	add	r15,r15,r14
	nor	r29,r16,r16
	or	r29,r29,r15
	xor	r29,r29,r14
	add	r30,r29,r30
	lis	r12,-23807
	addi	r12,r12,17172
	add	r30,r30,r12
	add	r17,r30,r17
	rotlwi	r17,r17,15
	add	r17,r15,r17
	nor	r30,r14,r14
	or	r30,r30,r17
	xor	r30,r30,r15
	add	r31,r30,r31
	lis	r12,19976
	addi	r12,r12,4513
	add	r31,r31,r12
	add	r16,r31,r16
	rotlwi	r16,r16,21
	add	r16,r17,r16
	nor	r31,r15,r15
	or	r31,r31,r16
	xor	r31,r31,r17
	add	r3,r31,r3
	lis	r12,-2221
	addi	r12,r12,32386
	add	r3,r3,r12
	add	r14,r3,r14
	rotlwi	r14,r14,6
	add	r14,r16,r14
	nor	r3,r17,r17
	or	r3,r3,r14
	xor	r3,r3,r16
	add	r4,r3,r4
	lis	r12,-17093
	addi	r12,r12,-3531
	add	r4,r4,r12
	add	r15,r4,r15
	rotlwi	r15,r15,10
	add	r15,r15,r14
	nor	r4,r16,r16
	or	r4,r4,r15
	xor	r4,r4,r14
	add	r5,r4,r5
	lis	r12,10968
	addi	r12,r12,-11589
	add	r5,r5,r12
	add	r17,r5,r17
	rotlwi	r17,r17,15
	add	r17,r15,r17
	nor	r5,r14,r14
	or	r5,r5,r17
	xor	r5,r5,r15
	add	r6,r5,r6
	lis	r12,-5241
	addi	r12,r12,-11375
	add	r6,r6,r12
	add	r16,r6,r16
	rotlwi	r16,r16,21
	add	r16,r17,r16
	add	r14,r7,r14
	add	r16,r8,r16
	add	r17,r9,r17
	add	r15,r10,r15
	addi	r13,r13,64
	lwz	r11,s_size(r1)
	addic.	r0,r11,-64
	stw	r0,s_size(r1)
	lwz	r11,s_size(r1)
	bne	cr0,.loop
	lwz	r10,s_ctx(r1)
	stw	r14,ctx_a(r10)
	stw	r16,ctx_b(r10)
	stw	r17,ctx_c(r10)
	stw	r15,ctx_d(r10)
	mr	r3,r13
	lmw	r13,24(r1)
	addi	r1,r1,112
	blr
	.type	_body,@function
	.size	_body,$-_body
	.set	___stack_body,112

	.ifndef	__ONLY_MD5_UPDATE__
	.text
	.align	2
	.global	_MD5_Init
	.global	MD5_Init
# In: r3 struct MD5Ctx *ctx
_MD5_Init:
MD5_Init:
	lis	r9,26437
	lis	r8,4146
	addi	r9,r9,8961
	addi	r8,r8,21622
	lis	r7,-4146
	lis	r6,-26437
	stw	r9,ctx_a(r3)
	addi	r7,r7,-21623
	addi	r6,r6,-8962
	li	r5,0
	stw	r7,ctx_b(r3)
	stw	r6,ctx_c(r3)
	stw	r8,ctx_d(r3)
	stw	r5,ctx_hi(r3)
	stw	r5,ctx_lo(r3)
	blr
	.type	_MD5_Init,@function
	.size	_MD5_Init,$-_MD5_Init
	.set	___stack_MD5_Init,0
	.endif

	.text
	.align	2
	.global	_MD5_Update
	.global	MD5_Update
# In: r3 struct MD5Ctx *ctx
# In: r4 const void *data
# In: r5 size_t size
_MD5_Update:
MD5_Update:
	lis	r12,8192
	mflr	r11
	stwu	r1,-64(r1)
	addi	r12,r12,-1
	stmw	r26,36(r1)
	mr	r29,r3         # ctx
	mr	r28,r4         # data
	stw	r11,72(r1)
	mr	r30,r5         # buffer
	addi	r10,r29,ctx_lo
	lwz	r6,0(r10)
	mr	r9,r6
	add	r9,r30,r9
	and	r9,r9,r12
	stw	r9,0(r10)
	lwz	r11,0(r10)
	cmplw	cr0,r11,r6
	bge	cr0,.noCarry
	addi	r10,r29,ctx_hi
	lwz	r11,0(r10)
	addi	r0,r11,1
	stw	r0,0(r10)
.noCarry:
	addi	r10,r29,ctx_hi
	srwi	r9,r30,29
	andi.	r7,r6,63
	lwz	r8,0(r10)
	add	r9,r8,r9
	stw	r9,0(r10)
	beq	cr0,.noBufferUsed
	subfic	r26,r7,64
	mr	r27,r26
	cmplw	cr0,r30,r27
	bge	cr0,.moreDataThanBufferAvail
	addi	r3,r29,ctx_buffer
	mr	r4,r28
	add	r3,r3,r7
	mr	r5,r30
	bl	_memcpy    # Copy all data to buffer for next call
	b	.end
.moreDataThanBufferAvail:
	addi	r31,r29,ctx_buffer
	mr	r4,r28
	add	r3,r31,r7
	mr	r5,r27
	bl	_memcpy    # Copy data to fill up buffer
	add	r28,r28,r26
	sub	r30,r30,r27
	mr	r3,r29
	mr	r4,r31
	li	r5,64
	bl	_body      # Consume entire 64B of ctx_buffer
.noBufferUsed:
	cmplwi	cr0,r30,64
	blt	cr0,.remainingSizeLessThan64
	li	r12,-64
	mr	r3,r29
	and	r5,r30,r12
	mr	r4,r28
	bl	_body      # Consume data in even 64B blocks
	mr	r28,r3
	andi.	r30,r30,63
.remainingSizeLessThan64:
	addi	r3,r29,ctx_buffer
	mr	r4,r28
	mr	r5,r30
	bl	_memcpy   # Copy remaining data to buffer for next call
.end:
	lmw	r26,36(r1)
	lwz	r11,72(r1)
	addi	r1,r1,64
	mtlr	r11
	blr
	.type	_MD5_Update,@function
	.size	_MD5_Update,$-_MD5_Update

	.ifndef	__ONLY_MD5_UPDATE__
	.text
	.align	2
	.global	_MD5_Final
	.global	MD5_Final
# In: r3 struct MD5Ctx *ctx
# In: r4 uint8_t *result
_MD5_Final:
MD5_Final:
	mflr	r11
	stwu	r1,-64(r1)
	stmw	r28,36(r1)
	mr	r31,r3             # ctx
	mr	r30,r4             # result
	stw	r11,72(r1)
	addi	r29,r31,ctx_buffer # ctx_buffer
	lwz	r28,ctx_lo(r31)
	andi.	r7,r28,63
	add	r10,r29,r7
	li	r11,128
	addi	r7,r7,1
	stb	r11,0(r10)
	subfic	r6,r7,64
	cmplwi	cr0,r6,8
	bge	cr0,.enoughBufferSpace
	add	r3,r29,r7
	mr	r5,r6
	li	r4,0
	bl	_memset
	mr	r3,r31
	mr	r4,r29
	li	r5,64
	bl	_body
	li	r7,0
	li	r6,64
.enoughBufferSpace:
	add	r3,r29,r7
	addi	r5,r6,-8
	li	r4,0
	bl	_memset
	mr	r3,r31
	mr	r4,r29
	li	r5,64
	li	r8,ctx_buffer+56
	slwi	r9,r28,3          # lo << 3
	# Store lo and ctx->hi at end of buffer, byte-swapped
	stwbrx	r9,r8,r31
	li	r11,ctx_buffer+60
	lwz	r8,ctx_hi(r31)
	stwbrx	r8,r11,r31
	bl	_body
	# Store ctx->a, ctx->b, ctx->c, ctx->d byte-swapped in result
	li	r9,0
	lwz	r11,ctx_a(r31)
	stwbrx	r11,r9,r30
	li	r9,4
	lwz	r11,ctx_b(r31)
	stwbrx	r11,r9,r30
	li	r9,8
	lwz	r11,ctx_c(r31)
	stwbrx	r11,r9,r30
	li	r9,12
	lwz	r11,ctx_d(r31)
	stwbrx	r11,r9,r30
	lmw	r28,36(r1)
	lwz	r11,72(r1)
	addi	r1,r1,64
	mtlr	r11
	blr
	.type	_MD5_Final,@function
	.size	_MD5_Final,$-_MD5_Final

	.global	_memset
	.endif
	.global	_memcpy
