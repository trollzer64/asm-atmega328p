;
; display-clock.asm
;
; Created: 15/06/2020 21:48:10
;

.def AUX = R16				; Para principais configurações
.def CTRL = R17				; LCD: E, RW, RS,-,-,-,-,-
.def DATA = R18				; LCD: D[0..7]
.def H = R19				; Registrador para guardar horas (Um dígito por nibble: [D0,D1])
.def M = R20				; Registrador para guardar minutos (Um dígito por nibble: [D0,D1])
.def S = R21				; Registrador para guardar segundos (Um dígito por nibble: [D0,D1])
.def MAXV = R22				; Registrador para o número máximo de um dígito

.ORG 0x0000
RJMP reset
.ORG 0x0012
RJMP timer2_ovf

reset:
	; LCD data
	LDI AUX,0b11111111	; D[0..7]
	OUT DDRD,AUX
	; LCD control
	LDI AUX,0b00000111	; E, RW, RS,-,-,-,-,-
	OUT DDRB,AUX
	; Tempo inicial
	LDI H,0x23
	LDI M,0x59
	LDI S,0x45
	; INICIALIZAÇÃO DO DISPLAY
	lcd_init:
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
	
	; Setup Timer - Oscilador externo, modo assíncrono
	LDI AUX,0b00100000	; (AS2) Asynchronous Timer/Counter 2
	STS ASSR,AUX
	LDI AUX,0b00000101	; (CS22|CS20) prescaler = 128
	STS TCCR2B,AUX
	; Interrupções - Timer 2, modo overflow
	SEI
	LDI AUX,0b00000001	; (TOIE2) Overflow Interrupt Enable
	STS TIMSK2,AUX
; LOOP PARA INTERROMPER
loop:
	NOP
	RJMP loop
; INCREMENTO DE TEMPO E DISPLAY DO NOVO DÍGITO
timer2_ovf:
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

	; H(0)
	LDI MAXV,0x03
	MOV AUX,H			; Carrega número do nibble
	ANDI AUX,0x0F
	RCALL limit_fcn		; Incrementa e limita ao numero máximo
	ANDI H,0xF0
	ADD H,AUX			; Guarda número no nibble
	CPI AUX,0x00
	BRNE send_message	; Se overflow número, incrementa o próximo
	
	; H(1)
	LDI MAXV,0x02
	MOV AUX,H			; Carrega número do nibble
	ANDI AUX,0xF0
	SWAP AUX
	RCALL limit_fcn		; Incrementa e limita ao numero máximo
	SWAP AUX
	ANDI H,0x0F
	ADD H,AUX			; Guarda número no nibble
	CPI AUX,0x00
	BRNE send_message	; Se overflow número, incrementa o próximo
	send_message:
		RCALL write_fcn
	RETI

; limit_fcn(AUX, MAXV) - Incrementa um valor com um limite máximo
limit_fcn:
	CP AUX,MAXV			; Se número máximo...
	BRNE incr
	LDI AUX,0xFF		; Zerar valor
	incr:
		INC AUX
	RET

; write_fcn(H, M, S) - Entra no display o valor selecionado
write_fcn:
	; Clear display :
	LDI CTRL,0b00000000
	LDI DATA,0b00000001		; Clear display command
	RCALL send_fcn
	
	; 5 - Write data to CGRAM/DDRAM :
	LDI CTRL,0b00000100
	LDI AUX,'0'				; Valor base do char '0'

	MOV DATA,H
	ANDI DATA,0xF0
	SWAP DATA
	ADD DATA,AUX
	RCALL send_fcn

	MOV DATA,H
	ANDI DATA,0x0F
	ADD DATA,AUX
	RCALL send_fcn

	LDI DATA,':'
	RCALL send_fcn

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

; send_fcn(CTRL, DATA) - envia um byte de dados ao LCD
send_fcn:
	RCALL wait_fcn			; Check busy flag

	OUT PORTD,DATA
	OUT PORTB,CTRL

	ORI CTRL,0b00000001		; E on 1
	OUT PORTB,CTRL
	ANDI CTRL,0b11111110	; E on 0
	OUT PORTB,CTRL

	RET

; wait_fcn() - Espera a busy flag do LCD estar livre
wait_fcn:
	PUSH R16
	PUSH R17
	
	; PORTD input
	LDI R16,0b00000000			; D[0..7]
	OUT DDRD,R16
	busy:
		; Send read command
		LDI R16,0b00000010		; E, RW, RS
		OUT PORTB,R16
		ORI R16,0b00000001		; E on 1
		OUT PORTB,R16
		; Check busy flag
		IN R17,PORTD
		SBRC R17,7
		RJMP busy

	RCALL delay_fcn				; Espera de 0.000040s necessária‬

	; End of LCD instruction
	ANDI R16,0b11111110			; E on 0
	OUT PORTB,R16

	; PORTD output
	LDI R16,0b11111111			; D[0..7]
	OUT DDRD,R16

	POP R17
	POP R16
	RET

; delay_fcn() -  Delay necessário após clear da busy flag do LCD
delay_fcn:
	PUSH R18
	PUSH R17
	LDI R17,0x02
	LDI R18,0xFF
	; t_ADD = 0.000040s
	back:
		DEC R17			; 1		CLK
		BRNE back		; 1/2	CLK
		DEC R18			; 1		CLK
		BRNE back		; 1/2	CLK
	POP R17
	POP R18
	RET

