;
; display-clock.asm
;
; Created: 15/06/2020 21:48:10
;

.equ B0 = PC0				; Botão 0
.def AUX = R16				; Para principais configurações
.def CTRL = R17				; LCD: E, RW, RS,-,-,-,-,-
.def DATA = R18				; LCD: D[0..7]
.def M = R19
.def S = R20
.def MAXV = R21

.ORG 0x0000
RJMP reset
.ORG 0x0012
RJMP timer2_ovf

reset:
	; Botao
	LDI AUX,0b11111110
	OUT DDRC,AUX
	LDI AUX,0b11000001
	OUT PORTC,AUX
	; Timer
	LDI AUX,0b00100000	; (AS2)
	STS ASSR,AUX
	LDI AUX,0b00000101	; (CS22|CS20)
	STS TCCR2B,AUX
	; Interrupções
	SEI
	LDI AUX,0b00000001	; (TOIE2)
	STS TIMSK2,AUX		; Interrupção do Timer/Counter 2
	; LCD data
	LDI AUX,0b11111111	; D[0..7]
	OUT DDRD,AUX
	; LCD control
	LDI AUX,0b00000111	; E, RW, RS
	OUT DDRB,AUX
	; Initial time
	LDI M,0x59
	LDI S,0x45
; INICIALIZAÇÃO DO DISPLAY (TABELA 13)
init:
	; 1 - Power supply
	RCALL wait_fcn
	; 2 - Function set
	LDI CTRL,0b00000000
	LDI DATA,0b00111000		; 8b mode; 2-line display; 5x8 font
	RCALL send_fcn
	; 3 - Display on/off control
	LDI CTRL,0b00000000
	LDI DATA,0b00001100		; Display on; Cursor off; blink off
	RCALL send_fcn
	; 4 - Entry mode set :
	LDI CTRL,0b00000000
	LDI DATA,0b00000110		; Increment and shift cursor; Don't shift display
	RCALL send_fcn

loop:
	NOP
	RJMP loop

timer2_ovf:
	; incrementar aqui M ou S
	
	; S(0)
	LDI MAXV,0x09
	MOV AUX,S			; Carrega número do nibble
	ANDI AUX,0x0F
	RCALL limit_fcn		; Incrementa e limita ao numero máximo
	ANDI S,0xF0
	ADD S,AUX			; Guarda número no nibble
	CPI AUX,0x00
	BRNE send_message	; Se overflow número, incrementa o próximo
	
	; S(1)
	LDI MAXV,0x05
	MOV AUX,S			; Carrega número do nibble
	ANDI AUX,0xF0
	SWAP AUX
	RCALL limit_fcn		; Incrementa e limita ao numero máximo
	SWAP AUX
	ANDI S,0x0F
	ADD S,AUX			; Guarda número no nibble
	CPI AUX,0x00
	BRNE send_message	; Se overflow número, incrementa o próximo
	
	; M(0)
	LDI MAXV,0x09
	MOV AUX,M			; Carrega número do nibble
	ANDI AUX,0x0F
	RCALL limit_fcn		; Incrementa e limita ao numero máximo
	ANDI M,0xF0
	ADD M,AUX			; Guarda número no nibble
	CPI AUX,0x00
	BRNE send_message	; Se overflow número, incrementa o próximo
	
	; M(1)
	LDI MAXV,0x05
	MOV AUX,M			; Carrega número do nibble
	ANDI AUX,0xF0
	SWAP AUX
	RCALL limit_fcn		; Incrementa e limita ao numero máximo
	SWAP AUX
	ANDI M,0x0F
	ADD M,AUX			; Guarda número no nibble
	CPI AUX,0x00
	BRNE send_message	; Se overflow número, incrementa o próximo
send_message:
	RCALL write
	RETI

; limit_fcn(AUX, MAXV)
limit_fcn:
	CP AUX,MAXV
	BRNE incr
	LDI AUX,0xFF
incr:
	INC AUX

	RET

; ESCREVENDO CARACTERES
write:
	; Clear display :
	LDI CTRL,0b00000000
	LDI DATA,0b00000001		; Clear display
	RCALL send_fcn
	
	; 5 - Write data to CGRAM/DDRAM :
	LDI CTRL,0b00000100
	LDI AUX,'0'

	MOV DATA,M
	ANDI DATA,0xF0
	SWAP DATA
	ADD DATA,AUX
	RCALL send_fcn

	MOV DATA,M
	ANDI DATA,0x0F
	ADD DATA,AUX
	RCALL send_fcn

	LDI DATA,':'
	RCALL send_fcn

	MOV DATA,S
	ANDI DATA,0xF0
	SWAP DATA
	ADD DATA,AUX
	RCALL send_fcn

	MOV DATA,S
	ANDI DATA,0x0F
	ADD DATA,AUX
	RCALL send_fcn

	RET

; (CTRL, DATA)
send_fcn:
	RCALL wait_fcn			; Check busy flag

	OUT PORTD,DATA
	OUT PORTB,CTRL

	ORI CTRL,0b00000001		; E on 1
	OUT PORTB,CTRL
	ANDI CTRL,0b11111110	; E on 0
	OUT PORTB,CTRL

	RET

wait_fcn:
	PUSH R16
	PUSH R17
	
	; PORTD input
	LDI R16,0b0000000	; D[0..7]
	OUT DDRD,R16
busy:
	; Send read command
	LDI R16,0b00000010	; E, RW, RS
	OUT PORTB,R16
	ORI R16,0b00000001		; E on 1
	OUT PORTB,R16
	; Check busy flag
	IN R17,PORTD
	SBRC R17,7
	RJMP busy

	RCALL delay

	; End of LCD instruction
	ANDI R16,0b11111110	; E on 0
	OUT PORTB,R16

	; PORTD output
	LDI R16,0b1111111	; D[0..7]
	OUT DDRD,R16

	POP R17
	POP R16
	RET

delay:
	PUSH R18
	PUSH R17
	LDI R17,0x02
	LDI R18,0xFF
	; t = 0.000071s, t_ADD = 0.000040s
back:
	DEC R17			; 1		CLK
	BRNE back		; 1/2	CLK
	DEC R18			; 1		CLK
	BRNE back		; 1/2	CLK

	POP R17
	POP R18
	RET

man_break:
	SBIC PINC,B0
	RJMP man_break
latch:
	SBIS PINC,B0
	RJMP latch

	RET