include dump.inc

assume cs:_TEXT
_TEXT segment word public 'CODE'

public	argc
argc   proc    near
;command line argument count
;on call, ES:BX	points to command line
;on return, AX = arguments count

       push bx
       push cx
       mov  ax,1      ;reset arguments count

argc1: mov  cx,-1     ;set flag=external argument (CX=0	internal, FF-ext)

argc2: inc  bx	      ;point to	the next symbol
       cmp  byte ptr es:[bx],cr	;why not a line	command?????
       je   argc3     ;stop if it's the	CR code
       cmp  byte ptr es:[bx],blank
       je   argc1     ;external	argument if SPACEBAR code
       cmp  byte ptr es:[bx],tab
       je   argc1     ;external	argument if TAB

		      ;processing if not (SPACEBAR or TAB)
       jcxz argc2     ;jump back if it's an internal argument

       inc  ax	      ;inc if argument not found
       not  cx	      ;set flag	to 'internal argument'...
       jmp  argc2     ;...and proceed the next symbol

argc3: pop  cx
       pop  bx	      ;restore used registers
       ret	      ;return AX=arguments count

argc   endp

public argv
argv	proc	near
			;get address and length of command line attributes
			;on call, ES:BX = command line
			;	  AX = argument number
			;on return, ES:BX = address
			;	    AX = length
	push	cx
	push	di
	or	ax,ax	;is is 0th argument?
	jz	argv8	;yes - go to geting program name
	xor	ah,ah	;arg counter setup

argv1:	mov	cx,-1	;set flag to 'outside the argument'
argv2:	inc	bx	;next cmdline symbol
	cmp	byte ptr es:[bx],cr
	je	argv7	;termnate if cr found
	cmp	byte ptr es:[bx],blank
	je	argv1	;set to outside the argument if space
	cmp	byte ptr es:[bx],tab
	je	argv1	;set to outside the argument if tab

			;processing all other symbols
	jcxz	argv2	;continue scan if inside the argument
	inc	ah	;otherwise update argument count
	cmp	ah,al	;is it desirable argument?
	je	argv4	;yes - count its length
	not	cx	;no - set flag to 'inside argument'...
	jmp	argv2	;...and continue scan

argv4:			;determine argument length
	mov	ax,bx	;save start address
argv5:	inc	bx	;next symbol
	cmp	byte ptr es:[bx],cr
	je	argv6	;end reached if we encounter with cr...
	cmp	byte ptr es:[bx],blank
	je	argv6	;...or space...
	cmp	byte ptr es:[bx],tab
	jne	argv5	;...or tab, else - continue search

argv6:	xchg	bx,ax	;set ES:BX to the beginning of arg
	sub	ax,bx	;and AX=length of arg
	jmp	argvx	;common exit

argv7:	xor	ax,ax	;AX=0 if argument not found
	jmp	argvx	;common exit

argv8:			;special case if argument=0 on call
	mov	ax,3000h;is it dos v3 or higher?
	int	21h	;(al will be 0 if dos v1)
	cmp	al,3
	jb	argv7	;exit w AX=0 if dos <3.0
	mov	es,es:[2ch]	;get environment from PSP
	xor	di,di
	xor	al,al
	cld
argv9:	repne scasb	;find prog.name as first '00' after all env. variables
	scasb		;should be TWO zeroes (no scasw as can be odd addr)
	jne	argv9	;continue loop if only one zero
	add	di,2	;skip word count
	mov	bx,di	;save program name address
	mov	cx,-1	;now determine progam name length...
	repne scasb	;...by searcing the next zero byte
	not	cx	;get lengtn (rep counts downwards)
	dec	cx
	mov	ax,cx	;return length in ax

argvx:			;common exit
	pop	di
	pop	cx
	ret

argv	endp
_TEXT ends

end
