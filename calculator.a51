#define LCD_CMD_5x8_MODE 0x38
#define LCD_CMD_CURSOR_BLINK_OFF 0x0E
#define LCD_CMD_CURSOR_BEGIN_AT_LINE1 0x80
#define LCD_CMD_CLEAR_SCREEN 0x01
#define LCD_INCREMENT_CURSOR 0x06
#define LCD_CURSOR_BEGIN_AT_LINE2 0xC0
#define LCD_DECREMENT_CURSOR 0x04

org 0x0000
sjmp start
start:
;Initialize stack pointer
mov SP,#0x80
;Select bank 0 registers
clr RS0
clr RS1

mov P1,#0x00
mov P2,#0x00

mov R5,#LCD_CMD_5x8_MODE
acall LCD_SEND_COMMAND

mov R5,#LCD_CMD_CURSOR_BLINK_OFF
acall LCD_SEND_COMMAND

mov R5,#LCD_CMD_CLEAR_SCREEN
acall LCD_SEND_COMMAND

calcloop:
mov DPTR,#prompt1
acall LCD_PRINT_STRING
mov R5,#LCD_CURSOR_BEGIN_AT_LINE2
acall LCD_SEND_COMMAND
acall READ_NUMBER
mov A,R2
mov R0,A

mov R5,#LCD_CMD_CLEAR_SCREEN
acall LCD_SEND_COMMAND
mov DPTR,#prompt2
acall LCD_PRINT_STRING
mov R5,#LCD_CURSOR_BEGIN_AT_LINE2
acall LCD_SEND_COMMAND
acall READ_NUMBER
mov A,R2
mov R1,A

mov R5,#LCD_CMD_CLEAR_SCREEN       ;Backspace clears the entire screen
acall LCD_SEND_COMMAND
mov DPTR,#opmsg
acall LCD_PRINT_STRING
mov R5,#LCD_CURSOR_BEGIN_AT_LINE2
acall LCD_SEND_COMMAND
acall READOP

acall DO_CALCULATIONS
acall SHOW_RESULT

wait_for_clear:
acall GET_CHAR
cjne A,#0x7f,wait_for_clear

acall LCD_PRINT_CHAR
sjmp calcloop

;.................Helper Functions................................

DELAY:
mov R7,#0xF0
outer:
	mov R6,#0xFF
	inner: djnz R6,inner
	djnz R7,outer
ret

LCD_SEND_COMMAND:      ;R5 contains the command to be sent to the LCD
	mov P1,R5
	clr P2.4
	clr P2.5
	setb P2.6
	acall DELAY
	clr P2.6
	;mov P1,#0
ret

LCD_PRINT_CHAR: ;Accumulator has data to write
	cjne A,#0x7f,not_clr
	mov R5,#LCD_CMD_CLEAR_SCREEN       ;Backspace clears the entire screen
	acall LCD_SEND_COMMAND
	ret
	not_clr:
	mov P1,A
	setb P2.4
	clr P2.5
	setb P2.6
	acall DELAY
	clr P2.6
	mov R5,#LCD_INCREMENT_CURSOR
	acall LCD_SEND_COMMAND
	;mov P1,#0
ret

LCD_PRINT_STRING:    ;DPTR must point to the beginning of the string
	clr A
	movc A,@ A+DPTR
	jnz printloop
	sjmp done
	printloop:
		acall LCD_PRINT_CHAR
		inc DPTR
	sjmp LCD_PRINT_STRING
done:ret

KEYPAD_GET_KEY_PRESSED:        ;Character read is in the accumulator A
	mov A,P3
	cjne A,#0xFF,key_press_true
	ret
	key_press_true:
	push 0x03
	push 0x02
	mov DPTR,#char_table
	anl A,#0x0F  ;Mask out the remaining bits
	mov 0x03,A     ;Save to R3 register
	;Three statements implement a right shift by 2
	
	rr A    
	rr A
	anl A,#0x0F
	
	dec A  ;Decrement A
	xch A,0x03  
	anl A,#0x01
	cjne A,#0,process_row
	mov A,0x03
	orl A,#0x01
	mov 0x03,A
	
	process_row:
	setb P2.0
	mov A,P3
	cjne A,#0xFF,i1
	sjmp row_s_obtained
	i1: setb P2.1
	mov A,P3
	cjne A,#0xFF,i2
	sjmp row_s_obtained
	i2: setb P2.2
	mov A,P3
	cjne A,#0xFF,i3
	sjmp row_s_obtained
	i3: setb P2.3
	
	row_s_obtained:
	mov A,P2
	mov 0x02,#0xFF
	r_loop:
		rr A
		anl A,#0x0F
		inc 0x02
	jnz r_loop
	
	mov A,0x02
	rl A
	rl A
	add A,0x03
	movc A,@ A+DPTR
	mov P2,#0
	pop 0x02
	pop 0x03
