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
cmd_line2 EQU 0C0H ; Command to set the cursor in the line 1
cmd_displayON EQU 0CH ; Command to turn on the display
cmd_displayOFF EQU 80H
  		
            XDEF _Startup
            ABSENTRY _Startup

            ORG   Z_RAMStart       ; Insert your data definition here
var_delay DS.B   2


            ORG    ROMStart
            
_Startup:   CLRA
			CLRA 
           	STA SOPT1 ; disenable watchdog
            LDHX   #RAMEnd+1        ; initialize the stack pointer
            TXS	
  	 		   
main:
			JSR initialconfig
			JSR initialstates
			JSR initLCD
			LDHX #initial_message
			JSR write_message
			
Bucle_Blink:			MOV #200D,var_delay
			JSR delayAx5ms ; delay for 20ms (level voltage desired to LCD)		
			LDA #08H
			JSR send_command
			MOV #100D,var_delay
			JSR delayAx5ms ; delay for 20ms (level voltage desired to LCD)		
			LDA #0CH
			JSR send_command    
			JMP Bucle_Blink
			
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
			RTS 
			
;******************************************Subroutine for initilize the LCD
initLCD:
		 	MOV #8,var_delay
			JSR delayAx5ms ; delay for 20ms (level voltage desired to LCD)
			LDHX #config_LCD ;	Load initial direction LCD		
bucle_initLCD:	LDA ,X ; Deferencing pointer
			CBEQA #0H,fin_initLCD			
			JSR send_command             
			AIX #1 ; Incrementing pointer
			BRA bucle_initLCD ; Repet until end
fin_initLCD:	RTS
			
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
			
;********************************************Table to be displayed in the LCD

config_LCD:	DC.B cmd_8bitmode,cmd_displayON,cmd_clear,090h,0H 

initial_message: DC.B '  BIENVENIDO ',1,0

 			
            ORG Vreset
			DC.W  _Startup			; Reset
