CODE_SEG	SEGMENT
    ASSUME	CS:CODE_SEG,DS:CODE_SEG,SS:CODE_SEG
    ORG	100H
    .386

    START:
    jmp begin

    old_1Ch dd ?
    int_2Fh_vector DD ?
    count dw 0
    color db 1
    pointer dw 0
    flag_off    DB  0
    key DB '/off'
    message db "Hello world!"
    mesLen dw $ - message
    attr db 0
    cursorX db 0
    cursorY db 0
    screenX db 0
    screenY db 0
    msg         DB  'already '
    msg1        DB  'installed',13,10,'$'
    msg4        DB  'just '
    msg3        DB  'not '
    msg2        DB  'uninstalled',13,10,'$'
    msg5        DB  "no parametrs",13,10,'$'
    msg6        DB  "wrong parametrs",13,10,'$'
    tick dw 0

    push_all_regs macro
        push	AX
        push	BX
        push	CX
        push	DX
    endm

    pop_all_regs macro
        pop		DX
        pop		CX
        pop		BX
        pop		AX
    endm

    Print_Word_dec	macro	src
        local	l1, l2, ex
        push DS
        push CS
        pop DS
        
        push_all_regs

            mov		AX,	src					;	Выводимое число в регисте EAX
            push		-1					;	Сохраним признак конца числа
            mov		cx,	10					;	Делим на 10
        l1:	
            xor		dx,	dx					;	Очистим регистр dx 
            div		cx						;	Делим 
            push		DX						;	Сохраним цифру
            or 			AX,	AX				;	Остался 0? (это оптимальнее, чем  cmp	ax,	0 )
            jne		l1						;	нет -> продолжим
            mov		ah,	2h
        l2:	
            pop		DX						;	Восстановим цифру
            cmp		dx,	-1					;	Дошли до конца -> выход {оптимальнее: or EDX,dx jl ex}
            je			ex
            add		dl,	'0'					;	Преобразуем число в цифру
            int		21h						;	Выведем цифру на экран
            jmp	l2							;	И продолжим
        ex:
        
        pop_all_regs
        pop DS
    endm
    
    print_letter	macro	letter
        push	AX
        push	DX
        mov	DL, letter
        mov	AH,	02
        int	21h
        pop	DX
        pop	AX
    endm

    print_mes	macro	message
        local	msg, nxt
        push	AX
        push	DX
        mov	DX, offset msg
        mov	AH,	09h
        int	21h
        pop	DX
        pop	AX
        jmp nxt
        msg	DB message,'$'
        nxt:
	endm

    print PROC NEAR
        MOV AH, 09H
        INT 21H
        RET
    print ENDP

    new_1Ch proc far
        ;;; set DS on CS
            push DS
            push CS
            pop DS
        ;;;

        inc count
        mov cx, tick
        cmp count, cx
        jne nig

        ;;; draw a gray rectangle
            mov screenX, 10
            mov screenY, 30

            mov ah, 06h
            mov al, 0
            mov bh, 7Fh
            mov ch, screenX
            mov cl, screenY
            mov dh, 10 + 2
            mov dl, 30 + 13
            int 10h
        ;;;

        ;;; change the attribute of symbols
            mov al, attr
            and al, 7Fh
            cbw
            mov bl, 15
            div bl
            mov attr, ah
            inc attr
        ;;;

        ;;; draw "Hello world!" through videobuffuer to avoid cursor issues
            mov ax, 0B800h
            mov es, ax
            mov di, 2*80*11 + 2*31
            lea bx, message
            mov cx, mesLen
            printCycle:
                mov al, [bx]
                mov ah, 70h
                add ah, attr

                mov es:[di], ax

                inc bx
                add di, 2
            loop printCycle
        ;;;

        mov count, 0

        nig:
        pop DS
        jmp dword ptr cs:[old_1Ch]
    endp

    int_2Fh proc far
        cmp ah, 0c7h
        jne Pass_2Fh
        cmp al, 00h
        je inst
        cmp al, 01h
        je unins
        jmp short Pass_2Fh

        inst:
        mov al, 0ffh
        iret

        Pass_2Fh:
        jmp dword ptr cs:[int_2Fh_vector]


        unins:
        push    BX
        push    CX
        push    DX
        push    ES

        mov     CX,CS  ; move into CX <- CS

        ;;; get int 1Ch
            mov     AX, 351Ch
            int     21h
        ;;;

        ;;; is new handler of 1Ch from the previos CS?  // DX -> ES, in CX - CS
            mov     DX,ES
            cmp     CX,DX
            jne     Not_remove
        ;;;
    
        ;;; is new handler of 1Ch is our new_1Ch procedure?
            cmp     BX, offset CS:new_1Ch
            jne     Not_remove
        ;;;

        ;;; get int 2Fh
            mov     AX,352Fh
            int     21h
        ;;;
    
        ;;; is new handler of 2Fh from the previous CS?
            mov     DX,ES
            cmp     CX,DX
            jne     Not_remove
        ;;;

        ;;; is new handler of 2Fh is our new int_2Fh procedure?
            cmp     BX, offset CS:int_2Fh
            jne     Not_remove
        ;;;
        
        push    DS
        ;;; load in DX old handler of 1Ch
            lds     DX, CS:old_1Ch
            mov     AX,251Ch
            int     21h
        ;;;
    
        ;;; load in DX old handler of 2Fh
            lds     DX, CS:int_2Fh_vector
            mov     AX,252Fh
            int     21h
        ;;;
        pop     DS
    
        ;;; clear the environment (2Ch in psp)
            mov     ES,CS:2Ch
            mov     AH, 49h
            int     21h
        ;;;
    
        ;;; clear the psp itself
            push CS
            pop ES
            mov     AH, 49h
            int     21h
        ;;;
    

        ;;; set AL as 0F - uninstalled program
            mov     AL,0Fh
        ;;;

        jmp     short pop_ret
    Not_remove:
        mov     AL,0F0h  ; set AL as F0 - no uninstallation
    pop_ret:
        ;;; pop all register that were used
            pop     ES
            pop     DX
            pop     CX
            pop     BX
        ;;;

        iret
    int_2Fh endp

    begin:
        mov CL, ES:80h  ; length of PSP
        cmp CL, 0  ; if length == 0 -> no attributes
        je no_attributes

        ;;; skip spaces before parametrs
            xor CH,CH
            cld
            mov DI, 81h
            mov AL, ' '
            repe    scasb
            dec DI
        ;;;

        ;;; check whether the first symbol of psp is a digit between 1-9
            mov al, [di]
            cmp al, '/'
            je continue
            cmp al, '1'
            jl wrong_parametrs
            cmp al, '9'
            jg wrong_parametrs
        ;;;

        xor ax, ax
        ;;; calculate a tick
            calcul:
                mov al, [di]
                cmp al, 0Dh
                je div_by_ten
                sub al, 30h
                cbw

                add tick, ax
                
                mov ax, tick
                mov bx, 10
                mul bx
                mov tick, ax

                inc di
                jmp calcul
            
            div_by_ten:
                mov ax, tick
                mov bx, 10
                div bx

            mov tick, ax
            jmp check_install
        ;;;

        continue:
        ;;; is psp is truly "/off"?
            mov SI,offset key
            mov CX, 4
            repe    cmpsb
        ;;;

        jne check_install  ; if ZF == 0, then skip incrementaion of flag_off
        inc flag_off  ; if ZF == 1, set the flag to unistall the interrupt

        check_install:
            ;;; run int 2Fh to check C7 code
                mov AX, 0C700h
                int 2Fh
            ;;;

            ;;; if AL == FF, then program is already installed
                cmp AL, 0FFh
                je  already_ins
            ;;;

            ;;; if "/off", but program is not installed
                cmp flag_off,1
                je  xm_stranno
            ;;; strange things...

            ;;; get int 2Fh
                mov AX,352Fh
                int 21h
            ;;;

            ;;; save old int 2Fh 
                mov word ptr int_2Fh_vector, BX
                mov word ptr int_2Fh_vector + 2, ES
            ;;;

            ;;; load new int 2Fh
                mov DX,offset int_2Fh
                mov AX,252Fh
                int 21h
            ;;;

            
            ;;; get int 1Ch
                mov AX,351Ch
                int 21h
            ;;;

            ;;; save old int 1Ch
                mov word ptr old_1Ch,BX
                mov word ptr old_1Ch+2,ES
            ;;;

            ;;; load new int 1Ch
                mov DX,offset new_1Ch
                mov AX,251Ch
                int 21h
            ;;;
	
            ;;; successful instalation
                mov DX,offset msg1
                call    print
            ;;;

        ;;; make it resident
            mov DX,offset   begin
            int 27h
        ;;;
    
;=========================Show errors===========================
    already_ins:
        cmp flag_off,1
        je  uninstall
        lea DX,msg
        call    print
    int 20h

    uninstall:
        mov AX,0C701h
        int 2Fh
        cmp AL,0F0h
        je  not_sucsess
        cmp AL,0Fh
        jne not_sucsess
        mov DX,offset msg2
        call    print
    int 20h

    not_sucsess:
        mov DX,offset msg3
        call    print
    int 20h
        
    xm_stranno:
        mov DX,offset msg4
        call    print
    int 20h

    no_attributes:
        mov dx, offset msg5
        call print
    int 20h

    wrong_parametrs:
        mov dx, offset msg6
        call print
    int 20h
;==============================================================

CODE_SEG ENDS
    end START