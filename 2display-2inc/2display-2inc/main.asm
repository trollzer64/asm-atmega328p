;
; 2display-2inc.asm
;
; Created: 15/06/2020 08:30:54
; Author : franc
;
;
; Engenharia de Computa��o
; Microcontroladores e Aplica��es
; A1 e A2
; Professor Eucl�rio
; 144171012 - Ana Virg�nia
; 144171033 - Francismar Condor
; 141171080 - Rodrigo de Souza Melo

.equ B0 = PC5				; Bot�o 0
.equ B1 = PC1				; Bot�o 1
.equ DISPLAY_CC = PORTD		; Display 0
.equ DISPLAY_CA = PORTB		; Display 1
.def AUX = R16				; Para principais configura��es
.def DTP = R17				; Configura se display � CC (0x00) ou CA (0x01)
.def N0 = R18				; Numero para display 0
.def N1 = R19				; Numero para display 1

.ORG 0x0000
;===
; Inicializa��o de portas (entradas e sa�das) e valores iniciais
;===
init:
	; Botao
	LDI AUX,0b11011101
	OUT DDRC,AUX			; configura PC1 e PC5 como entrada e resto sa�das
	LDI AUX,0xFF
	OUT PORTC,AUX			; habilita o pull-up da PORTC
	; Display0
	OUT DDRD,AUX			; PORTD como sa�da
	LDI AUX,0x00
	OUT DISPLAY_CC,AUX		; desliga o display (Catodo Comum desliga com 0)
	; Display1
	LDI AUX,0xFF
	OUT DDRB,AUX			; PORTB como sa�da
	OUT DISPLAY_CA,AUX		; desliga o display (Anodo Comum desliga com 1)

	; Configurando USB do Arduino
	STS UCSR0B,R1			; carrega o valor 0x00 em USCR0B

	; Valor inicial dos displays
	LDI AUX,0x00			; ambos come�am com 0
	LDI DTP,0x00			; decodifica para display 0
	RCALL decode
	LDI DTP,0x01			; decodifica para display 1
	RCALL decode
;===
; Verifica��o do aperto dos bot�es
;===
main:
	SBIC PINC,B0			; verifica se PINC em B0 � 0, sen�o
	RJMP b_1				; passa para verifica��o de B1
	CPI N0,0x09				; compara se valor � m�ximo (9)
	BRNE incr0				; se n�o for igual, incrementa
	LDI N0,0x00				; sen�o, zera valor
	
	MOV AUX,N0				; usa AUX como parametro em decode
	LDI DTP,0x00			; decodifica para display 0
	RJMP dis_num
b_1:
	SBIC PINC,B1			; verifica se PINC em B1 � 0, sen�o
	RJMP main				; passa para verifica��o de B0
	CPI N1,0x09				; compara se valor � m�ximo (9)
	BRNE incr1				; se n�o for igual, incrementa
	LDI N1,0x00				; sen�o, zera valor
	
	MOV AUX,N1				; usa AUX como parametro em decode
	LDI DTP,0x01			; decodifica para display 1
	RJMP dis_num

incr0:
	INC N0
	
	MOV AUX,N0				; usa AUX como parametro em decode
	LDI DTP,0x00			; decodifica para display 0
	RJMP dis_num
incr1:
	INC N1
	
	MOV AUX,N1				; usa AUX como parametro em decode
	LDI DTP,0x01			; decodifica para display 1

dis_num:
	RCALL decode
	RCALL delay				; evita m�ltiplos cliques do bot�o
	RJMP main				; volta ler bot�es
;===
; Atraso de aprox. 0,2 s � 16 MHz
;===
delay:
	; guardar vari�veis de subrotina
	PUSH R18
	PUSH R17
	PUSH R16
	; loop de delay
	LDI R18,16			; repete os la�os abaixo 16 vezes
volta:
	DEC R16				; decrementa R16
	BRNE volta			; enquanto R16 > 0 fica decrementando R16
	DEC R17				; decrementa R17
	BRNE volta			; enquanto R17 > 0 volta a decrementar R16
	DEC R18				; decrementa R18
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