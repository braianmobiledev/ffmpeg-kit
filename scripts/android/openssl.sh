#!/bin/bash

if [[ ${ARCH} == "x86" ]]; then
  # MODIFICACIÓN: En lugar de retornar error 200, salimos con éxito (0)
  # para que el script principal continúe. FFmpeg.sh se encargará de NO usar OpenSSL en x86.
  echo -e "INFO: openssl skipped on $ARCH (will use GnuTLS in ffmpeg step).\n" 1>>"${BASEDIR}"/build.log 2>&1
  
  # Importante: No retornamos error. Retornamos 0 (éxito)
  return 0
fi

# SET BUILD OPTIONS
ASM_OPTIONS=""
case ${ARCH} in
arm-v7a | arm-v7a-neon)
  ASM_OPTIONS="linux-generic32"
  ;;
arm64-v8a)
  ASM_OPTIONS="linux-generic64 enable-ec_nistp_64_gcc_128"
  ;;
x86)
  ASM_OPTIONS="linux-generic32 386"
  ;;
x86-64)
  ASM_OPTIONS="linux-generic64 enable-ec_nistp_64_gcc_128"
  ;;
esac

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_openssl} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

INT128_AVAILABLE=$($CC -dM -E - </dev/null 2>>"${BASEDIR}"/build.log | grep __SIZEOF_INT128__)

echo -e "INFO: __uint128_t detection output: $INT128_AVAILABLE\n" 1>>"${BASEDIR}"/build.log 2>&1

./Configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  zlib \
  no-shared \
  no-engine \
  no-dso \
  no-legacy \
  ${ASM_OPTIONS} \
  no-tests || return 1

make -j$(get_cpu_count) build_sw || return 1

make install_sw install_ssldirs || return 1

# MANUALLY COPY PKG-CONFIG FILES
cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
