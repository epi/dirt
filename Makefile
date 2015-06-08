CROSS=/opt/arm-none-eabi/bin/arm-none-eabi-

AS=$(CROSS)as
LD=$(CROSS)ld
DC=$(CROSS)gdc
CC=$(CROSS)gcc
QEMU=/opt/qemu/bin/qemu-system-arm

libgcc_a := $(shell $(CC) -print-libgcc-file-name)

DFLAGS := -Os -g -mcpu=cortex-m3 -mthumb -nophoboslib -frelease -finline -ffunction-sections -fdata-sections -fno-invariants -fmerge-constants -fno-emit-moduleinfo
ASFLAGS := -g -mcpu=cortex-m3 -mthumb
LDFLAGS := -nostdlib --gc-sections

objs := start.o object.o libc.o sh.o main.o libd.o std/format.o std/traits.o std/typetuple.o
asms := $(patsubst %.o,%.S,$(objs))

hello.elf: $(objs) hello.lds
	$(LD) $(objs) $(libgcc_a) -T hello.lds -o $@ $(LDFLAGS)

main.o: object.d __entrypoint.d

.SECONDARY: $(asms)

%.S: %.d
	$(DC) $(DFLAGS) -S -c $< -o $@

%.o: %.S
	$(AS) $(ASFLAGS) $< -o $@

run: hello.elf
	$(QEMU) -machine lm3s6965evb -semihosting-config "target=native" -nographic -kernel $< || stty sane
.PHONY: run

clean:
	rm -f $(objs) $(asms) hello.elf
.PHONY: clean
