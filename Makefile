# Default to release build, use DEBUG=1 to build debug
PROFILE ?= release
CARGO_FLAGS = --release

ifeq ($(DEBUG),1)
	PROFILE = debug
	CARGO_FLAGS =
endif

all: build

build:
	cargo build $(CARGO_FLAGS)

clean:
	cargo clean

test:
	cargo test --lib
	cargo test --test config_test --test handler_test --test logging_fsync_test --test functional_interface_mapping_test --test functional_http_contract_test --test functional_ws_contract_test

test_unit:
	cargo test --lib

test_functional:
	cargo test --test config_test --test handler_test --test logging_fsync_test --test functional_interface_mapping_test --test functional_http_contract_test --test functional_ws_contract_test

test_integration:
	cargo test --test integration_process_boot_test --test integration_redis_http_test --test integration_redis_pubsub_test --test integration_redis_socket_test --test websocket_raw_test

perftest:
	./tests/bench.sh

test_all: test perftest

.PHONY: all build clean install test perftest test_all
