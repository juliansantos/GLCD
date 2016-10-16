;*******************************************************************
;*                       LCD FIRMWARE 							   *
;*******************************************************************
  
            INCLUDE 'MC9S08JM16.inc'
         
  ;*******************************Pin definition section
pin_ENABLE EQU 5 ; pin ENABLE
pin_RS EQU 4 ; pin RS
  
  ;*******************************LCD  label definition 
cmd_clear  EQU 1H ; Command to clear the display
cmd_8bitmode EQU 38H ; Command to set parallel mode at 8 bits
cmd_line1 EQU 80H ; Command to set the cursor in the line 1
cmd_line3 EQU 88H 
cmd_line2 EQU 90H ; Command to set the cursor in the line 2
cmd_line4 EQU 98H 
cmd_displayON EQU 0CH ; Command to turn on the display
cmd_displayOFF EQU 80H

  ;*****************************Flags definition
display_P EQU 0  
  		
            XDEF _Startup
            ABSENTRY _Startup

            ORG   Z_RAMStart       ; Insert your data definition here
var_delay DS.B   2
flags     DS.B   1
counter   DS.B   1

            ORG    ROMStart
            
_Startup:   CLRA
			CLRA 
           	STA SOPT1 ; disenable watchdog
            LDHX   #RAMEnd+1        ; initialize the stack pointer
            TXS	
  	 		   
main:
			JSR initialconfig
			JSR initialstates
			JSR init_LCD
			LDHX #initial_message
			JSR write_message
			JSR init_TPM1
			JSR init_KBI
			JMP *
			
;******************************************Subroutine for set the initial configuration of the MCU            
initialconfig:
			BSET pin_ENABLE,PTFDD ; Setting data direction (pin ENABLE)
			BSET pin_RS,PTFDD ; Setting data direction (pin RS)
			MOV #$FF,PTEDD ; Setting data direction pins of data to LCD
			RTS
			
;******************************************Subroutine for set the initial states of the pins and vars			
initialstates: 
			BSET pin_ENABLE,PTFD ; Initial State Enable pin
			BSET pin_RS,PTFD ; Initial States RS pin
			MOV #$FF,PTED
			MOV #0,counter
			MOV #00H,flags
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

		   RTS		
;******************************************Subroutine to  initialize timer interrupt
init_TPM1:
		MOV #%01000111,TPM1SC ; Timer Off, Enable interrupt, PS{1:128}
		MOV #$AF,TPM1MODH 
		MOV #$FF,TPM1MODL
		BSET TPM1SC_CLKSA,TPM1SC		
		CLI
		RTS		   
		   	
;******************************************Subroutine for send data to LCD

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
			
;********************************************ISR KEY_BOARD
ISR_KEYBOARD:
	;JMP *
	RTI ; Return from interrupt			
;********************************************ISR TIMER 
ISR_TIMER:	BCLR TPM1SC_TOF,TPM1SC ; Clearing FlaG
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
			RTI
discharge:		BSET display_P,flags
			DEC counter
			LDA counter
			CMP #0
			BEQ charging 
			ADD #cmd_line3	
			JSR send_command	
			LDA #' '
			JSR send_data	
			RTI			
charging:
			MOV #0,counter
			BCLR display_P,flags
			BRA ISR_TIMER			
;********************************************Table to be displayed in the LCD

config_LCD:	DC.B cmd_8bitmode,cmd_displayON,cmd_clear,cmd_line2,0H  ; 90 second line
initial_message: DC.B '  BIENVENIDO ',2,0
msg1: DC.B '  Gracias ',0

			ORG Vtpm1ovf 			;Overflow Timer1 
			DC.W ISR_TIMER				
 			ORG Vkeyboard			;Keyboard
 			DC.W ISR_KEYBOARD 		
            ORG Vreset				; Reset
			DC.W  _Startup			
