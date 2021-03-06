################################################################################
#
# Copyright 1993-2013 NVIDIA Corporation.  All rights reserved.
#
# NOTICE TO USER:
#
# This source code is subject to NVIDIA ownership rights under U.S. and
# international Copyright laws.
#
# NVIDIA MAKES NO REPRESENTATION ABOUT THE SUITABILITY OF THIS SOURCE
# CODE FOR ANY PURPOSE.  IT IS PROVIDED "AS IS" WITHOUT EXPRESS OR
# IMPLIED WARRANTY OF ANY KIND.  NVIDIA DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOURCE CODE, INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY, NONINFRINGEMENT, AND FITNESS FOR A PARTICULAR PURPOSE.
# IN NO EVENT SHALL NVIDIA BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL,
# OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
# OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
# OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE
# OR PERFORMANCE OF THIS SOURCE CODE.
#
# U.S. Government End Users.  This source code is a "commercial item" as
# that term is defined at 48 C.F.R. 2.101 (OCT 1995), consisting  of
# "commercial computer software" and "commercial computer software
# documentation" as such terms are used in 48 C.F.R. 12.212 (SEPT 1995)
# and is provided to the U.S. Government only as a commercial end item.
# Consistent with 48 C.F.R.12.212 and 48 C.F.R. 227.7202-1 through
# 227.7202-4 (JUNE 1995), all U.S. Government End Users acquire the
# source code with only those rights set forth herein.
#
################################################################################
#
# Makefile project only supported on Mac OS X and Linux Platforms)
#
################################################################################



OSUPPER = $(shell uname -s 2>/dev/null | tr "[:lower:]" "[:upper:]")
OSLOWER = $(shell uname -s 2>/dev/null | tr "[:upper:]" "[:lower:]")

OS_SIZE = $(shell uname -m | sed -e "s/i.86/32/" -e "s/x86_64/64/" -e "s/armv7l/32/")
OS_ARCH = $(shell uname -m | sed -e "s/i386/i686/")

DARWIN = $(strip $(findstring DARWIN, $(OSUPPER)))
ifneq ($(DARWIN),)
	XCODE_GE_5 = $(shell expr `xcodebuild -version | grep -i xcode | awk '{print $$2}' | cut -d'.' -f1` \>= 5)
endif

# Take command line flags that override any of these settings
ifeq ($(i386),1)
	OS_SIZE = 32
	OS_ARCH = i686
endif
ifeq ($(x86_64),1)
	OS_SIZE = 64
	OS_ARCH = x86_64
endif
ifeq ($(ARMv7),1)
	OS_SIZE = 32
	OS_ARCH = armv7l
endif

# Common binaries
ifneq ($(DARWIN),)
ifeq ($(XCODE_GE_5),1)
  GCC ?= clang
else
  GCC ?= g++
endif
else
  GCC ?= g++
endif


INCLUDES  := -I/usr/local/include/libfreenect 
LD_LIBS_LOCATION := -L/usr/local/lib
LD_LIBS :=  -lfreenect  -lopencv_core -lopencv_highgui -lopencv_imgproc -lpthread
LIBRARIES := $(LD_LIBS_LOCATION) $(LD_LIBS) 

# Location of the CUDA Toolkit
CUDA_PATH       ?= /usr/local/cuda-6.0
NVCC := $(CUDA_PATH)/bin/nvcc -ccbin $(GCC)

# Common includes and paths for CUDA
INCLUDES += -I/usr/local/include/opencv
ifeq ($(OS_ARCH),armv7l)
	LD_CUDALIBS_LOCATION := -L/usr/local/cuda/lib
else
	LD_CUDALIBS_LOCATION := -L/usr/local/cuda/lib64
endif
LD_CUDALIBS := -lcudart -lnpps -lnppi -lnppc -lcufft
LIBRARIES += $(LD_CUDALIBS_LOCATION) $(LD_CUDALIBS) 

# internal flags
NVCCFLAGS   := -m${OS_SIZE}
CCFLAGS     :=
LDFLAGS     :=

# Extra user flags
EXTRA_NVCCFLAGS   ?=
EXTRA_LDFLAGS     ?=
EXTRA_CCFLAGS     ?=

# OS-specific build flags
ifneq ($(DARWIN),)
  LDFLAGS += -rpath $(CUDA_PATH)/lib
  CCFLAGS += -arch $(OS_ARCH)
else
  ifeq ($(OS_ARCH),armv7l)
    ifeq ($(abi),androideabi)
      NVCCFLAGS += -target-os-variant Android
    else
      ifeq ($(abi),gnueabi)
        CCFLAGS += -mfloat-abi=softfp
      else
        # default to gnueabihf
        override abi := gnueabihf
        LDFLAGS += --dynamic-linker=/lib/ld-linux-armhf.so.3
        CCFLAGS += -mfloat-abi=hard
      endif
    endif
  endif
endif

ifeq ($(ARMv7),1)
NVCCFLAGS += -target-cpu-arch ARM
ifneq ($(TARGET_FS),)
CCFLAGS += --sysroot=$(TARGET_FS)
LDFLAGS += --sysroot=$(TARGET_FS)
LDFLAGS += -rpath-link=$(TARGET_FS)/lib
LDFLAGS += -rpath-link=$(TARGET_FS)/usr/lib
LDFLAGS += -rpath-link=$(TARGET_FS)/usr/lib/arm-linux-$(abi)
endif
endif

