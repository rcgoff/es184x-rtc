debug  equ 0    ;1=debug mode (stand-alone program)
com    equ 1    ;1 if com file
;i2c bus routines (Front-end)

;L.Yadrennikov june-july 2025, sep-oct 2026

public write_i2c_device
public read_i2c_device
extrn i2crd:near
extrn i2cwr:near
extrn i2c_stopreset:near

_TEXT segment byte public 'CODE'
assume cs:_TEXT

write_i2c_device proc near
;Write byte array to I2C devices
;(sequental write)
;On call:
;   DS:SI - pointer to location of bytes to write
;   BX - initial address into device
;   CX - number of bytes to write ( >0 )
;   CY clear - send 1-byte address to i2c
;   CY set   - send 2-byte address to i2c
;   AH - I2C device address
;On return:
;   CY clear - All OK
;   CY set   - No acknowlege bit from device
       push dx
       sbb dx,dx         ;dx=CF (0 or FFh)
       clc               ;9 SCL, then stop
       call i2c_stopreset
       jc i2cwrerr
       stc
       call i2cwr        ;send dev addr from AH
       jc i2cwrerr
       inc dx            ;dx=0 if CF on call was 1
       jnz lowraddr      ;equivalent of jnc for CF-on-call
       mov ah,bh         ;internal addr-h
       clc
       call i2cwr
       jc i2cwrerr
lowraddr:
       mov ah,bl         ;internal addr-l
       call i2cwr
       jc i2cwrerr
       cld               ;autoincrement
arraywr_loop:
       lodsb
       mov ah,al
       call i2cwr
       jc i2cwrerr
       loop arraywr_loop
       stc               ;stop condition
       call i2c_stopreset
       clc
i2cwrerr:                ;jump to i2cwrerr alays occurs by jc, so CF=1
       pop dx
       ret
write_i2c_device endp

read_i2c_device proc near
;Read byte array from I2C devices
;(sequental read)
;On call:
;   ES:DI - pointer to location of read bytes
;   BX - initial address into device
;   CX - number of bytes to read ( >0 )
;   CY clear - send 1-byte address to i2c
;   CY set   - send 2-byte address to i2c
;   AH - I2C device address
;   AL<>0 - skip addres writing
;On return:
;   CY clear - All OK
;   CY set   - No acknowlege bit from device
;   AX,BP destroyed
       push dx
       mov dx,ax
       sbb bp,bp         ;BP=Carry flag  (0 or FFh)
       clc
       call i2c_stopreset
       jc i2crderr
       or al,al
       jnz read
       stc
       call i2cwr        ;send dev addr from AH
       jc i2crderr
       inc bp            ;now BP=0 if CF was 1
       jnz lowrdaddr     ;equals jnc by saved CF
       mov ah,bh         ;internal addr-h
       clc
       call i2cwr
       jc i2crderr
lowrdaddr:
       mov ah,bl         ;internal addr-l
       call i2cwr
       jc i2crderr
read:
       mov ax,dx         ;recall i2c device addr
       inc ah            ;form 'read' command
       stc
       call i2cwr
       jc i2crderr
       cld               ;autoincrement
       dec cx
       jz last_read
arrayrd_loop:
       call i2crd
       mov al,ah
       stosb
       loop arrayrd_loop
last_read:
       stc
       call i2crd
       mov al,ah
       stosb
       stc               ;stop condition
       call i2c_stopreset
       clc
i2crderr:                ;jump to i2crderr alays occurs by jc, so CF=1
       pop dx
       ret
read_i2c_device endp

if debug
;=========for debug-test
i2c_test proc far
       jmp short wrtest
       push cs
       pop es
       mov di,offset rtc_buff
       xor bx,bx
       mov cx,8         ;read 8 bytes (00..07)
       mov ah,11010000b ;dev addr-w (ds1307)
       clc
       call read_i2c_device
;24Cxx        mov ah,10100000b ;dev addr-w
;de1307       mov ah,11010000b ;dev addr-w
texit: mov ax,4c00h
       int 21h

wrtest:
       push cs
       pop ds
       mov si,offset wr_test_buff
       xor bx,bx
       mov cx,7         ;write 7 bytes (00..06)
       mov ah,11010000b ;dev addr-w (ds1307)
       clc
       call write_i2c_device
       jmp short texit

i2c_test endp

rtc_buff:
       db  8 dup (?)

wr_test_buff:
       db 00
       db 01
       db 02
       db 03
       db 04
       db 05
       db 06
;=========end of for debug-test
endif

_TEXT ends

ife com
STACK segment para stack 'STACK'
if debug
         db   64 dup (?)
endif
STACK ends
endif

if debug
end i2c_test
endif

end
