ARCH := $(shell uname -m)
ifneq ($(filter i386 i486 i586 i686, $(ARCH)),)
ARCH := i386
endif

ifneq ($(filter i386, $(ARCH)),)
ALL_TARGETS   := initrd biostest initrd+modules boot boot-themes rescue root root+rescue root-themes gdb sax2
INSTSYS_PARTS := config rpmlist root common rescue gdb sax2
BOOT_PARTS    := boot/* initrd biostest
endif

ifneq ($(filter x86_64, $(ARCH)),)
ALL_TARGETS   := initrd biostest initrd+modules boot-efi boot boot-themes rescue root root+rescue root-themes gdb sax2
INSTSYS_PARTS := config rpmlist root common rescue gdb sax2
BOOT_PARTS    := boot/* initrd biostest boot-efi
endif

ifneq ($(filter ia64, $(ARCH)),)
ALL_TARGETS   := initrd initrd+modules boot-efi rescue root root+rescue root-themes gdb sax2
INSTSYS_PARTS := config rpmlist root common rescue gdb sax2
BOOT_PARTS    := boot-efi initrd
endif

ifneq ($(filter s390 s390x, $(ARCH)),)
ALL_TARGETS   := initrd initrd+modules rescue root root+rescue root-themes gdb
INSTSYS_PARTS := config rpmlist root common rescue gdb
BOOT_PARTS    := initrd
endif

ifneq ($(filter ppc ppc64, $(ARCH)),)
ALL_TARGETS   := initrd initrd+modules rescue root root+rescue root-themes gdb sax2
INSTSYS_PARTS := config rpmlist root common rescue gdb sax2
endif

THEMES        := openSUSE SLES SLED
DESTDIR       := images/instsys

export ARCH THEMES DESTDIR INSTSYS_PARTS BOOT_PARTS WITH_FLOPPY

.PHONY: all dirs base zeninitrd zenboot zenroot biostest initrd \
	boot boot-efi root rescue root+rescue sax2 gdb clean \
	boot-themes root-themes install install-initrd debuginfo

all: $(ALL_TARGETS)
	@rm images/*.log

install:

dirs:
	@[ -d images ] || mkdir images
	@[ -d tmp ] || mkdir tmp

base: dirs
	@[ -d tmp/base ] || nostrip=1 image=base fs=none bin/mk_image

zeninitrd: base
	initramfs=$${initramfs:-1} YAST_IS_RUNNING=1 theme=Zen filelist=zeninitrd bin/mk_initrd

zenboot: zeninitrd mboot
	theme=Zen initrd=large boot=isolinux memtest=no bin/mk_boot

zenroot: base
	theme=Zen fs=$${fs:-ext2} image=zenroot src=root fs=squashfs bin/mk_image

biostest: base
	libdeps=initrd,biostest image=biostest src=initrd fs=cpio.gz disjunct=initrd bin/mk_image

initrd: base
	libdeps=initrd image=initrd-base.gz tmpdir=initrd src=initrd filelist=initrd fs=cpio.gz bin/mk_image

modules: base
	image=modules-config src=initrd fs=none bin/mk_image
	bin/mlist1
	bin/mlist2
	image=modules src=initrd fs=none bin/mk_image
	mkdir -p images/module-config/$${MOD_CFG:-default}
	ls -I module.config tmp/modules/modules | sed -e 's#.*/##' >images/module-config/$${MOD_CFG:-default}/module.list
	cp tmp/modules/modules/module.config images/module-config/$${MOD_CFG:-default}

initrd+modules: base
	image=modules-config src=initrd fs=none bin/mk_image
	bin/mlist1
	bin/mlist2
	rm -rf tmp/initrd/modules tmp/initrd/lib/modules
	mode=keep,add image=$${image:-initrd} tmpdir=initrd filelist=modules src=initrd fs=cpio.gz bin/mk_image
	mkdir -p images/module-config/$${MOD_CFG:-default}
	ls -I module.config tmp/initrd/modules | sed -e 's#.*/##' >images/module-config/$${MOD_CFG:-default}/module.list
	cp tmp/initrd/modules/module.config images/module-config/$${MOD_CFG:-default}

boot-efi: base
	image=boot-efi src=boot filelist=efi fs=dir bin/mk_image
	ln images/initrd tmp/boot-efi/efi/boot/initrd
	bin/hdimage --size=80000 --chs 0 4 63 --part-ofs 0 --mkfs fat --add-files tmp/boot-efi/* tmp/boot-efi/.p* -- images/boot-efi.img
	rm -rf tmp/boot-efi/efi/boot/initrd images/boot-efi
	mv images/boot-efi.img images/boot-efi

boot: base
	image=boot fs=dir bin/mk_image

root: base
	libdeps=root root_i18n=1 root_gfx=1 perldeps=root image=root bin/mk_image

rescue: base
	libdeps=rescue image=rescue bin/mk_image

root+rescue: base
	image=root+rescue fs=none bin/mk_image
	bin/common_tree --dst tmp/root+rescue tmp/rescue tmp/root
	mode=keep tmpdir=root+rescue/c image=common fs=squashfs bin/mk_image
	mode=keep tmpdir=root+rescue/1 image=rescue fs=squashfs bin/mk_image
	mode=keep tmpdir=root+rescue/2 image=root fs=squashfs bin/mk_image
	cp data/root/config images
	cat data/root/rpmlist tmp/base/yast2-trans-rpm.list >images/rpmlist

sax2: base
	libdeps=root,sax2 perldeps=root,sax2 image=sax2 src=root fs=squashfs disjunct=root bin/mk_image

gdb: base
	libdeps=root,gdb image=gdb src=root fs=squashfs disjunct=root bin/mk_image

boot-themes: base
	for theme in $(THEMES) ; do \
	  image=boot-$$theme src=boot filelist=$$theme fs=dir bin/mk_image ; \
	done

root-themes: base
	for theme in $(THEMES) ; do \
	  image=root-$$theme src=root filelist=$$theme fs=squashfs disjunct=root bin/mk_image ; \
	done

mboot:
	make -C src/mboot

debuginfo:
	./install.debuginfo

clean:
	-@make -C src/mboot clean
	-@make -C src/eltorito clean
	-@rm -rf images tmp
	-@rm -f `find -name '*~'`
	-@rm -rf /tmp/mk_initrd_* /tmp/mk_image_* 
	-@rm -rf data/initrd/gen data/boot/gen data/base/gen data/demo/gen

install:
	-@rm -rf $(DESTDIR)
	@mkdir -p $(DESTDIR)
	./install.$(ARCH)

install-initrd:
	-@rm -rf $(DESTDIR)
	@mkdir -p $(DESTDIR)/default
	cp images/initrd-base.gz $(DESTDIR)
	cp -a images/module-config/* $(DESTDIR)

