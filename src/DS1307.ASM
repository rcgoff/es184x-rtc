;Real-time clock set-reset based on DS1307 chip
;L.Yadrennikov june-september 2025

;DOS functions for time/date
;int 21h, AH=2Ah. get system date.
;int 21h, AH=2Bh. set system date.
;Date format for both functions:
;CX=year (1980-2099)
;DH=month (1-12)
;DL=day (1-31)

;2Ah (get date) returns:
;AL=day of week (0-6, 0-sunday)
;2Bh (set date) returns:
;AL=00 for valid date, FF for invalid.

;int 21h, AH=2Ch. get system time.
;int 21h, AH=2Dh. set system time.
;Time format:
;CH=hours (0-23)
;CL=minutes (0-59)
;DH=seconds (0-59)
;DL=hundredths of seconds (0-99)

;2Ch (get time) returns nothing
;2Dh (set time) returns:
;AL=00 for valid time, FF for invalid.

;time/date is stored in DS1307 as follows:
;The format is BCD
;Byte - Value
;0 Seconds (bit7=1 switches oscillator off)
;1 Minutes
;2 Hours (bit6=1 12hour mode, if so, bit5=1 PM)
;3 Day of week
;4 Day of month
;5 Month
;6 Year
;7 Control word
;8...3F - RAM.

cr       equ   0dh
lf       equ   0ah
cmd      equ   80h     ;command line tail
buf1     equ   0e0h    ;buffer for reading from RTC
buf2     equ   0f0h    ;buffer for comparing
stdout   equ   1
stderr   equ   2

extrn bin_to_bcd:near
extrn bcd_to_bin:near
extrn write_i2c_device:near
extrn read_i2c_device:near
extrn argc:near
extrn argv:near

TO_BUFF macro
;convert AL to bcd and write to buff
       call bin_to_bcd
       stosb
       endm

FROM_BUFF macro
;read buff to AL, convert from bcd to bin
       lodsb
       call bcd_to_bin
       endm

_TEXT segment word public 'CODE'
assume cs:_TEXT
org 100h
select proc near
       mov  bx,offset cmd    ;ES:BX points to command tail
       call argc        ;argument count
       cmp  ax,2
       jne  synterr     ;if not exactly 2 arguments, error and exit
get_cmd:
       mov  ax,1        ;AX - arg.number, ES:BX - command tail as before
       call argv        ;returns addr in ES:BX and length in AX

                        ;convert argument to uppercase
       mov cx,ax
       mov si,bx
ucase1:
       cmp byte ptr [si],'a'
       jb ucase2
       cmp byte ptr [si],'z'
       ja ucase2
       sub byte ptr [si],'a'-'A'
ucase2:
       inc si
       loop ucase1
                        ;compare argument with proper strings
       cld              ;autoincrement
       mov cx,ax        ;setup registers for string compare
       mov di,bx
       mov si,offset todos
       repe cmpsb
       jnz search_cmd_fromdos
       mov ax,offset read_from_rtc
       jmp short call_selected
search_cmd_fromdos:
       mov cx,ax
       mov di,bx
       mov si,offset fromdos
       repe cmpsb
       jnz synterr
       mov ax,offset write_to_rtc
call_selected:
       call ax                ;call selected subroutine, return errorlevel
       or  ah,ah              ;check if it was reading w/errorlevel 0
       jnz cexit              ;then quiet exit
axprn: cbw
       mov bx,ax
       shl bx,1
       mov bx,offset msglist[bx]
       mov cl,[bx]
       xor ch,ch
       mov dx,bx
       inc dx
       mov  bx,stdout
       or  al,al              ;check if errorlevel 0
       jz  printfnoerr        ;if yes, print to stdout
       mov  bx,stderr         ;std error handler
printfnoerr:
       mov  ah,40h            ;write function
       push ax                ;save errorlevel
       int  21h               ;go to ms-dos
       pop ax
cexit: mov ah,4ch
       int 21h                ;quit, return to DOS

synterr:
       mov al,3
       jmp short axprn

;error messages catalog
msglist label word
       dw  oksetmsg
       dw  i2cermsg
       dw  norunmsg
       dw  synterrmsg
select endp

write_to_rtc proc near
;return errorlevel in AX
       cld              ;autoincrement
       mov di,offset buf1
       mov ah,2ch       ;get time
       int 21h
       mov al,dh        ;seconds
       TO_BUFF
       mov al,cl        ;minutes
       TO_BUFF
       mov al,ch        ;hours
       TO_BUFF
       mov ah,2ah       ;get date
       int 21h
       or al,al         ;is week day sunday?
       jnz no_sunday
       mov al,7
