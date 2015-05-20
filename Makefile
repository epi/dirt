#CROSS=/opt/arm-gdcproject-linux-gnueabihf/bin/arm-gdcproject-linux-gnueabihf-
CROSS=/opt/arm-none-eabi/bin/arm-none-eabi-

AS=$(CROSS)as
LD=$(CROSS)ld
GDC=$(CROSS)gdc
QEMU=/opt/qemu/bin/qemu-system-arm

DFLAGS := -Os -g -mcpu=cortex-m3 -mthumb -nostdinc -ffunction-sections -fdata-sections -fno-invariants -fmerge-constants -fno-rtti
ASFLAGS := -g -mcpu=cortex-m3 -mthumb
LDFLAGS := -nostdlib --gc-sections

objs := start.o object.o libc.o sh.o main.o libd.o
asms := $(patsubst %.o,%.S,$(objs))

hello.elf: $(objs) hello.lds
	$(LD) $(objs) -T hello.lds -o $@ $(LDFLAGS)

main.o: object.d __entrypoint.d

.SECONDARY: $(asms)

%.S: %.d
	$(GDC) $(DFLAGS) -S -c $< -o $@

%.o: %.S
	$(AS) $(ASFLAGS) $< -o $@

run: hello.elf
	$(QEMU) -machine lm3s6965evb -semihosting-config "target=native" -nographic -kernel $< || stty sane
.PHONY: run

clean:
	rm -f $(objs) $(asms) hello.elf
.PHONY: clean
