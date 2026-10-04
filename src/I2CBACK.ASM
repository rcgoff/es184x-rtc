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

;L.Yadrennikov jun, aug 2025, may, sep 2026

public i2cwr
public i2crd
public i2c_stopreset

port_b           equ 61h
port_c           equ 62h
sda_out_position equ 2
sda_in_position  equ 4
scl_position     equ 3
sda_out_mask     equ 1 SHL sda_out_position
sda_in_mask      equ 1 SHL sda_in_position
scl_mask         equ 1 SHL scl_position

SCL_HI macro             ;raise SCL
       or  al,scl_mask
       out dx,al
       endm

SCL_LO macro             ;fall SCL
       and al,not scl_mask
       out dx,al
       endm

I2C_STOP macro           ;issue stop condition
       call sda_lo
       SCL_HI
       call sda_hi
       endm

I2C_START macro          ;issue start condition
       call sda_lo
       SCL_LO
       endm

_DATA segment at 0h      ;data segment is PSP
       org 0efh
       inversion_mask db ?
_DATA ends

_TEXT segment word public 'CODE'
assume cs:_TEXT,ds:_DATA

i2c_stopreset proc near
;Detect I2C harness (in-to-out connection) presence,
;and force i2c reset after undefined bus and/or device state
;or just generate STOP
;On call:
;   CY clear - detect harness, 9 SCLs, then stop
;   CY set   - Just stop
;On return:
;   CY set - no I2C harness
       push ax
       push cx
       push dx
       mov dx,port_b
       in al,dx
       jc stopgen
                         ;detect I2C harness
       or  al,sda_out_mask       ;SDA=1
       out dx,al
       in al,port_c
       and al,sda_in_mask
       mov ah,al         ;keep 1st SDA read
       in al,dx          ;port_B
       and al,not sda_out_mask   ;SDA=0
       out dx,al
       in al,port_c
       and al,sda_in_mask
       xor ah,al         ;1 if harness exists
       jz no_harness
;at this point,AL=0 means non-inverted harness
       add al,100h-sda_in_mask   ;CY=1 means inverted harness
       sbb al,al                 ;AL=FFh means inverted harness
       and al,sda_out_mask       ;now 'AL XOR databit' ready for inv/noninv
       mov inversion_mask,al     ;keep it in memory
;9 SCL and stop
       in al,dx          ;port_B
       SCL_LO
       call sda_hi
       mov cx,9
scloop:
       SCL_HI
       SCL_LO
       loop scloop
stopgen:
       I2C_STOP
stresexit:
       pop dx
       pop cx
       pop ax
       ret

no_harness:
       stc
       jmp short stresexit
i2c_stopreset endp

sda_set proc near
sda_lo:                          ;fall SDA
       and al,not sda_out_mask   ;prepare 0
       jmp short sda_set_common
;       xor al,inversion_mask     ;if inv_mask=1 then inverted
                                 ;0xor1=1 0xor0=0
;       out dx,al
;       ret

sda_hi:                          ;raise SDA
       or  al,sda_out_mask       ;prepare 1
sda_set_common:
       xor al,inversion_mask     ;if inv_mask=1 then inverted
                                 ;1xor1=0 1xor0=1
       out dx,al
       ret

sda_set endp


i2cwr proc near
;Write AH to I2C device
;On call:
;   AH - byte for output to I2C device
;   CY clear - No start condition
;   CY set   - Start condition
;On return:
;   CY clear - All OK
;   CY set   - No acknowlege bit from device
;   AX destroyed
       push bx
       push cx
       push dx
       pushf
       mov dx,port_b
       in  al,dx
       and al,not (sda_out_mask or scl_mask)
       mov bl,al         ;save previous port with 0s at i2c pins

       mov cl,sda_out_position
       test inversion_mask,sda_out_mask     ;return 1 if inverted
       jz rdy_for_write
       not ah
rdy_for_write:
       rol ah,cl         ;now the highest bit for output to device...
                         ;...is in proper position
       mov cx,8          ;number of bits to output
       popf
       jnc i2cwr_loop
       or  al, (scl_mask or sda_out_mask)
       xor al,inversion_mask    ;set sda_out_mask=0 if invert (1xor1=0)
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
       call sda_hi
       SCL_HI
       in  al,port_c     ;read acknowlege bit
       and al,sda_in_mask
       mov ah,al
       in  al,dx         ;restore port values
       SCL_LO
       neg ah            ;1-ah, set CY if ACK<>0
       pop dx
       pop cx
       pop bx
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
       push cx
       push dx
       pushf
       mov dx,port_b
       in  al,dx
;       and ax,00ffh and not scl_mask
       mov cx,8          ;number of bits to read
       call sda_hi
i2crd_loop:
       SCL_HI
       in  al,port_c     ;read next bit
       and al,sda_in_mask
       neg al            ;set CF=read bit
       rcl ah,1          ;put next bit from CF to AH
       in  al,dx         ;restore port values
       SCL_LO
       loop i2crd_loop
       popf
       jc  rd_finshift   ;skip acknowlege byte if desired
       call sda_lo       ;send acknowlege byte
rd_finshift:
       SCL_HI            ;9th clock in both cases (ack vs no ack)
       SCL_LO
       clc
       pop dx
       pop cx
       ret
i2crd endp

_TEXT ends

end
