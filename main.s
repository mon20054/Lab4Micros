
; Archivo:	main.s
; Dispositivo:	PIC16F887
; Autor:	Javier Monzón 20054
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	Contador de 4 bits con interrupciones en el puerto A
;		Contador con TIMR0 e interrupciones en puerto B
; Hardware:	LEDs en el puerto A y B
;		Display de 7 segmentos en el puerto C y D
;
; Creado:	12 febrero 2022
; Última modificación: 14 febrero 2022

PROCESSOR 16F887
#include <xc.inc>
    
; Configuration word 1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscilador interno sin salidas
  CONFIG  WDTE = OFF            ; WDT disabled (reinicio repetitivo del PIC)
  CONFIG  PWRTE = OFF           ; PWRT enabled (espera de 72ms al iniciar)
  CONFIG  MCLRE = OFF           ; El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              ; Sin protección de código 
  CONFIG  CPD = OFF             ; Sin protección de datos
  
  CONFIG  BOREN = OFF           ; Sin reinicio cuando el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            ; Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           ; Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = OFF             ; Programación en bajo voltaje permitida
  
; Configuration word 2
  CONFIG  BOR4V = BOR40V        ; Reinicio abajo de 4V 
  CONFIG  WRT = OFF             ; Protección de autoescritura por el programa desactivada
  
PSECT udata_shr			; Variables temporales en memoria compartida
 wtemp:		DS  1
 status_temp:	DS  1
    
PSECT udata_bank0		; Variables almacenadas en el banco 0
  cont_1:	DS  1		; Contador de botones
  cont_2:	DS  1		; Contador de TMR0
  cont_3:	DS  1		; Contador entre TMR0 y unidades
  unidades:	DS  1		; Unidades de segundos
  decenas:	DS  1		; Decenas de segundos
  six:		DS  1		; Variable con valor de 6
  ten:		DS  1		; Variable con valor de 10
  offset1:	DS  1		; Offset para tabla de unidades
  offset2:	DS  1		; Offset para tabla de decenas
  binario1:	DS  1		; Valor en binario para display de 7 segmentos unidades
  binario2:	DS  1		; Valor en binario para display de 7 segmentos decenas
  
PSECT resVect, class = CODE, abs, delta = 2
 ;-------------- vector reset ---------------
 ORG 00h			; Posición 00h para el reset
 resVect:
    goto main
    
PSECT intVect, class = CODE, abs, delta = 2
ORG 004h				; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
 
push:
    movwf   wtemp		; Se guarda W en el registro temporal
    swapf   STATUS, W		
    movwf   status_temp		; Se guarda STATUS en el registro temporal
    
isr:
    btfss   PORTB,   4		; Ver si boton 1 fue presionado
    call    antirebotes1
    btfss   PORTB,   5		; Ver si boton 2 fue presionado
    call    antirebotes2
    banksel INTCON
    btfsc   T0IF		; Ver si bandera de TMR0 se encendió
    call    t0
    bcf	    RBIF		; Limpiamos bandera de interrupcion del puerto B
    
pop:
    swapf   status_temp, W	
    movwf   STATUS		; Se recupera el valor de STATUS
    swapf   wtemp, F
    swapf   wtemp, W		; Se recupera el valor de W
    retfie  
    
PSECT code, delta = 2, abs
ORG 100h		    ; posición 100h para el codigo
;------------- CONFIGURACION ------------
main:
    call    config_IO		; Configuración de I/O
    call    config_clk		; Configuración de Oscilador
    call    config_tmr0
    call    config_int		; Configuración de interrupciones
    