ret

GET_CHAR:    ;Character entered from keypad is in accumulator(A)
	acall KEYPAD_GET_KEY_PRESSED
	cjne A,#0xFF,gotchar
sjmp GET_CHAR
gotchar:
ret

READ_NUMBER:                     ;Number is read in R2 register
	mov R2,#0
	acall GET_CHAR
	cjne A,#0x3D,read_more
	sjmp READ_NUMBER
	read_more:
		acall LCD_PRINT_CHAR
		add A,#0xD0
		xch A,R2
		mov B,#10
		mul AB
		add A,R2
		mov R2,A
		acall GET_CHAR
	cjne A,#0x3D,read_more
ret

READOP:   ;R2 has operation
	acall GET_CHAR
	cjne A,#0x3D,opread
sjmp READOP
opread:
acall LCD_PRINT_CHAR
mov R2,A
ret

DO_CALCULATIONS:  ;R3 = result(R4 has remainder when division is done),R0 has v1 and R1 has V2

cjne R2,#43,ca1
mov A,R0
add A,R1
mov DPTR,#sum
sjmp calcdone
ca1:cjne R2,#45,ca2
mov A,R0
clr c
subb A,R1
mov DPTR,#diff
sjmp calcdone
ca2:cjne R2,#42,ca3
mov A,R0
mov B,R1
mul AB
mov DPTR,#product
sjmp calcdone
ca3:
mov A,R0
mov B,R1
div AB
mov R4,B
mov DPTR,#quotient
calcdone:
mov R3,A
ret


EXTRACT_DIGITS:   ;A contains the number whose digits are to be taken
mov 0x21,#0
mov R0,#0x21
startext:
	jnz extractdig
	sjmp digdone
extractdig:
	mov B,#10
	div AB
	mov @R0,B
	inc R0
	
sjmp startext
digdone:
dec R0
ret

PRINT_DIGITS:
cjne R0,#0x20,strtprint 
sjmp printdone
strtprint:
	mov A,@R0
	add A,#0x30
	acall LCD_PRINT_CHAR
	dec R0
sjmp PRINT_DIGITS
printdone:
mov A,#0x20
acall LCD_PRINT_CHAR
ret

SHOW_RESULT:
mov R5,#LCD_CMD_CLEAR_SCREEN
acall LCD_SEND_COMMAND
acall LCD_PRINT_STRING
mov R5,#LCD_CURSOR_BEGIN_AT_LINE2
acall LCD_SEND_COMMAND

cjne R2,#43,bca1
mov A,R3
acall EXTRACT_DIGITS
acall PRINT_DIGITS
sjmp resdone
bca1:cjne R2,#45,bca2
mov A,R3
acall EXTRACT_DIGITS
acall PRINT_DIGITS
sjmp resdone
bca2:cjne R2,#42,bca3
mov A,R3
acall EXTRACT_DIGITS
acall PRINT_DIGITS
sjmp resdone
bca3:
mov A,R3
acall EXTRACT_DIGITS
acall PRINT_DIGITS
mov A,R4
acall EXTRACT_DIGITS
acall PRINT_DIGITS
resdone:
ret


;---------------------------------------------------------------------------------
prompt1: db 'Value 1:',0
prompt2: db 'Value 2:',0
opmsg: db 'Operation:',0
sum: db 'Sum:',0
diff: db 'Diff:',0
product: db 'Product:',0
quotient: db 'Q R',0 	
char_table: db '789/456*123-',0x7f,'0=+',0
END