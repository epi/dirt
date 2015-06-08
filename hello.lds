MEMORY
{
	flash(rx) : ORIGIN = 0, LENGTH = 256K
	sram(!rx) : ORIGIN = 0x20000000, LENGTH = 128K
}

SECTIONS
{
	. = 0;
	.text : SUBALIGN(4) {
		LONG(0x20007fff)
		LONG(resetISR + 1)
		__init_array_start = .;
		KEEP(*(.init_array))
		__init_array_end = .;
		KEEP(start.o(.text*))
		*(.text)
		*(.text*)
		*(.rodata)
		*(.rodata*)
		*(.data*ModuleInfo*)
	} >flash

  .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >flash
   PROVIDE_HIDDEN (__exidx_start = .);
  .ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } >flash
   PROVIDE_HIDDEN (__exidx_end = .);
  .eh_frame_hdr : { *(.eh_frame_hdr) } >flash
  .eh_frame       : ONLY_IF_RO { KEEP (*(.eh_frame)) } >flash
		_etext = . ;

	.data : AT ( _etext ) {
		_data = .;
		*(.data)
		*(.data*)
		_edata = .;
	} >sram
	.bss : {
		_bstart = .;
		*(.bss)
		*(.bss*)
		*(COMMON)
		_bend = .;
	} >sram
	/DISCARD/ : {
	}
}
