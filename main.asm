#include <p12f675.inc>
    radix	decimal
    __CONFIG _CP_OFF & _CPD_OFF & _BODEN_OFF & _MCLRE_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT &_PWRTE_ON
    errorlevel -302

;variable definitions --------------
	cblock	0x25
 		delay_1
		delay_2 ;ползват се от delay подпрограмата
        timer   ;броячът намалява всяка секунда и при достигане на 0
                ;се вика resetDevice. Следи се входа HEARTBEAT и ако
                ;се промени, то в timer се записва TIMEOUT
        prev    ;Пази последната стойност за нивото на HEARTBEAT входа
	endc

#define TIMEOUT     120
;pin def
#define  HEARTBEAT   5  ;вход който се променя периодично ако външното
                        ;устройство е ОК
#define  HBMASK      0x20
#define  RST         4  ;Изход за ресет на външното устройство
#define  ACTIVE      2  ;Индикатор за активност
;дефиниции на макроси -----------------
SELECT_BANK_0	macro
				bcf	STATUS,RP0
				endm
SELECT_BANK_1	macro
				bsf	STATUS,RP0
				endm
;code-------------------------------
		ORG	0x000
		goto	main

		ORG 0x004
		retfie
;подпрограми------------------------
delay ;Закъснение от около 250мс
		movlw	255
		movwf	delay_1
		movlw	255
		movwf	delay_2
delay_loop
		nop
		decfsz	delay_1,1
		goto	delay_loop
		movlw	255
		movwf	delay_1
		decfsz  delay_2,1
		goto	delay_loop
		return

;---------------------------------------------------------------------

main
;io pins
		movlw	0x07
		movwf	CMCON ;GP0,1,2 - Цифрови входове/изходи
		SELECT_BANK_1
		;calibration
		call 	0x3ff 	; Get the cal value
		movwf 	OSCCAL 	; Calibrate

		clrf	ANSEL		 ;GP0-GP3 са цифрови входове/изходи
		;TRISIO[x]=1 - input
		bsf		TRISIO,HEARTBEAT
		bcf		TRISIO,RST
        bcf     TRISIO,ACTIVE

		SELECT_BANK_0
        movlw   TIMEOUT
        movwf   timer
        bsf     GPIO,RST

main_loop
        bcf     GPIO,ACTIVE
        call    delay
        call    delay
        bsf     GPIO,ACTIVE
        call    delay
        call    delay

;проверка на HEARTBEAT
        movfw   GPIO
        andlw   HBMASK
        xorwf   prev,0
        btfsc   STATUS,Z
        goto    decTimer
;има промяна на HEARTBEAT. Възстановява се timer и се обновява prev
        movlw   TIMEOUT
        movwf   timer
        movfw   GPIO    
        andlw   HBMASK
        movwf   prev
        goto    main_loop

decTimer
        decfsz  timer,1
        goto    main_loop
resetDevice ;Рестарт на външното устройство
        bcf     GPIO,RST
        call    delay
        call    delay
        call    delay
        call    delay
        movlw   TIMEOUT
        movwf   timer
        bsf     GPIO,RST
        goto    main_loop

        END