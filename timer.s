			AREA	|.text|, CODE, READONLY, ALIGN=2
			THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Timer Definition
STCTRL		EQU		0xE000E010		; SysTick Control and Status Register
STRELOAD	EQU		0xE000E014		; SysTick Reload Value Register
STCURRENT	EQU		0xE000E018		; SysTick Current Value Register
	
STCTRL_STOP	EQU		0x00000004		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 0, Bit 0 (ENABLE) = 0
STCTRL_GO	EQU		0x00000007		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
STRELOAD_MX	EQU		0x00FFFFFF		; MAX Value = 1/16MHz * 16M = 1 second
STCURR_CLR	EQU		0x00000000		; Clear STCURRENT and STCTRL.COUNT	
SIGALRM		EQU		14				; sig alarm

; System Variables
SECOND_LEFT	EQU		0x20007B80		; Secounds left for alarm( )
USR_HANDLER EQU		0x20007B84		; Address of a user-given signal handler function	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer initialization
; void timer_init( )
			EXPORT		_timer_init
_timer_init
	;; Implement by yourself
		LDR		r3, =STCTRL
		MOV		r4, #STCTRL_STOP
		STR		r4, [r3]
		LDR		r3, =STRELOAD
		MOV		r4, #STRELOAD_MX
		STR		r4, [r3]
		MOV		pc, lr		; return to Reset_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer start
; int timer_start( int seconds )
		EXPORT		_timer_start
_timer_start
	;; Implement by yourself
		CMP		r0, #0
		BLE		_timer_start_done
		LDR		r3, =SECOND_LEFT
		LDR		r1, [r3]
		STR		r0, [r3]
		LDR		r3, =STCTRL
		MOV		r4, #STCTRL_GO
		STR		r4, [r3]
		
		LDR		r3,	=STCURRENT
		MOV		r4, #STCURR_CLR
		STR		r4, [r3]
_timer_start_done
		MOV		r0, r1
		MOV		pc, lr		; return to SVC_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void timer_update( )
        EXPORT        _timer_update
_timer_update
		LDR    r3, =SECOND_LEFT    ; retrieve seconds left
		LDR    r0, [r3]
		SUB    r0, r0, #1        ; decrement seconds
		STR    r0, [r3]        ; save seconds left
		CMP    r0, #0
		BNE    _timer_update_done    ; if seconds still remain, don't stop SysTick
			
		LDR    r3, =STCTRL        ; Stop SysTick
		MOV    r4, #STCTRL_STOP
		STR    r4,    [r3]            
			
	; invoke a user-provided signal handler
		MOVS    R0,    #3        ; Set SPSEL bit 1, nPriv bit 0
		MSR    CONTROL, R0        ; Now thread mode uses PSP for user    
		LDR    r3, =USR_HANDLER    ; call a user-provided handler
		LDR    r4,[r3]
		BX    r4            ; Invoke the handler (r0)    
        
_timer_update_done
		MOV        pc, lr        ; return to SysTick_Handler


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void* signal_handler( int signum, void* handler )
			EXPORT	_signal_handler
_signal_handler
	;; Implement by yourself
			CMP		r0, #SIGALRM			
			BNE		_signal_handler_done	; only check SIGALRM (r0)
			
			LDR		r3, =USR_HANDLER		; save user-provided handler function (r1)
			LDR		r2, [r3]				; r2 = previous user handler function
			STR		r1, [r3]

_signal_handler_done
			MOV		r0, r2		; r0 = return value (previous user handler)
			MOV		pc, lr		; return to Reset_Handler
			
			END