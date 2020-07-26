;
; 2display-inc-dec.asm
;
; Created: 15/06/2020 21:43:26
; Author : franc
;

.equ B0 = PC5					; Bot�o 0
.equ B1 = PC1					; Bot�o 1
.equ DISPLAY_CC = PORTD			; Display 0
.equ DISPLAY_CA = PORTB			; Display 1
.def AUX = R16					; Para principais configura��es
.def DTP = R17					; Configura se display � CC (0x00) ou CA (0x01)
.def N0 = R18					; Numero para display 0
.def N1 = R19					; Numero para display 1

.ORG 0x0000
RJMP init						; desvia para o in�cio do programa
.ORG 0x0008
RJMP PCINT1_VECT				; interrup. 1 por mudan�a de pino (porta C)
;===
; Inicializa��o de portas (entradas e sa�das) e valores iniciais
;===
init:
	; Defini��o da pilha
	LDI AUX,HIGH(RAMEND)
	OUT SPH,AUX
	LDI AUX,LOW(RAMEND)
	OUT SPL,AUX

	; Botao
	LDI AUX,0b11011101
	OUT DDRC,AUX					; PC1 e PC5 como entrada e resto sa�das
	LDI AUX,0xFF
	OUT PORTC,AUX					; habilita pull-ups
	; Display0
	OUT DDRD,AUX					; PORTD como sa�da
	LDI AUX,0x00
	OUT DISPLAY_CC,AUX				; desliga o display (Catodo Comum desliga com 0)
	; Display1
	LDI AUX,0xFF
	OUT DDRB,AUX					; PORTB como sa�da
	OUT DISPLAY_CA,AUX				; desliga o display (Anodo Comum desliga com 1)

	; Configurando USB do Arduino
	STS UCSR0B,R1					; carrega o valor 0x00 em USCR0B
	
	; Interrup��es
	SEI								; Habilita interrup��o global
	LDI AUX,0b00000010
	STS PCICR,AUX					; Habilita interrup��o nos pinos de PORTC (PCINT8:14)
	LDI AUX,0b00100010
	STS PCMSK1,AUX					; Habilita interrup��o em PCINT9 e PCINT13

	; Valor inicial dos displays
	LDI AUX,0x00					; ambos come�am com 0
	LDI DTP,0x00					; decodifica para display 0
	RCALL decode
	LDI DTP,0x01					; decodifica para display 1
	RCALL decode
loop:
	NOP
	RJMP loop

PCINT1_VECT:
	; ===
	; Tratando interrup��o
	; ===
; botao 0 (PCINT13) incremento
bt0:
	SBIC PINC,B0							; verifica se PINC0 � 0, sen�o
	RJMP bt1								; verifica o outro bot�o
	
	; display0
	CPI N0,0x09							; compara se valor � m�ximo
	BRNE incr0							; se n�o for igual, incrementa
	LDI N0,0x00							; sen�o, zera valor
	; display1
	CPI N1,0x09							; compara se valor � m�ximo
	BRNE incr1							; se n�o for igual, incrementa
	LDI N1,0x00							; sen�o, zera valor
	
	RJMP dis_num						; exibe n�mero novo
; bot�o 1 (PCINT9) decremento
bt1:
	SBIC PINC,B1						; verifica se PINC0 � 0, sen�o
	RJMP dis_num						; retorna da interrup��o
	
	; display0
	CPI N0,0x00							; compara se valor � m�nimo
	BRNE decr0							; se n�o for igual, decrementa
	LDI N0,0x09							; sen�o, max valor
	; display1
	CPI N1,0x00							; compara se valor � m�nimo
	BRNE decr1							; se n�o for igual, decrementa
	LDI N1,0x09							; sen�o, max valor

	RJMP dis_num						; exibe n�mero novo

; fun��es auxiliares
incr0:
	INC N0
	RJMP dis_num
incr1:
	INC N1
	RJMP dis_num
decr0:
	DEC N0
	RJMP dis_num
decr1:
	DEC N1
	RJMP dis_num
; mostrando n�meros
dis_num:
	MOV AUX,N0						; usa AUX como parametro em decode
	LDI DTP,0x01					; decodifica para display 1
	RCALL decode
	
	MOV AUX,N1						; usa AUX como parametro em decode
	LDI DTP,0x00					; decodifica para display 0
	RCALL decode

	RCALL delay						; atraso para evitar missclick no botao
	RETI
;===
; Atraso de aprox. 0,2 s � 16 MHz
;===
delay:
	; guardar vari�veis de subrotina
	PUSH R18
	PUSH R17
	PUSH R16
	; loop de delay
	LDI R18,16				; repete os la�os abaixo 16 vezes
volta:
	DEC R16					; decrementa R16
	BRNE volta				; enquanto R16 > 0 fica decrementando R16
	DEC R17					; decrementa R17
	BRNE volta				; enquanto R17 > 0 volta a decrementar R16
	DEC R18					; decrementa R18
	BRNE volta

	; restaurar vari�veis de subrotina
	POP R16
	POP R17
	POP R18
	RET
;===
; Decodifica um valor de 0 -> F para o display (AUX 0 a F, DTP 0 ou 1)
;===
decode:
	LDI ZH,HIGH(Tabela_CC<<1)	; carrega endere�o da tabela
	LDI ZL,LOW(Tabela_CC<<1)	; << 1 para o bit 0
	ADD ZL,AUX					; AUX percorre at� a pos. relativa da mem�ria
	BRCC rd_tab					; carry pelo mesmo motivo do left shift
	INC ZH
rd_tab:
	LPM R0,Z					; l� valor no end. Tabela_CC(AUX)
	SBRC DTP,0					; se display CC (DTP(0)==0), vai para disp_cc
	RJMP disp_ca				; Sen�o, disp_ca
	; output do bin calculado
	disp_cc:
		OUT DISPLAY_CC,R0		; output para display CC
		RET
	disp_ca:
		LDI AUX, 0xFF			; registrador AUX n�o est� mais ocupado
		EOR R0, AUX				; CA tem bits invertidos do CC
		OUT DISPLAY_CA,R0		; output para display CA
		RET

;===
; Tabela de acendimento do 7seg
;===
Tabela_CC: .dw 0x86BF, 0xCFDB, 0xEDE6, 0x87FD, 0xE7FF, 0xFCF7, 0xDEB9, 0xF1F9