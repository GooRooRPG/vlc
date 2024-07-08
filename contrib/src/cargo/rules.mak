# cargo/cargo-c installation via rustup

RUST_VERSION=1.79.0
CARGOC_VERSION=0.9.29
RUSTUP_VERSION := 1.27.1
RUSTUP_URL := $(GITHUB)/rust-lang/rustup/archive/refs/tags/$(RUSTUP_VERSION).tar.gz

RUSTUP = . $(CARGO_HOME)/env && \
	RUSTUP_HOME=$(RUSTUP_HOME) CARGO_HOME=$(CARGO_HOME) rustup

ifdef BUILD_RUST
PKGS_TOOLS += rustup rustc cargo
PKGS_ALL += rustup rustc

ifdef HAVE_CROSS_COMPILE
PKGS_TOOLS += rustc-cross
PKGS_ALL += rustc-cross
endif

ifneq ($(call system_tool_version, rustup --version, cat),)
PKGS_FOUND += rustup
RUSTUP = RUSTUP_HOME=$(RUSTUP_HOME) CARGO_HOME=$(CARGO_HOME) rustup
endif

ifneq ($(call system_tool_majmin, cargo --version),)
PKGS_FOUND += rustc
# TODO detect if the target is available
# PKGS_FOUND += rustc-cross
else
DEPS_rustc = rustup $(DEPS_rustup)
endif

ifneq ($(call system_tool_majmin, cargo-capi --version),)
PKGS_FOUND += cargo
endif

endif

DEPS_rustc-cross = rustc $(DEPS_rustc) rustup $(DEPS_rustup)

ifdef HAVE_CROSS_COMPILE
DEPS_cargo = rustc-cross $(DEPS_rustc-cross)
else
DEPS_cargo = rustc $(DEPS_rustc)
endif

$(TARBALLS)/rustup-$(RUSTUP_VERSION).tar.gz:
	$(call download_pkg,$(RUSTUP_URL),cargo)

.sum-cargo: rustup-$(RUSTUP_VERSION).tar.gz

.sum-rustup: .sum-cargo
	touch $@

.sum-rustc: .sum-cargo
	touch $@

.sum-rustc-cross: .sum-cargo
	touch $@

cargo: rustup-$(RUSTUP_VERSION).tar.gz .sum-cargo
	$(UNPACK)
	$(MOVE)

# Test if we can use the host libssl library
ifeq ($(shell unset PKG_CONFIG_LIBDIR PKG_CONFIG_PATH; \
	pkg-config "openssl >= 1.0.1" 2>/dev/null || \
	pkg-config "libssl >= 2.5" 2>/dev/null || echo FAIL),)
CARGOC_FEATURES=
else
# Otherwise, let cargo build and statically link its own openssl
CARGOC_FEATURES=--features=cargo/vendored-openssl
endif

.rustup: cargo
	cd $< && RUSTUP_INIT_SKIP_PATH_CHECK=yes \
	  RUSTUP_HOME=$(RUSTUP_HOME) CARGO_HOME=$(CARGO_HOME) \
	  ./rustup-init.sh --no-modify-path -y --default-toolchain none
	touch $@

.rustc: cargo
	+$(RUSTUP) set profile minimal
	+$(RUSTUP) default $(RUST_VERSION)
	touch $@

.rustc-cross: cargo
	+$(RUSTUP) set profile minimal
	+$(RUSTUP) default $(RUST_VERSION)
	+$(RUSTUP) target add --toolchain $(RUST_VERSION) $(RUST_TARGET)
	touch $@

# When needed (when we have a Rust dependency not using cargo-c), the cargo-c
# installation should go in a different package
.cargo: cargo
	+unset PKG_CONFIG_LIBDIR PKG_CONFIG_PATH CFLAGS CPPFLAGS LDFLAGS; \
		$(CARGO) install --locked $(CARGOC_FEATURES) cargo-c --version $(CARGOC_VERSION)
	touch $@