loop:
    btfsc   cont_1,	4   ; Verifica si contador 1 es mayor a 15
    decf    cont_1,	1   ; Hace que contador 1 no sea mayor a 15
    btfsc   cont_1,	7   ; Verifica si contador 1 es negativo
    incf    cont_1,	1   ; Hace que contador 1 nunca sea menor a 0
    btfsc   cont_2,	4   ; Verifica si contador 2 es mayor a 15
    call    complete1
    btfsc   cont_3,	4   ; Verifica si contador 3 es mayor a 15
    call    complete2
    movf    unidades,	0   ; Se mueve el valor de unidades a W
    subwf   ten,	0   ; Se verifica si las unidades alcanzaron 10
    btfsc   STATUS,	2   ; Se verifica si la bandera de zero está encendida
    call    diez
    movf    decenas,	0   ; Se mueve el valor de decenas a W
    subwf   six,	0   ; Se verifica si las decenas alcanzaron 6
    btfsc   STATUS,	2   ; Se verifica si la bandera de zero está encendida
    clrf    decenas	    ; Se limpia el registro de decenas	    
    movf    cont_1,	0   ; Se mueve el valor de contador 1 a W
    movwf   PORTA	    ; Se muestra el valor de contador 1 en PORTA
    movf    cont_2,	0   ; Se mueve el valor de contador 2 a W
    movwf   PORTB	    ; Se muestra el valor de contador 2 en PORTB<0:3>
    movf    unidades,	0   ; Se mueve el valor de unidades a W
    movf    decenas,	0   ; Se mueve el valor de decenas a W
    movf    unidades,	0   ; Se mueve el valor de unidades a W
    movwf   offset1	    ; Se almacena el valor de unidades en offset1
    movf    offset1,	0   ; Se mueve el offset 1 a W
    call    tabla1
    movwf   binario1	    ; Se almacena el valor obetnido de la tabla en el registro binario1 
    movf    binario1,	0   ; Se mueve el valor a W
    movwf   PORTC	    ; Se muestra el valor en display de 7 segmentos
    movf    decenas,	0   ; Se mueve el valor de decenas a W
    movwf   offset2	    ; Se almacena el valor de las decenas en offset2
    movf    offset2,	0   ; Se mueve el valor de offset 2 a W
    call    tabla2
    movwf   binario2	    ; Se almacena el valor obtenido de la tabla en el registro binario2
    movf    binario2,	0   ; Se mueve el valor de binario 2 a W
    movwf   PORTD
    goto    loop    
    
;------------- SUBRUTINAS ---------------
config_clk:
    banksel OSCCON	    ; cambiamos a banco de OSCCON
    bsf	    OSCCON,	 0  ; SCS -> 1, Usamos reloj interno
    bsf	    OSCCON,	 6
    bcf	    OSCCON,	 5
    bcf	    OSCCON,	 4  ; IRCF<2:0> -> 100 1MHz
    return
    
config_tmr0:
    banksel OPTION_REG	    ; Cambiamos a banco de OPTION_REG
    bcf	    OPTION_REG, 5   ; T0CS = 0 --> TIMER0 como temporizador 
    bcf	    OPTION_REG, 3   ; Prescaler a TIMER0
    bsf	    OPTION_REG, 2   ; PS2
    bsf	    OPTION_REG, 1   ; PS1
    bsf	    OPTION_REG, 0   ; PS0 Prescaler de 1 : 256
    banksel TMR0	    ; Cambiamos a banco 0 de TIMER0
    movlw   252		    ; Cargamos el valor 252 a W
    movwf   TMR0	    ; Cargamos el valor de W a TIMER0 para 4.44mS de delay
    bcf	    T0IF	    ; Borramos la bandera de interrupcion
    return
    
