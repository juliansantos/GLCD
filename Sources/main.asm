;*******************************************************************
;*                       LCD FIRMWARE 							   *
;* 					AUTHOR: JULIAN ALFONSO SANTOS BUSTOS     	   *
;*******************************************************************
            INCLUDE 'MC9S08JM16.inc'   
  ;*******************************Pin definition section
pin_ENABLE EQU 5 ; pin ENABLE
pin_RS EQU 4 ; pin RS
pin_trigger EQU 4; 
pin_LED EQU 0
  
  ;*******************************LCD  label definition 
cmd_clear  EQU 01H ; Command to clear the display
cmd_8bitmode EQU 38H ; Command to set parallel mode at 8 bits
cmd_line1 EQU 80H ; Command to set the cursor in the line 1
cmd_line3 EQU 88H 
cmd_line2 EQU 90H ; Command to set the cursor in the line 2
cmd_line4 EQU 98H 
cmd_displayON EQU 0CH ; Command to turn on the display
cmd_displayOFF EQU 80H
cmd_home EQU 2H


  ;*****************************Flags definition
display_P EQU 0  
push_key EQU 1
  		
            XDEF _Startup
            ABSENTRY _Startup

            ORG   Z_RAMStart       ; Insert your data definition here
var_delay DS.B   2
flags     DS.B   1
counter   DS.B   1
key       DS.B   1  ; Key that has been pushed
time      DS.B   2 ; Time proportional to the distance
distance  DS.B   3
number    DS.B   2 
tmp       DS.B   2 ; Temporal
unidades  DS.B   1		
decenas   DS.B   1
centenas  DS.B   1

            ORG    ROMStart
            
_Startup:   CLRA
			CLRA 
           	STA SOPT1 ; disenable watchdog
            LDHX   #RAMEnd+1        ; initialize the stack pointer
            TXS	
  	 		   
main:
			JSR initialconfig ; Subroutine for initial configuration of parallel input ports
			JSR initialstates ; Subroutine for set initial states
			JSR init_LCD ; Subroutine for initilaze LCD
			LDHX #initial_message 
			JSR write_message ; Display the initial message
			JSR init_KBI ; For initialize the KBI interrupt
			JSR init_TPM1 ; For initialize the timer 1 second interrupt
			JSR initIRQ
			JMP *
			
;******************************************Subroutine for set the initial configuration of the MCU            
initialconfig:
			BSET pin_ENABLE,PTFDD ; Setting data direction (pin ENABLE)
			BSET pin_RS,PTFDD ; Setting data direction (pin RS)
			MOV #$FF,PTEDD ; Setting data direction pins of data to LCD
			MOV #%11110000,PTGDD
			BSET pin_trigger,PTCDD
			BSET pin_LED,PTBDD
			RTS
			
;******************************************Subroutine for set the initial states of the pins and vars			
initialstates: 
			BSET pin_ENABLE,PTFD ; Initial State Enable pin
			BSET pin_RS,PTFD ; Initial States RS pin
			MOV #$FF,PTED
			MOV #0,counter
			MOV #00H,flags
			MOV #00H,key
			MOV #00H,distance
			MOV #00H,distance+1
			MOV #00H,distance+2
			BCLR pin_trigger,PTCD
			MOV #00H,number+0
			MOV #00H,number+1
			BSET pin_LED,PTBD
			RTS 
			
;******************************************Subroutine for initilize the LCD
init_LCD:
		 	MOV #8,var_delay
			JSR delayAx5ms ; delay for 20ms (level voltage desired to LCD)
			LDHX #config_LCD ;	Load initial direction LCD		
bucle_initLCD:	LDA ,X ; Deferencing pointer
			CBEQA #0H,fin_initLCD			
			JSR send_command             
			AIX #1 ; Incrementing pointer
			BRA bucle_initLCD ; Repet until end
fin_initLCD:	RTS

;******************************************Subroutine to initialize keyboard interrupt
init_KBI:
		   LDA #%00001111
		   STA PTGPE ; Enabling pull-up G 0-1-2-3
		   MOV #%11000011,KBIES  ; Keyboard Edge Select Bit 0 (Pull down)
		   MOV #%11000011,KBIPE ;  Keyboard pin enable
		   MOV #%00000100,KBISC ; Clearing flag and setting mod for edge
		   BSET KBISC_KBIE,KBISC  ; Enabling interrupt for keyboard
		   RTS		
		   
;******************************************Subroutine to  initialize timer interrupt
init_TPM1:
		MOV #%01000111,TPM1SC ; Timer Off, Enable interrupt, PS{1:128}
		MOV #$AF,TPM1MODH 
		MOV #$FF,TPM1MODL
		BSET TPM1SC_CLKSA,TPM1SC		
		MOV #%11110000,PTED ; neccesary for keyboard
		CLI
		RTS	

;********************************************************************Subroutine for initialize IRQ
initIRQ:
			MOV #01110100B,IRQSC ; ACK clearing flag
			;BSET IRQSC_IRQIE,IRQSC ; Enabling interrupt
			RTS			   
		   	