no_sunday:
       TO_BUFF
       mov al,dl        ;month day
       TO_BUFF
       mov al,dh        ;month
       TO_BUFF
       mov ax,cx        ;year
       sub ax,2000
       jnc xxi_century
       add al,100
xxi_century:
       TO_BUFF

       mov si,offset buf1
       mov bx,0
       mov cx,7         ;write 7 bytes (00..06)
       mov ah,11010000b ;dev addr-w (ds1307)
       clc
       call write_i2c_device
       jc werr          ;exit with errorlevel 1 if error
       call check_running
       jz norun         ;all digits are unchanged -> clock isn't running
       cmp cx,1         ;if other digits than min and sec are differ,
       ja werr          ;then DS1307 error
                        ;otherwise OK, print msg and normal exit
       xor al,al        ;errorlevel 0
       jmp short wexit
norun: mov al,2
       jmp short wexit
werr:  mov al,1
wexit: xor ah,ah        ;non-quiet mode in all cases
       ret
write_to_rtc endp

read_from_rtc proc near
       cld              ;autoincrement
       mov di,offset buf1
       call read_ds1307
       jc rerr
       call check_running
       jz rnorun
;now let's get data in backward direction
       mov si,offset buf2+6
       FROM_BUFF        ;get year
       cbw
       cmp al,80
       ja xx_century
       add ax,100
xx_century:
       add ax,1900
       mov cx,ax        ;store year
       FROM_BUFF
       mov dh,al        ;store month
       lodsw            ;read day, skip weekday
       call bcd_to_bin
       mov dl,al        ;store day
       mov ah,2bh
       int 21h          ;set date
       or al,al         ;0=valid date
       jnz rerr
       FROM_BUFF
       mov ch,al        ;store hours
       FROM_BUFF
       mov cl,al        ;store minutes
       FROM_BUFF
       cbw
       mov dx,ax        ;store seconds
       mov ah,2dh
       int 21h          ;set time
       or al,al         ;0=valid time
       jnz rerr         ;if not, mark an error
       mov ah,1         ;otherwise mark "Qiet OK exit"
       jmp short rexit
rerr:  mov ax,0001h     ;otherwise exit with errorlevel 1 (rerr)
       jmp short rexit
rnorun:
       mov ax,0002h
rexit: ret
read_from_rtc endp

read_ds1307 proc near
;read 7 bytes from addr 0 (date & time)
;to address given in di
;if error, carry is set
       mov bx,0
       mov cx,7         ;read 7 bytes (00..06)
       mov ah,11010000b ;dev addr-w (ds1307)
       xor al,al        ;don't skip addr wrt
       clc
       call read_i2c_device
       ret
read_ds1307 endp

delay_2sec proc near
;wait for 2 sec to ensure that RTC is running
;2 sec instead of 1 to prevent asyncronity...
;...of PC and RTC seconds' change issues.
;3 cases are possible:
;linear seconds increment
;59->0->1     1-59=-58
;58->59->0    0-58=-58
;so, if we get negative number (check by JC),we should add 60
       mov ah,2ch
       int 21h          ;get time,seconds in dh
       mov bl,dh
dloop: int 21h
       sub dh,bl
       jc add60
dcmp:  cmp dh,2
       jnz dloop
       ret

add60: add dh,60d
       jmp short dcmp
delay_2sec endp

check_running proc near
       call delay_2sec
       mov di,offset buf2
       call read_ds1307
                        ;check if RTC is running, by comparison
       std              ;autodecrement
       mov cx,8         ;setup registers for string compare
       mov di,offset buf2+7
       mov si,offset buf1+7
       repe cmpsb       ;compare from control word downto seconds
       ret
check_running endp

todos    db '/TODOS'
fromdos  db '/FROMDOS'
synterrmsg db synterrmsglen
         db 'Syntax error, usage: DS1307 /todos or DS1307 /fromdos',cr,lf,lf
synterrmsglen = $-synterrmsg-1
oksetmsg db oksetmsglen
         db 'RTC OK',cr,lf,lf
oksetmsglen = $-oksetmsg-1
norunmsg db norunmsglen
         db "RTC isn't running (bad quartz?)",cr,lf,lf
norunmsglen = $-norunmsg-1
i2cermsg db i2cermsglen
         db "RTC: I2C bus error",cr,lf,lf
i2cermsglen = $-i2cermsg-1

_TEXT ends

end select
