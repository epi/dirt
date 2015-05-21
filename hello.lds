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
		_etext = . ;
	} >flash

	.data : AT ( ADDR (.text) + SIZEOF (.text) ) {
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
		*(.ARM.exidx*)
		*(.ARM.extab*)
	}
}