config_IO:
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH	    ; I/O digitales
    banksel TRISB
    bcf	    TRISB,  0	    ; RB0 como salida
    bcf	    TRISB,  1	    ; RB1 como salida
    bcf	    TRISB,  2	    ; RB2 como salida
    bcf	    TRISB,  3	    ; RB3 como salida
    bsf	    TRISB,  4	    ; RB4 como entrada
    bsf	    TRISB,  5	    ; RB5 como entrada
    banksel WPUB	    ; Banco para pullups puerto B
    bsf	    WPUB,   4	    ; RB0 con Pullup interno
    bsf	    WPUB,   5	    ; RB1 con Pullup interno
    banksel TRISA
    clrf    TRISA	    ; PORTA como salida
    clrf    TRISC	    ; PORTC como salida
    clrf    TRISD	    ; PORTD como salida
    banksel PORTA
    clrf    PORTA	    ; Apagamos PORTA
    clrf    PORTB	    ; Apagamos PORTB
    clrf    PORTC	    ; Apagamos PORTC
    clrf    PORTD	    ; Apagamos PORTD
    movlw   0x00	
    movwf   cont_1	    ; Contador 1 inicia en 0
    movlw   0x00
    movwf   cont_2	    ; Contador 2 inicia en 0
    movlw   0x00
    movwf   cont_3	    ; Contador 3 inicia en 0
    movlw   0x00
    movwf   unidades	    ; Unidades inicia en 0
    movlw   0x06	    
    movwf   six		    ; Variable six vale 6
    movlw   0x0A
    movwf   ten		    ; Variable ten vale 10
    movlw   0x00
    movwf   offset1	    ; Offse1t inicia en 0
    movlw   0x00
    movwf   offset2	    ; Offset2 inicia en 0
    movlw   0x00
    movwf   decenas	    ; Decenas inicia en 0
    return
    
 config_int:
    banksel IOCB
    bsf	    IOCB,   4	    ; Interrupcion en RB4
    bsf	    IOCB,   5	    ; Interrupcion en RB5
    bsf	    T0IE	    ; Habilitamos interrupcion TMR0
    bcf	    T0IF	    ; Limpiamos bandera de TMR0
    banksel INTCON
    bsf	    GIE		    ; Habilitamos interrupciones
    bsf	    RBIE	    ; Habilitamos interrupcion PORTB
    bcf	    RBIF	    ; Limpiamos bandera de PORTB
    return
    
antirebotes1:
    btfss   PORTB, 4
    goto    $-1
    incf    cont_1
    return
   
antirebotes2:
    btfss   PORTB, 5
    goto    $-1
    decf    cont_1
    return
    
t0:
    call    reset_tmr0
    incf    cont_2
    return
    
complete1:
    clrf    cont_2
    incf    cont_3
    return
    
complete2:
    clrf    cont_3
    incf    unidades, 1
    return
 
reset_tmr0:
    banksel TMR0	    ; cambiamos de banco
    movlw   252
    movwf   TMR0	    ; delay 4.44mS
    bcf	    T0IF
    return
    
diez:
    clrf    unidades
    incf    decenas,	1
    return

org 0200h    
    
tabla1:
    clrf    PCLATH
    bsf	    PCLATH, 1
    addwf   PCL, 1		; Se suma el offset al PC y se almacena en dicho registro
    retlw   0b11011101		; Valor para 0 en display de 7 segmentos
    retlw   0b01010000		; Valor para 1 en display de 7 segmentos
    retlw   0b11001110		; Valor para 2 en display de 7 segmentos
    retlw   0b11011010		; Valor para 3 en display de 7 segmentos
    retlw   0b01010011		; Valor para 4 en display de 7 segmentos
    retlw   0b10011011		; Valor para 5 en display de 7 segmentos 
    retlw   0b10011111		; Valor para 6 en display de 7 segmentos 
    retlw   0b11010000		; Valor para 7 en display de 7 segmentos 
    retlw   0b11011111		; Valor para 8 en display de 7 segmentos
    retlw   0b11010011		; Valor para 9 en display de 7 segmentos
    
tabla2:
    clrf    PCLATH
    bsf	    PCLATH, 1
    addwf   PCL, 1		; Se suma el offset al PC y se almacena en dicho registro
    retlw   0b11011101		; Valor para 0 en display de 7 segmentos
    retlw   0b01010000		; Valor para 1 en display de 7 segmentos
    retlw   0b11001110		; Valor para 2 en display de 7 segmentos
    retlw   0b11011010		; Valor para 3 en display de 7 segmentos
    retlw   0b01010011		; Valor para 4 en display de 7 segmentos
    retlw   0b10011011		; Valor para 5 en display de 7 segmentos 
    retlw   0b10011111		; Valor para 6 en display de 7 segmentos 
    
END