;********************************************************************Subroutines neccesaries to send data to LCD
enable_pulse: BSET pin_ENABLE,PTFD 
 			MOV #4,var_delay
			JSR delayAx5ms
            BCLR pin_ENABLE,PTFD
			RTS
	
send_command: STA PTED ; Send command to LCD terminals
			BCLR pin_RS,PTFD ; command mode
			JSR enable_pulse
			MOV #4,var_delay
			JSR delayAx5ms
			RTS
	
send_data: 	STA PTED ; Send data to LCD terminal
			BSET pin_RS,PTFD ; data mode
			JSR enable_pulse
			MOV #4,var_delay
			JSR delayAx5ms
			RTS
			
write_message: LDA ,X ; Deferencing pointer
			CBEQA #0H,fin_messageLCD			
			JSR send_data            
			AIX #1 ; Incrementing pointer
			BRA write_message ; Repet until end
fin_messageLCD:	RTS	
							
							
;******************************************Subroutine for create delays
delayAx5ms: ; 6 cycles the call of subroutine
			PSHH ; save context H
			PSHX ; save context X
			PSHA ; save context A
			LDA var_delay ;  cycles
delay_2:    LDHX #1387H ; 3 cycles 
delay_1:    AIX #-1 ; 2 cycles
	    	CPHX #0 ; 3 cycles  
			BNE delay_1 ; 3 cycles
			DECA ;1 cycle
			CMP #0 ; 2 cycles
			BNE delay_2  ;3 cycles
			PULA ; restore context A
			PULX ; restore context X
			PULH ; restore context H
			RTS ; 5 cycles				
			
;***********************************************************************************ISR KEY_BOARD
ISR_KEYBOARD:
			BSET IRQSC_IRQIE,IRQSC ; Enabling interrupt
			BRSET PTGD_PTGD0,PTGD,Fila0
			BRSET PTGD_PTGD1,PTGD,Fila1
			BRSET PTGD_PTGD2,PTGD,Fila2
			BRSET PTGD_PTGD3,PTGD,Fila3		
			BRA ISR_KEYBOARD
			
Fila0: ; Left, Zero, Right, Reset
			JSR detect_column 
			LDA ,X ;Dereferecing pointer
			BRA Show_key
			
Fila1: ; One, Two, Three, Stop
			JSR detect_column 
			AIX #4D
			LDA ,X ;Dereferecing pointer			
			BRA Show_key
Fila2: ; Four, Five, Six , OK
			JSR detect_column 
			AIX #8D
			LDA ,X ;Dereferecing pointer			
			BRA Show_key
Fila3: ; Seven, Eight, Nine, Del		
			JSR detect_column 
			AIX #12D
			LDA ,X ;Dereferecing pointer
			BRA Show_key
				
detect_column: ;Subroutine te detect a column
			LDHX #keyboard	
			BCLR 7,PTED 
			LDA PTGD
			AND #%00001111 ; Mask the input
			BEQ column0
			BCLR 6,PTED
			LDA PTGD
			AND #%00001111 ; Mask the input
			BEQ column1
			BCLR 5,PTED
			LDA PTGD
			AND #%00001111 ; Mask the input
			BEQ column2
			BCLR 4,PTED
			LDA PTGD
			AND #%00001111 ; Mask the input
			BEQ column3 	
			BRA detect_column	
			RTS
column0: RTS
column1: AIX #1
		 RTS	
column2: AIX #2
		 RTS
column3: AIX #3
		 RTS			
							
clrscreen: ; subroutine for clear the display and put the cursor at 0,0 position
			LDA #cmd_clear
			JSR send_command
			LDA #cmd_home
			JSR send_command
			LDHX #msg2 ; Distancia
			JSR write_message 
			LDA #cmd_line3
			JSR send_command
			LDHX #msg1 ; Lectura
			JSR write_message 
			RTS
				
Show_key:
			STA key	
			CBEQA #40H,reset ; Test for reset signal 
			BRSET push_key,flags,sk_0
			MOV #0,number+0
			AND #0FH
			STA number+1	
			JSR clrscreen ; show numbers
			BRA sk_1
			
sk_0:		LDX number+1  ; multiplication * 10 
     	    LDA #10D				
		    MUL 
		    STA tmp+1
		    STX tmp+0
		   
		    LDX number+0 
		    LDA #10D				
		    MUL
		    ADD tmp+0
		    STA tmp+0

			LDA tmp+0 ; Save new number
			STA number+0
			LDA tmp+1
			STA number+1
			LDA key
			AND #0FH
			ADD number+1
			STA number+1
			CLRA
			ADC number+0
		    		
sk_1:		LDA #cmd_line2
			ADD #3
			JSR send_command
			LDHX number
			LDA number+1
			LDX #100D
			DIV
			STA centenas
			ORA #30H
			JSR send_data
			PSHH
			LDHX #0000H
			PULA
			LDX #10D
			DIV
			STA decenas
			ORA #30H
			JSR send_data			
			PSHH
			PULA
			STA unidades
			ORA #30H
			JSR send_data
			BRA end_isr_key
					
