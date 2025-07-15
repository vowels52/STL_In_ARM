		AREA	|.text|, CODE, READONLY
		ALIGN
			
		EXPORT 	_bzero
_bzero
		;	R0 = *s
		;	R1 = n
		MOV		r2, #0
loop
		CMP		r1, #0
		BEQ		bzero_done
		STRB	r2, [r0], #1
		SUB		r1, r1, #1
		B		loop
bzero_done	
		BX		lr
		
		EXPORT 	_strncpy
_strncpy
		;	R0 = *dst
		;	R1 = *src
		;	R2 = len
		MOV		r4, r0
copy	
		CMP		r2, #0
		BEQ		copy_done
		
		LDRB	r3, [r1], #1
		STRB	r3,	[r0], #1
		SUB		r2, r2, #1
		
		CMP		r3, #0
		BNE		copy
copy_done
		MOV		r0, r4
		BX		lr
		
        EXPORT  _malloc
_malloc
        MOV     r7, #4
        SVC     #0
        BX      lr

        EXPORT  _free
_free
        MOV     r7, #5
        SVC     #0
        BX      lr

        EXPORT  _signal
_signal
        MOV     r7, #2
        SVC     #0
        BX      lr

        EXPORT  _alarm
_alarm
        MOV     r7, #1
        SVC     #0
        BX      lr
		
		END