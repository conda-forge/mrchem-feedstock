BUILD_TYPE="Release"
CXXFLAGS="${CXXFLAGS//-march=nocona}"
CXXFLAGS="${CXXFLAGS//-mtune=haswell}"

export CXX=$(basename ${CXX})

if [[ ! -z "$mpi" && "$mpi" != "nompi" ]]; then
  MPI_SUPPORT=ON
else
  MPI_SUPPORT=OFF
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  # This is only used by open-mpi's mpicc
  # ignored in other cases
  export OMPI_CC="$CC"
  export OMPI_CXX="$CXX"
  export OMPI_FC="$FC"
  export OPAL_PREFIX="$PREFIX"
fi

# configure
cmake ${CMAKE_ARGS} \
  -H${SRC_DIR} \
  -Bbuild \
  -GNinja \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
  -DENABLE_OPENMP=ON \
  -DENABLE_ARCH_FLAGS=OFF \
  -DENABLE_MPI=${MPI_SUPPORT} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DCMAKE_INSTALL_LIBDIR="lib" \
  -DPYMOD_INSTALL_LIBDIR="${SP_DIR#$PREFIX/lib}"


# build
cd build
cmake --build . -- -j${CPU_COUNT} -v -d stats

# unset so we can run tests
if [ "$(uname)" = "Linux" ]; then
  export OMPI_MCA_plm_rsh_agent=""
fi

# test
if [[ ("${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "") && "$target_platform" != linux-ppc64le ]]; then
  ctest -j${CPU_COUNT} --output-on-failure --verbose
fi

# install
cmake --build . --target install -- -j${CPU_COUNT}
