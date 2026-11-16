.dseg ; turn on data memory
.org 0x100
flag: .byte 1 ; reserev 1 byte in ram
    
.cseg ; swithcing back to program emmory     
.org 0x1000
.include "printlib.inc"
    ; define variables
    .def MM = r18
    .def SS = r19
    .def DD= r20
    .def RUNNING = r24 ; flag it equals to 1 when runnign 0 when its stopped
 
.org 0 
    jmp start
.org 0x16
    jmp interrupt ; jumps here when timer starts
    
    
.org 0x100 
start:
    call init_disp
    call init_button ; initialize analog to digital for buttons
    call init_int ; timer interrupt
  
    ldi MM, 0
    ldi SS, 0
    ldi DD, 0
    ldi RUNNING, 0 ; start with not running state
    
    ldi r16, 0
    sts flag, r16 
;-------------------------------------------------------------------------------
    main:
	lds r16, flag  ; wait for timer
	cpi r16, 0
	breq main ; basically spin here untill flag is set
	
	ldi r16, 0
	sts flag, r16  ; clear flag
	call read_button ; result in r16 
	
	; 0 = none
	; 1 = right(start)
	; 2 = up(stop)
	; 3 = down ( reset)
	cpi r16, 1
	breq do_start ; jump if equal 
	cpi r16, 2
	breq do_stop
	cpi r16, 3
	breq do_reset
	rjmp run ; make sure if flag changed or nah
	
	do_start:
	    ldi RUNNING, 1
	    rjmp run
	    
	do_stop:
	    ldi RUNNING, 0
	    rjmp run
	    
	do_reset: ; clear eevrything and stop stopwatch
	    ldi RUNNING, 0
	    clr MM
	    clr SS
	    clr DD
	    ldi r16, 0
	    sts flag, r16
	    rjmp display ; refreshing display needs to jump staright in there and sdoesnt interfeare with runnign
	
        run:
	    
	    cpi RUNNING, 1
	    brne display ; not runnign so just dispaly
	    
	    ; for incrementing
	    inc DD
	    cpi DD, 100
	    brne display ; branch if not equal 
	    ; if equal
	    clr DD ; so now DD is 0
	    inc SS
	    cpi SS, 60 ; if its equal to minute
	    brne display ; branch if not euqal
	
	    ;if equal
	    clr SS
	    inc MM
	    cpi MM, 60
	    brne display  
	    clr MM   
	
   ;---------------------------------------------------------------------------- 
   display:
	ldi r25, '0' ; for conversion to ASCII
    ;--------MM-------------
	mov r16, MM
	rcall split_to_dig
	
	mov r16, r21 ; move first dig for printing
	add r16, r25
	ldi r17, 0x00
	call show_char
	
	 mov r16, r22
	 add r16, r25
	 ldi r17, 0x01
	 call show_char
	 
	 ; print ':'
	 
	 ldi r16, ':'
	 ldi r17, 0x02
	 call show_char
    ;--------SS-----------
	mov r16, SS
	rcall split_to_dig
	
	mov r16, r21 ; move first dig for printing
	add r16, r25
	ldi r17, 0x03
	call show_char
	
	mov r16, r22
	add r16, r25
	ldi r17, 0x04
	call show_char
	 
	; print ':' 
	ldi r16, ':'
	ldi r17, 0x05
	call show_char
	
        ;--------DD-----------
	mov r16, DD
	rcall split_to_dig
	
	mov r16, r21 ; move first dig for printing
	add r16, r25
	ldi r17, 0x06
	call show_char
	
	mov r16, r22
	add r16, r25
	ldi r17, 0x07
	call show_char

	rjmp main
;-------------------------------------------------------------------------------
  
    interrupt:         
	; store register and SREG
	push r16
	in r16, SREG ; status register
	push r16

	; set the flag
	ldi r16, 1
	sts flag, r16

	; restore SREG and register
	pop r16
	out SREG, r16 ; get status flags from r16
	pop r16
	reti     
	
;-------------------------------------------------------------------------------
   init_int:
    push r16
    cli ; global interrupt disable
   
    ; clear timer counter
    clr r16
    sts TCNT1H, r16
    sts TCNT1L, r16

    ; interrupt enable when the TCNT1 timer/counter reaches the OCR1A value
    ldi r16, (1<<OCIE1A)
    sts TIMSK1, r16

   
    ldi r16, (1<<WGM12) | (0b101<<CS10)
    sts TCCR1B, r16

    ldi r16, 0
    sts OCR1AH, r16
    ldi r16, 155
    sts OCR1AL, r16

    ; disable interrupt from buttons
    clr r16
    out EIMSK, r16

    sei; global interrupt enable
    pop r16
    ret
	
;-------------------------------------------------------------------------------
   init_button:
	push r16
	; enable AD converter and set pre-divider
	; (set the ADEN bit in memory at address ADCSRA without affecting the other bits) 1
	lds r16, ADCSRA
	ori r16, (1<<ADEN) | (0b010<<ADPS0)
	sts ADCSRA, r16

	; set reference voltage (0b01<<REFS0)
	; set output alignment to the left (1<<ADLAR) 
	ldi r16, (0b01<<REFS0) | (1<<ADLAR)
	sts ADMUX, r16

	pop r16
	ret
	
;-------------------------------------------------------------------------------
    read_button:
	;0 = no button
	;1 = RIGHT (start)
	;2 = UP (stop)
	;3 = DOWN (reset)
	;4 = LEFT
	;5 = SELECT
	push r17 ; preserve it
	
	; we need to turn on ADC
	lds r17, ADCSRA  ; load ADC control register into r17
	ori r17, (1<<ADSC) ; turn on the ADSC bit to satrt conversion
	sts ADCSRA, r17 ; load back
	
    wait_adc: 
	lds r17, ADCSRA     ; load ADC control register again
	sbrc r17, ADSC       ; skip next line if its cleared
	rjmp wait_adc        
	
	lds r17, ADCH ; top 8 bits
	; but we need only top 4 
	swap r17
	andi r17, 0x0F 
	
	; figuring out which button to return
	ldi r16, 0 ; asusme nothing is pressed
	cpi r17, 0x0f
	breq rb_done; if equal go to done
	
	cpi r17, 0x00 ; is it start?
	brne not_right
	ldi r16, 1
	rjmp rb_done
	
    not_right:
	cpi r17, 0x01 ; is it UP?
	brne not_up
	ldi r16, 2
	rjmp rb_done
    not_up:
	cpi r17, 0x03 ; is it down?
	brne not_down
	ldi r16, 3
	rjmp rb_done 
	
    not_down:
	cpi r17, 0x06 ; is it left?
	brne not_left
	ldi r16, 4
	rjmp rb_done
    not_left:
	cpi r17, 0x09 ; select
	ldi r16, 5

	; if its not this either r16 = 5 does ntohing so tis fine
    rb_done:

	pop r17
	ret
	
;-------------------------------------------------------------------------------	
    split_to_dig: ; this helps us split digits into 2 registers

	clr r21
	mov r22, r16
	
    split_loop:
	cpi r22, 10
	brlo done; if its lower than 10 the whole digit done
	; if not
	subi r22, 10
	inc r21
	rjmp split_loop 
	; so this loops untill we reach base case and it goes to done
    done:
	ret; jump abck and continue where we left off
  
    
end: jmp end      
