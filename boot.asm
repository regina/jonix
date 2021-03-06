; ---------------------------------------------------
; Jonix
;
; boot.asm
;
; Author(s): Jonathan Haigh
; Last edited by: Jonathan Haigh
; ---------------------------------------------------

; NOTE: this code is taken from osdev.org's 'Barebones' tutorial and 'Bran's Kernel
; Development Tutorial' @ http://osdever.net/bkerndev/Docs/. I'm guessing it's free
; code.
[BITS 32]

global loader           ; making entry point visible to linker
global gdt_flush        ; Allows the C code to link to this
global enable_paging
global kmem_stack
; isr_n (0<=n<=31) are also made global, but dynamically, later


extern main
extern gdt_ptr          ; GDT Pointer struct.
extern fault_handler    ; C func that handles faults.
extern irq_handler      ; C func that handles IRQ interrupts
extern kpage_dir        ; The kernel's page directory
extern tss_0            ; Address of TSS for ring 0

STACKSIZE equ 0x4000          ; that's 16k.

; setting up the Multiboot header - see GRUB docs for details
MODULEALIGN equ  1<<0                   ; align loaded modules on page boundaries
MEMINFO     equ  1<<1                   ; provide memory map
FLAGS       equ  MODULEALIGN | MEMINFO  ; this is the Multiboot 'flag' field
MAGIC       equ    0x1BADB002           ; 'magic number' lets bootloader find the header
CHECKSUM    equ -(MAGIC + FLAGS)        ; checksum required

section .text
align 4
MultiBootHeader:
   dd MAGIC
   dd FLAGS
   dd CHECKSUM


loader:
   mov esp, kmem_stack+STACKSIZE      ; set up the stack
   push eax                           ; pass Multiboot magic number
   push ebx                           ; pass Multiboot info structure

   call  main                         ; call kernel proper
               hlt                    ; halt machine should kernel return

; This will set up our new segment registers. We need to do
; something special in order to set CS. We do what is called a
; far jump. A jump that includes a segment as well as an offset.
; This is declared in C as 'extern void gdt_flush();'

gdt_flush:
    lgdt [gdt_ptr]     ; Tell the CPU where the GDT is.

                       ; Load the data segments.

                       ; Segment descriptors have the following form:
                       ; 15 14 13 12 10 11 10 9  8  7  6  5  4  3  2  1  0
                       ; ^--------------------------------------^  ^--^  ^ 
                       ;        offset into GDT                     RPL  TI
                       ;
                       ; Where RPL is the privelege level and TI is the table
                       ; index - 0 -> GDT
                       ;         1 -> LDT
                       ;
                       ; Here we will always have RPL=0 and TI=0, so the segment
                       ; descriptors should just be 2^3*(offset in gdt).

    mov ax, 16         ; Data segment has offset of 2 in the GDT.
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax         ; Stack segment is a type of data segment so uses the
                       ; same GDT entry as the data segments.

                       ; We need to fill in the esp0 (stack pointer) entry 
                       ; of the TSS before we get the CPU to load the TSS.
    mov [tss_0+4], esp ; The esp0 entry in the TSS has an offset of 4 bytes.

    mov ax, 24         ; TSS descriptor has offset 3 in the GDT.

    ltr ax             ; Tell the CPU where the TSS descriptor is.

    jmp 8:flush2       ; Code segment has offset 1 in the GDT. We now do a far jump.
flush2:
    ret                ; Returns back to the C code.

; Loads the IDT defined in 'idtp' into the processor.
; This is declared in C as 'extern void idt_load();'
global idt_load
extern idtp
idt_load:
    lidt [idtp]
    ret

; Set up Interrupt Service Routines for exceptions from the CPU
;
%macro isr_noparams 1  ; Argument is the exception number
    global isr_%{1}
    isr_%{1}:
        cli
        push byte 0         ; push a dummy variable on to the stack
        push byte %1
        jmp isr_common
%endmacro

%macro isr_params 1     ; Argument is the interrupt number
    global isr_%{1}
    isr_%{1}:
        cli
        push byte %1
        jmp isr_common
%endmacro
    
isr_noparams 0
isr_noparams 1
isr_noparams 2
isr_noparams 3
isr_noparams 4
isr_noparams 5
isr_noparams 6
isr_noparams 7
isr_params 8
isr_noparams 9
isr_params 10
isr_params 11
isr_params 12
isr_params 13
isr_params 14
isr_noparams 15
isr_noparams 16
isr_noparams 17
isr_noparams 18
isr_noparams 19
isr_noparams 20
isr_noparams 21
isr_noparams 22
isr_noparams 23
isr_noparams 24
isr_noparams 25
isr_noparams 26
isr_noparams 27
isr_noparams 28
isr_noparams 29
isr_noparams 30
isr_noparams 31

isr_common:
    pusha
    push ds
    push es
    push fs
    push gs
    mov ax, 0x10   ; Load the Kernel Data Segment descriptor!
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov eax, esp   ; Push us the stack
    push eax
    mov eax, fault_handler
    call eax       ; A special call, preserves the 'eip' register
    pop eax
    pop gs
    pop fs
    pop es
    pop ds
    popa
    add esp, 8     ; Cleans up the pushed error code and pushed ISR number
    iret           ; pops 5 things at once: CS, EIP, EFLAGS, SS, and ESP!


%macro irq_noparams 1  ; Argument is the IRQ number
    global irq_%{1}
    irq_%{1}:
        cli
        push byte 0         ; push a dummy variable on to the stack
        push byte %1
        jmp irq_common
%endmacro

irq_noparams 0;
irq_noparams 1;
irq_noparams 2;
irq_noparams 3;
irq_noparams 4;
irq_noparams 5;
irq_noparams 6;
irq_noparams 7;
irq_noparams 8;
irq_noparams 9;
irq_noparams 10;
irq_noparams 11;
irq_noparams 12;
irq_noparams 13;
irq_noparams 14;
irq_noparams 15;

; This is a stub that we have created for IRQ based ISRs. This calls
; 'irq_handler' in our C code. We need to create this in an 'irq.c'
irq_common:
    pusha
    push ds
    push es
    push fs
    push gs
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov eax, esp
    push eax
    mov eax, irq_handler
    call eax
    pop eax
    pop gs
    pop fs
    pop es
    pop ds
    popa
    add esp, 8
    iret

enable_paging:
    ;push eax
    mov eax, [kpage_dir]
    mov cr3, eax
    mov eax, cr0
    or eax, 0x80000000 ; bit 31 is the paging bit
    mov cr0, eax
    ;pop eax
    hlt
    ret

section .bss
align 32
kmem_stack:
   resb STACKSIZE   ; reserve memory for the stack
