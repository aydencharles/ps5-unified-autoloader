# ps5-unified-autoloader Makefile

# -----------------------------------------------------------------------
# SDK paths
# -----------------------------------------------------------------------
SDK    ?= $(PS5_PAYLOAD_SDK)
TARGET := $(SDK)/target

# -----------------------------------------------------------------------
# Tools
# -----------------------------------------------------------------------
ifeq ($(origin CC), default)
CC := $(SDK)/bin/prospero-clang
endif
STRIP ?= $(SDK)/bin/prospero-strip

# -----------------------------------------------------------------------
# Build config
# -----------------------------------------------------------------------
# -I. lets the compiler find pldmgr_elf.c generated in the project root
INCLUDES := -I. -Iinclude -I$(TARGET)/include
LIBS     := -lSceSystemService -lSceUserService -lSceNetCtl -lpthread
SRCS     := src/main.c src/launcher.c src/app_killer.c src/notification.c src/sync.c
CFLAGS   := -Os -Wall -ffunction-sections -fdata-sections
LDFLAGS  := -Wl,--gc-sections

ELF          := autoloader.elf
PLDMGR_ELF   := pldmgr.elf
PLDMGR_ELF_C := pldmgr_elf.c

# -----------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------
.PHONY: all clean dist-clean check-sdk

all: $(ELF)

.PHONY: check-sdk
check-sdk:
	@test -n "$(SDK)" || (echo "ERROR: PS5_PAYLOAD_SDK is not set." >&2; exit 1)
	@test -x "$(CC)" || (echo "ERROR: PS5 Payload SDK compiler not found: $(CC)" >&2; exit 1)
	@test -x "$(STRIP)" || (echo "ERROR: PS5 Payload SDK strip tool not found: $(STRIP)" >&2; exit 1)

# Embed pldmgr.elf as a C byte array (included directly by src/main.c)
$(PLDMGR_ELF_C): $(PLDMGR_ELF)
	@echo "Embedding $(PLDMGR_ELF)..."
	xxd -i $< > $@

# Build autoloader.elf — pldmgr_elf.c is #include-d by src/main.c,
# so it must NOT be passed again as a separate source file.
$(ELF): $(PLDMGR_ELF_C) $(SRCS) | check-sdk
	@echo "Building $(ELF)..."
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) -o $@ $(SRCS) $(LIBS)
	@echo "Stripping $(ELF)..."
	$(STRIP) $@
	@echo "Done: $(ELF)"

clean:
	rm -f $(ELF) $(PLDMGR_ELF_C)

dist-clean: clean
	rm -f $(PLDMGR_ELF)