# Debug build flags
ifeq ($(dbg),1)
      NVCCFLAGS += -G
      CCFLAGS += -g
      TARGET := debug
else
      TARGET := release
endif

ALL_CCFLAGS :=
ALL_CCFLAGS += $(NVCCFLAGS)
ALL_CCFLAGS += $(EXTRA_NVCCFLAGS)
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(CCFLAGS))
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(EXTRA_CCFLAGS))

ALL_LDFLAGS :=
ALL_LDFLAGS += $(ALL_CCFLAGS)
ALL_LDFLAGS += $(addprefix -Xlinker ,$(LDFLAGS))
ALL_LDFLAGS += $(addprefix -Xlinker ,$(EXTRA_LDFLAGS))

MPI_CCFLAGS :=
MPI_CCFLAGS += $(CCFLAGS)
MPI_CCFLAGS += $(EXTRA_CCFLAGS)

MPI_LDFLAGS :=
MPI_LDFLAGS += $(addprefix -Xlinker ,$(LDFLAGS))
MPI_LDFLAGS += $(addprefix -Xlinker ,$(EXTRA_LDFLAGS))



################################################################################

EXEC   ?=

# MPI check and binaries
MPICXX ?= $(shell which mpicxx 2>/dev/null)

ifneq ($(shell uname -m | sed -e "s/i386/i686/"), ${OS_ARCH})
      $(info -----------------------------------------------------------------------------------------------)
      $(info WARNING - attempting to detect 32-bit MPI compiler.)
      MPICXX := $(shell echo $(MPICXX) | sed -e "s/64//")
endif

ifeq ($(MPICXX),)
      $(info -----------------------------------------------------------------------------------------------)
      $(info WARNING - No MPI compiler found.)
      $(info -----------------------------------------------------------------------------------------------)
      $(info   CUDA Sample "simpleMPI" cannot be built without an MPI Compiler.)
      $(info   This will be a dry-run of the Makefile.)
      $(info   For more information on how to set up your environment to build and run this )
      $(info   sample, please refer the CUDA Samples documentation and release notes)
      $(info -----------------------------------------------------------------------------------------------)
      MPICXX=mpicxx
      EXEC=@echo "[@]"
else
      MPI_GCC := $(shell $(MPICXX) -v 2>&1 | grep gcc | wc -l | tr -d ' ')
ifeq ($(MPI_GCC),0)
      MPI_CCFLAGS += -stdlib=libstdc++
      MPI_LDFLAGS += -stdlib=libstdc++
endif
endif

# CUDA code generation flags
ifneq ($(OS_ARCH),armv7l)
GENCODE_SM10    := -gencode arch=compute_10,code=sm_10
endif
GENCODE_SM20    := -gencode arch=compute_20,code=sm_20
GENCODE_SM30    := -gencode arch=compute_30,code=sm_30
GENCODE_SM32    := -gencode arch=compute_32,code=sm_32
GENCODE_SM35    := -gencode arch=compute_35,code=sm_35
GENCODE_SM50    := -gencode arch=compute_50,code=sm_50
GENCODE_SMXX    := -gencode arch=compute_50,code=compute_50
ifeq ($(OS_ARCH),armv7l)
GENCODE_FLAGS   ?= $(GENCODE_SM32)
else
GENCODE_FLAGS   ?= $(GENCODE_SM10) $(GENCODE_SM20) $(GENCODE_SM30) $(GENCODE_SM32) $(GENCODE_SM35) $(GENCODE_SM50) $(GENCODE_SMXX)
endif

LIBSIZE :=
ifeq ($(DARWIN),)
ifeq ($(OS_SIZE),64)
LIBSIZE := 64
endif
endif

LIBRARIES += -L$(CUDA_PATH)/lib$(LIBSIZE) -lcudart

################################################################################

# Target rules
all: build

build: simpleMPI

simpleMPI_mpi.o:simpleMPI.cpp
	$(EXEC) $(MPICXX) $(INCLUDES) $(MPI_CCFLAGS) -o $@ -c $< $(LIBRARIES)

simpleMPI.o:simpleMPI.cu
	$(EXEC) $(NVCC) $(INCLUDES) $(ALL_CCFLAGS) $(GENCODE_FLAGS) -o $@ -c $< $(LIBRARIES)

simpleMPI: simpleMPI_mpi.o simpleMPI.o
	$(EXEC) $(MPICXX) $(MPI_LDFLAGS) -o $@ $+ $(LIBRARIES)
#	$(EXEC) mkdir -p ../../bin/$(OS_ARCH)/$(OSLOWER)/$(TARGET)$(if $(abi),/$(abi))
#	$(EXEC) cp $@ ../../bin/$(OS_ARCH)/$(OSLOWER)/$(TARGET)$(if $(abi),/$(abi))

run: build
	$(EXEC) ./simpleMPI

clean:
	rm -f simpleMPI simpleMPI_mpi.o simpleMPI.o
#	rm -rf ../../bin/$(OS_ARCH)/$(OSLOWER)/$(TARGET)$(if $(abi),/$(abi))/simpleMPI

clobber: clean

print-%  : ; @echo $* = $($*)
