# Modify the Makefile to point to Linux build tree.
DIST ?= $(shell uname -r)
KDIR:=/lib/modules/$(DIST)/build/
CDIR:=/usr/src/linux-source-2.6.35/scripts/
SOURCE:=$(shell pwd)
DRV_NAME:=dnvme
FLAG=-DDEBUG
EXTRA_CFLAGS+=$(FLAG) -I$(PWD)/


SOURCES := \
	dnvme_reg.c \
	sysdnvme.c \
	dnvme_ioctls.c 

#
# RPM build parameters
#
RPMBASE=$(DRV_NAME)
MAJOR=$(shell awk 'FNR==5' $(PWD)/version.h)
MINOR=$(shell awk 'FNR==8' $(PWD)/version.h)
SOFTREV=$(MAJOR).$(MINOR)
RPMFILE=$(RPMBASE)-$(SOFTREV)
RPMCOMPILEDIR=$(PWD)/rpmbuild
RPMSRCFILE=$(PWD)/$(RPMFILE)
RPMSPECFILE=$(RPMBASE).spec
SRCDIR?=./src

obj-m := dnvme.o
dnvme-objs += sysdnvme.o dnvme_ioctls.o dnvme_reg.o

all:
	make -C $(KDIR) M=$(PWD) modules

rpm: rpmzipsrc rpmbuild

clean:
	make -C $(KDIR) M=$(PWD) clean
	rm -f doxygen.log
	rm -rf $(SRCDIR)
	rm -rf $(RPMFILE)
	rm -rf $(RPMCOMPILEDIR)
	rm -rf $(RPMSRCFILE)
	rm -f $(RPMSRCFILE).tar*

clobber: clean
	rm -rf doc
	rm -f $(DRV_NAME)

doc:
	doxygen doxygen.conf > doxygen.log

# Specify a custom source c:ompile dir: "make src SRCDIR=../compile/dir"
# If the specified dir could cause recursive copies, then specify w/o './'
# "make src SRCDIR=src" will copy all except "src" dir.
src:
	rm -rf $(SRCDIR)
	mkdir -p $(SRCDIR)
	(git archive HEAD) | tar xf - -C $(SRCDIR)

install:
	# typically one invokes this as "sudo make install"
	mkdir -p $(DESTDIR)/lib/modules/$(DIST)
	install -p $(DRV_NAME).ko $(DESTDIR)/lib/modules/$(DIST)
	install -p etc/55-$(RPMBASE).rules $(DESTDIR)/etc/udev/rules.d
ifeq '$(DESTDIR)' ''
	# DESTDIR only defined when installing to generate an RPM, i.e. psuedo
	# install thus don't update /lib/modules/xxx/modules.dep file
	/sbin/depmod -a
endif

rpmzipsrc: SRCDIR:=$(RPMFILE)
rpmzipsrc: clobber src
	rm -f $(RPMSRCFILE).tar*
	tar cvf $(RPMSRCFILE).tar $(RPMFILE)
	gzip $(RPMSRCFILE).tar

rpmbuild: rpmzipsrc
	# Build the RPM and then copy the results local
	./build.sh $(RPMCOMPILEDIR) $(RPMSPECFILE) $(RPMSRCFILE)
	rm -rf ./rpm
	mkdir ./rpm
	cp -p $(RPMCOMPILEDIR)/RPMS/x86_64/*.rpm ./rpm
	cp -p $(RPMCOMPILEDIR)/SRPMS/*.rpm ./rpm

chksrc:
	$(CDIR)checkpatch.pl --file --terse $(SOURCE)$(DRV_NAME)/*.c
chkhdr:
	$(CDIR)checkpatch.pl --file --terse $(SOURCE)$(DRV_NAME)/*.h

.PHONY: all clean clobber doc src install rpmzipsrc rpmbuild