sk_2:		LDA key		
			CBEQA #'L',left
			CBEQA #'R',right
			CBEQA #'S',stop
			CBEQA #'O',ok
			CBEQA #'D',del
			BRA reset
			
reset:
	BCLR IRQSC_IRQIE,IRQSC ; OFF IRQ
	JMP _Startup	
				
left:
right:
stop:
ok:
del:

			;JMP main
								
end_isr_key: ;JMP *	
			LDA #'c'
			JSR send_data
			LDA #'m'
			JSR send_data
			MOV #%11110000,PTED ; Mandatory for keyboard interrupt
		   	BSET push_key,flags ; Flag for key pushed
		   	;MOV #20D,var_delay			
			;JSR delayAx5ms ;For debouncing 20*5ms
		    BSET KBISC_KBACK,KBISC ; Mandatory for future interrupts
			RTI ; Return from interrupt	
					
;********************************************ISR TIMER 
ISR_TIMER:	BCLR TPM1SC_TOF,TPM1SC ; Clearing FlaG

			BSET pin_trigger,PTCD ; Pulse for trigger
			MOV #1D,var_delay			
			JSR delayAx5ms ; Delay for 5ms
			BCLR pin_trigger,PTCD
			
			BRSET push_key,flags,end_isr_tpm
			BRSET display_P,flags,discharge
			INC counter
			LDA counter
			CMP #6
			BHI discharge 
			ADD #cmd_line3
			JSR send_command
			LDA #7
			JSR send_data
			LDA counter	
			MOV #%11110000,PTED ; neccesary for keyboard			 
end_isr_tpm:		RTI
discharge:		BSET display_P,flags
			DEC counter
			LDA counter
			CMP #0
			BEQ charging 
			ADD #cmd_line3	
			JSR send_command	
			LDA #' '
			JSR send_data
			MOV #%11110000,PTED ; neccesary for keyboard		
			RTI			
charging:
			MOV #0,counter
			BCLR display_P,flags
			BRA ISR_TIMER			

;*****************************************************************************Routine for IRQ
ISR_IRQ:
		LDHX #0000H
count_time:		AIX #1
		NOP
		NOP
		NOP
		BIH count_time
		STHX time
		LDA #cmd_line4
		ADD #3
		JSR send_command 
		JSR show_measure
		MOV #%11110000,PTED 
		BSET 2,IRQSC ; clearing flag
		RTI	
		
;**************************************************************Subroutine to show measure
show_measure:
	   CLRA 
	   STA distance+0
	   CLRA 
	   STA distance+1
	   CLRA
	   STA distance+2
	   
	   LDX time+1 
	   LDA #4D				
	   MUL 
	   STA distance+2
	   STX distance+1
	   
	   LDX time+0 
	   LDA #4D				
	   MUL
	   ADD distance+1
	   STA distance+1
	   CLRA 
	   TXA
	   ADC distance+0
	   STA distance+0
	   		
	   		LDA distance+0
	   		PSHA
	   		PULH
			LDA distance+1
			LDX #100D
			DIV
			STA centenas
			PSHH
			LDHX #0000H
			PULA
			LDX #10D
			DIV
			STA decenas		
			PSHH
			PULA
			STA unidades
		
	   LDA centenas
	   LDX #4
	   MUL
	   STA tmp+0
	   LDA decenas
	   LSRA
	   ADD tmp+0
	   STA tmp+0
	

	   	LDA distance+1
	   	SUB tmp+0
	   	STA distance+1
	   	CLRA
	   	LDA distance+0
	   	SBC #0
	   	STA distance+0   
				   
		LDA distance+0
	   		PSHA
	   		PULH
			LDA distance+1
			LDX #100D
			DIV
			ORA #30H
			JSR send_data
			PSHH
			LDHX #0000H
			PULA
			LDX #10D
			DIV
			ORA #30H
			JSR send_data	
			PSHH
			PULA
			ORA #30H
			JSR send_data
			LDA #'c'
			JSR send_data
			LDA #'m'
			JSR send_data	   
	   RTS	 	   	
	         
;*****************************************************************************Table to be displayed in the LCD

config_LCD:	DC.B cmd_8bitmode,cmd_displayON,cmd_clear,cmd_line2,0  ; 90 second line
initial_message: DC.B '  BIENVENIDO ',2,0
keyboard: DC.B 1BH,'0',1AH,40H,'123',9,'456',10H,'789',11H,0 ; Left, Right, Del, OK, Start, RESET
msg1: DC.B '   Lectura: ',0
msg2: DC.B '   Distancia: ',0


;************************************************************************************VECTORS OF INTERRUPT
			ORG Virq				;External interrupt
			DC.W ISR_IRQ			
			ORG Vtpm1ovf 			;Overflow Timer1 
			DC.W ISR_TIMER				
 			ORG Vkeyboard			;Keyboard
 			DC.W ISR_KEYBOARD 		
            ORG Vreset				; Reset
			DC.W  _Startup			
