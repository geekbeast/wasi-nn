#!/bin/bash

set -e
if [ -z $1 ]; then
    echo "Please specify as or rust to build"
else
    BUILD_TYPE=$1
    WASI_NN_DIR=$(dirname "$0" | xargs dirname)
    WASI_NN_DIR=$(realpath $WASI_NN_DIR)
    if [ ! -d "$WASI_NN_DIR/wasmtime" ] ; then
        git clone git@github.com:bytecodealliance/wasmtime.git
    fi
    pushd $WASI_NN_DIR/wasmtime
    git submodule init
    git submodule update
    # Inform the environment of OpenVINO library locations. Then we use OPENVINO_INSTALL_DIR below to avoid building all of
    # OpenVINO from source (quite slow).
    source /opt/intel/openvino/bin/setupvars.sh

    # Build Wasmtime with wasi-nn enabled; we attempt this first to avoid extra work if the build fails.
    export OPENVINO_INSTALL_DIR=/opt/intel/openvino

    cargo build -p wasmtime-cli --features wasi-nn
    popd

    case $BUILD_TYPE in
        as)
        pushd $WASI_NN_DIR/assemblyscript
            npm install
            ln -sf $WASI_NN_DIR/wasmtime/target/debug/wasmtime wasmtime
            npm run demo
            ;;

        rust)
            echo "The first argument: $1"
            FIXTURE=https://github.com/intel/openvino-rs/raw/main/crates/openvino/tests/fixtures/alexnet
            pushd $WASI_NN_DIR/rust/
            cargo build --release --target=wasm32-wasi
            mkdir -p $WASI_NN_DIR/rust/examples/classification-example/build
            RUST_BUILD_DIR=$(realpath $WASI_NN_DIR/rust/examples/classification-example/build/)
            ln -sf $WASI_NN_DIR/wasmtime/target/debug/wasmtime $RUST_BUILD_DIR/wasmtime
            pushd examples/classification-example
            cargo build --release --target=wasm32-wasi
            cp target/wasm32-wasi/release/wasi-nn-example.wasm $RUST_BUILD_DIR
            pushd build
            wget --no-clobber --directory-prefix=$RUST_BUILD_DIR $FIXTURE/alexnet.bin
            wget --no-clobber --directory-prefix=$RUST_BUILD_DIR $FIXTURE/alexnet.xml
            wget --no-clobber --directory-prefix=$RUST_BUILD_DIR $FIXTURE/tensor-1x3x227x227-f32.bgr
            ./wasmtime run --mapdir fixture::$RUST_BUILD_DIR wasi-nn-example.wasm
        ;;
        *)
            echo "Unknown build type $BUILD_TYPE"
        ;;
    esac
fi


