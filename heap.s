			AREA	|.text|, CODE, READONLY, ALIGN=2
			THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
HEAP_TOP	EQU		0x20001000
HEAP_BOT	EQU		0x20004FE0
MAX_SIZE	EQU		0x00004000		; 16KB = 2^14
MIN_SIZE	EQU		0x00000020		; 32B  = 2^5
	
MCB_TOP		EQU		0x20006800      	; 2^10B = 1K Space
MCB_BOT		EQU		0x20006BFE
MCB_ENT_SZ	EQU		0x00000002		; 2B per entry
MCB_TOTAL	EQU		512			; 2^9 = 512 entries
	
INVALID		EQU		-1			; an invalid id
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Memory Control Block Initialization
		EXPORT	_heap_init
_heap_init
	;; Implement by yourself
		LDR		r0, =MCB_TOP
		LDR		r1, =MCB_BOT
		MOV		r2, #0
		
_kinit
		CMP		r0, r1
		BEQ		_kinit_done
		
		STRB	r2, [r1], #-1
		B		_kinit	

_kinit_done
		LDR		r0, =MCB_TOP
		MOV		r1, #MAX_SIZE
		STR		r1, [r0]
		BX		lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc( int size )
		EXPORT  _kalloc
_kalloc
        PUSH    {lr}

_ralloc_prep
        LDR     r1, =MCB_TOP     ; left = mcb_top
        LDR     r2, =MCB_BOT     ; right = mcb_bot
		MOV     r4, r0           ; Save 'size' in r4
        BL      _ralloc
        POP     {pc}

_ralloc	; _ralloc(size, left, right)
        PUSH    {r1-r11, lr}

        MOV     r5, r1           ; r5 = entry
		
        SUB     r6, r2, r1       
        ADD     r6, r6, #2		; r6 = mcb_size

        MOV     r7, r6
        LSL     r7, r7, #4       ; r7 = mcb_bytes

        MOV     r8, r7
        LSR     r8, r8, #1       ; r8 = mcb_bytes / 2
		
		CMP		r7, #MIN_SIZE
		BEQ		_base_case	; current slot is min_size

        CMP     r8, r4           
        BGE     _ralloc_recurse	; mcb_bytes/2 >= size

_base_case
        LDR    r9, [r5]         ; r9 = *entry
        ANDS    r10, r9, #1      ; in_use = *entry & 1
        BNE     _ralloc_fail

        CMP     r9, r7           ; *entry < mcb_bytes
        BLT     _ralloc_fail

        LDR     r11, =MCB_TOP
        SUB     r10, r1, r11
        LSL     r10, r10, #4     ; r10 = offset = (left - mcb_top) * 16

        ORR     r9, r7, #1
        STR    r9, [r5]			; r5 = *entry = in_use

        LDR		r11, =HEAP_TOP
        ADD     r0, r11, r10	; r0 = addr = heap_top + offset
        B       _ralloc_done

_ralloc_fail
        MOVS    r0, #0			; return null
        B       _ralloc_done

_ralloc_recurse
        MOV     r9, r6
        LSR     r9, r9, #1
        ADD     r9, r9, r1       ; r9 = mid = left + (mcb_size / 2)
		
		PUSH	{r1-r2}
        SUB     r2, r9, #2      ; r2 = mid - 2
        MOV     r0, r4           ; restore original size
        BL      _ralloc			; _ralloc(size, left, mid - 2)
		POP		{r1-r2}
        CMP     r0, #0
        BEQ     _ralloc_right	; _ralloc(size, mid, right)

        LDR    	r6, [r9]         ; r6 = *mid_entry
        ANDS    r6, r6, #1
        BNE     _ralloc_done

        MOV     r7, r7           ; r7 = mcb_bytes
        LSR     r7, r7, #1
        STR    	r7, [r9]		 ; r9 = *mid_entry = mcb_bytes / 2
        B       _ralloc_done

_ralloc_right	; _ralloc(size, mid, right)
        MOV     r1, r9           ; left = mid
        MOV     r0, r4           ; restore original size
        BL      _ralloc

_ralloc_done
        POP     {r1-r11, pc}
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void free( void *ptr )
		EXPORT	_kfree
_kfree
        PUSH    {lr}
        MOV     r4, r0           ; r4 = ptr to free

        LDR     r1, =HEAP_TOP
        CMP     r4, r1
        BLT     _kfree_fail; ptr >= heap_top
        LDR     r1, =HEAP_BOT
        CMP     r4, r1
        BGT     _kfree_fail; ptr <= heap_bot

        LDR     r1, =HEAP_TOP
        SUB     r5, r4, r1
        LSR     r5, r5, #4
        LDR     r1, =MCB_TOP
        ADD     r0, r1, r5      ; r0 = mcb_addr = mcb_top + ((ptr - heap_top) / 16)

        BL      _rfree

        CMP     r0, #0
        BEQ     _kfree_fail; check if addr is valid
        MOV     r0, r4             
        B       _kfree_done; return ptr

_kfree_fail
        MOVS    r0, #0          ; return NULL

_kfree_done
        POP     {pc}

_rfree
        PUSH    {r4-r11, lr}
        MOV     r4, r0           ; r4 = mcb_addr

        LDRH     r5, [r4]       ; r5 = *mcb_entry
        ANDS    r6, r5, #1 ; If size 0, return 0
        BIC     r7, r5, #1       ; r7 = size
        STRH     r7, [r4]         ; in_use = 0

        ; Compute buddy address
        MOV     r8, r7           
		LSR		r8, r8, #4 ; r8 = mcb_disp = block_size / 16
        LDR     r9, =MCB_TOP
        SUB     r10, r4, r9      ; r10 = mcb_index
        UDIV    r11, r10, r8     ; r11 = buddy_index = mcb_index / mcb_disp
        ANDS    r11, r11, #1
        CMP     r11, #0 ; if r11 == 0, this is left buddy, else right buddy
        BNE     _rfree_right

_rfree_left
        ADD     r12, r4, r8      ; r12 = buddy_addr = this + block size
        LDRH     r5, [r12]        ; r5 = buddy_val
        ANDS    r6, r5, #1 
        BNE     _rfree_return ; if buddy is in use, return
        BIC     r5, r5, #1
        CMP     r5, r7
        BNE     _rfree_return ; if buddy is wrong size, return

        MOVS    r5, #0
        STRH     r5, [r12]        ; clear buddy size
        LSL     r7, r7, #1       ; double size
        STR     r7, [r4]         ; update my block to combined size
        BL      _rfree
        B       _rfree_return

_rfree_right
        SUB     r12, r4, r8      ; r12 = buddy_addr = this - block size
        LDRH     r5, [r12]        ; r5 = buddy_val
        ANDS    r6, r5, #1
        BNE     _rfree_return ; if buddy is in use, return
        BIC     r5, r5, #1
        CMP     r5, r7
        BNE     _rfree_return ; if buddy is wrong size, return

        MOVS    r5, #0
        STRH     r5, [r4]         ; clear self
        LSL     r7, r7, #1       ; double size
        STR     r7, [r12]        ; update buddy to combined size
        MOV     r0, r12
        BL      _rfree
        B       _rfree_return

_rfree_return
        MOV     r0, r4 ; return original addr
        POP     {r4-r11, lr}
		BX		lr

		END