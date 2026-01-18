        public  bin_to_bcd
        public  bcd_to_bin
assume cs:_TEXT
_TEXT segment word public 'CODE'

bin_to_bcd      proc    near            ; real time clock sup
;Convert a binary input in AL (less than 63h or 99 decimal)
;into a bcd value in AL.  AH destroyed.
;LY this is from MSINIT.ASM DOS 3.3
        push    cx
        xor     ah, ah
        mov     cl, 10
        div     cl              ;al=high digit bcd, ah=low digit bcd
        mov     cl, 4
        shl     al, cl          ;mov the high digit to high nibble
        or      al, ah
        pop     cx
        ret
bin_to_bcd      endp

bcd_to_bin      proc    near            ; real time clock sup
;
;   Bcd_to_bin converts two bcd nibbles in al (value <= 99.) to
;   a binary representation in al
;   ah is destroyed
;
;LY this if from READCLOC.INC DOS 3.3
        push    cx
        mov     ah,al           ;mjb002 copy bcd number to ah
        and     ax,0f00fh       ;mjb002 clear unwanted nibbles
        mov     ch,al           ;mjb002 save units place
        xchg    ah,al           ;mjb002 10's place to al
        xor     ah,ah           ;mjb002 ah not wanted
        mov     cl,4            ;mjb002 shift count
        shr     ax,cl           ;mjb004 swap nibbles
        mov     cl,10           ;mjb002 convert al to ...
        mul     cl              ;mjb002 ... its binary value
        add     al,ch           ;mjb002 add in units
        pop     cx
        ret                     ;mjb002
bcd_to_bin      endp
_TEXT ends
end
