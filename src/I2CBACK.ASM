;invert equ 1    ;1 if we need to invert SDA output (OC used)
;--changed for MASM 4.0 from IF INVERT to IFDEF INVERT
;--so, you should just un-comment the 1st line if you want to
;  enable inversion with MASM 3
;i2c bus routines
;i2c device is connected to 8255 as follows:
;8255 port b (61h) bit 2 - SDA out
;8255 port b (61h) bit 3 - SCL
;8255 port c (62h) bit 4 - SDA in
;2k7 pull-up to SDA

;for 8255 chip, SDA out can be tied directly to I2C device.
;for 82c55 chip, with its strong "1" output current,
;I2C device must be connected via OC gate or just a
;transistor tied to port B bit 2 (and inversion must be used!)

;L.Yadrennikov june, august 2025, may 2026

public i2cwr
public i2crd
public i2c_stopreset

port_b           equ 61h
port_c           equ 62h
sda_out_position equ 2
sda_in_position  equ 4
sda_out_mask     equ 1 SHL sda_out_position
sda_in_mask      equ 1 SHL sda_in_position
scl_mask         equ 00001000b

SCL_HI macro             ;raise SCL
       or  al,scl_mask
       out dx,al
       endm

SCL_LO macro             ;fall SCL
       and al,not scl_mask
       out dx,al
       endm

SDA_HI macro             ;raise SDA
ifdef invert
       and al,not sda_out_mask
else
       or  al,sda_out_mask
endif
       out dx,al
       endm

SDA_LO macro             ;fall SDA
ifdef invert
       or  al,sda_out_mask
else
       and al,not sda_out_mask
endif
       out dx,al
       endm

I2C_STOP macro           ;issue stop condition
       SDA_LO
       SCL_HI
       SDA_HI
       endm

I2C_START macro          ;issue start condition
       SDA_LO
       SCL_LO
       endm

_TEXT segment word public 'CODE'
assume cs:_TEXT

i2c_stopreset proc near
;Force i2c reset after undefined bus and/or device state
;or just generate STOP
;On call:
;   CY clear - 9 SCLs, then stop
;   CY set   - Just stop
;On return:
;   Nothing
       push ax
       push cx
       push dx
       mov dx,port_b
       in al,dx
       jc stopgen
       SCL_LO
       SDA_HI
       mov cx,9
scloop:
       SCL_HI
       SCL_LO
       loop scloop
stopgen:
       I2C_STOP
       pop dx
       pop cx
       pop ax
       ret
i2c_stopreset endp


i2cwr proc near
;Write AH to I2C device
;On call:
;   AH - byte for output to I2C device
;   CY clear - No start condition
;   CY set   - Start condition
;On return:
;   CY clear - All OK
;   CY set   - No acknowlege bit from device
       push ax
       push bx
       push cx
       push dx
       pushf
       mov dx,port_b
       in  al,dx
       and al,not (sda_out_mask or scl_mask)
       mov bl,al         ;save previous port with 0s at i2c pins

       mov cl,sda_out_position
ifdef invert
       not ah
endif
       rol ah,cl         ;now the highest bit for output to device
                         ;is in proper position
       mov cx,8          ;amount of bits to output
       popf
       jnc i2cwr_loop
ifdef invert
       or  al, scl_mask
else
       or  al, (scl_mask or sda_out_mask)
endif
       out dx,al         ;out idle state on i2c
       I2C_START
i2cwr_loop:
       rol ah,1
       mov al,sda_out_mask
       and al,ah         ;select proper bit
       or  al,bl         ;put proper DATA bit
       out dx,al         ;keep SCL low, out DATA
       SCL_HI
       SCL_LO
       loop i2cwr_loop
       or  al,sda_out_mask     ;put SDA pin high regardless of inversion settings
       out dx,al
       SCL_HI
       in  al,port_c     ;read acknowlege bit
       mov ah,al
       in  al,dx         ;restore port values
       SCL_LO
       clc
       and ah,sda_in_mask
       jz  wrexit
       stc               ;error if Ack<>0
wrexit:
       pop dx
       pop cx
       pop bx
       pop ax
       ret
i2cwr endp

i2crd proc near
;Read from I2C device to AH
;On call:
;   CY clear - Generate acknowlege bit
;   CY set   - Don't generate acknowlege bit
;On return:
;   AH - byte from I2C device
;   CY clear
       push bx
       push cx
       push dx
       pushf
       mov dx,port_b
       in  al,dx
ifdef invert
       and ax,00ffh and not scl_mask
else
       and ax,00ffh and not (sda_out_mask or scl_mask)
endif
       mov bl,sda_in_mask
       mov cx,8          ;amount of bits to read
i2crd_loop:
       rol ah,1
       SDA_HI
       SCL_HI
       in  al,port_c     ;read next bit
       and al,bl
       or  ah,al
       in  al,dx         ;restore port values
       SCL_LO
       loop i2crd_loop
       popf
       jc  rd_finshift   ;skip acknowlege byte if desired
       SDA_LO            ;send acknowlege byte
rd_finshift:
       SCL_HI            ;9th clock in both cases (ack vs no ack)
       SCL_LO
       mov cl,sda_in_position
       rol ah,cl         ;now the highest bit from device
                         ;is in proper position
rdexit:
       clc
       pop dx
       pop cx
       pop bx
       ret
i2crd endp

_TEXT ends

end
