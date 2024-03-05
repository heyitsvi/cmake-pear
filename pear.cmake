set(pear_module_dir "${CMAKE_CURRENT_LIST_DIR}")

include(bare)

bare_target(pear_host)

if(pear_host MATCHES "darwin")
  include(macos)
elseif(pear_host MATCHES "linux")
  include(app-image)
elseif(pear_host MATCHES "win32")
  include(msix)
else()
  message(FATAL_ERROR "Unsupported target '${pear_host}'")
endif()

mirror_drive(
  SOURCE qogbhqbcxknrpeotyz7hk4x3mxuf6d9mhb1dxm6ms5sdn6hh1uso
  DESTINATION "${PROJECT_SOURCE_DIR}/prebuilds"
  PREFIX /${pear_host}
  CHECKOUT 113
  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
)


mirror_drive(
  SOURCE excdougxjday9q8d13azwwjss8p8r66fhykb18kzjfk9bwaetkuo
  DESTINATION "${PROJECT_SOURCE_DIR}/prebuilds"
  PREFIX /${pear_host}
  CHECKOUT 8
  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
)

if(NOT TARGET c++)
  add_library(c++ STATIC IMPORTED)

  find_library(
    c++
    NAMES c++ libc++
    PATHS "${PROJECT_SOURCE_DIR}/prebuilds/${pear_host}"
    REQUIRED
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
  )

  set_target_properties(
    c++
    PROPERTIES
    IMPORTED_LOCATION "${c++}"
  )
endif()

if(NOT TARGET v8)
  add_library(v8 STATIC IMPORTED)

  find_library(
    v8
    NAMES v8 libv8
    PATHS "${PROJECT_SOURCE_DIR}/prebuilds/${pear_host}"
    REQUIRED
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
  )

  set_target_properties(
    v8
    PROPERTIES
    IMPORTED_LOCATION "${v8}"
  )

  target_link_libraries(
    v8
    INTERFACE
      c++
  )

  if(pear_host MATCHES "linux")
    target_link_libraries(
      v8
      INTERFACE
        m
    )
  elseif(pear_host MATCHES "android")
    find_library(log log)

    target_link_libraries(
      v8
      INTERFACE
        "${log}"
    )
  elseif(pear_host MATCHES "win32")
    target_link_libraries(
      v8
      INTERFACE
        winmm
    )
  endif()
endif()

if(NOT TARGET js)
  add_library(js STATIC IMPORTED)

  find_library(
    js
    NAMES js libjs
    PATHS "${PROJECT_SOURCE_DIR}/prebuilds/${pear_host}"
    REQUIRED
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
  )

  set_target_properties(
    js
    PROPERTIES
    IMPORTED_LOCATION "${js}"
  )

  target_link_libraries(
    js
    INTERFACE
      v8
  )
endif()

if(NOT TARGET pear)
  add_library(pear STATIC IMPORTED)

  find_library(
    pear
    NAMES pear libpear
    PATHS "${PROJECT_SOURCE_DIR}/prebuilds/${pear_host}"
    REQUIRED
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
  )

  set_target_properties(
    pear
    PROPERTIES
    IMPORTED_LOCATION "${pear}"
  )

  target_include_directories(
    pear
    INTERFACE
      "${pear_module_dir}"
  )

  target_link_libraries(
    pear
    INTERFACE
      js
  )

  if(pear_host MATCHES "darwin")
    target_link_libraries(
      pear
      INTERFACE
        "-framework Foundation"
        "-framework CoreMedia"
        "-framework AppKit"
        "-framework AVFoundation"
        "-framework AVKit"
        "-framework WebKit"
    )
  endif()

  if(pear_host MATCHES "win32")
    target_link_libraries(
      pear
      INTERFACE
        Dbghelp
        Iphlpapi
        Shcore
        Userenv
        WindowsApp
    )
  endif()

  if(pear_host MATCHES "linux")
    find_package(PkgConfig REQUIRED)

    pkg_check_modules(GTK4 REQUIRED IMPORTED_TARGET gtk4)

    target_link_libraries(
      pear
      INTERFACE
        PkgConfig::GTK4
    )
  endif()
endif()

function(configure_pear_appling_macos target)
  set(one_value_keywords
    NAME
    VERSION
    AUTHOR
    SPLASH
    IDENTIFIER
    ICON
    CATEGORY
    SIGNING_IDENTITY
    SIGNING_KEYCHAIN
  )

  set(multi_value_keywords
    ENTITLEMENTS
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(NOT ARGV_ICON)
    set(ARGV_ICON "assets/darwin/icon.icns")
  endif()

  set_target_properties(
    ${target}
    PROPERTIES
    OUTPUT_NAME "${ARGV_NAME}"
  )

  add_macos_entitlements(
    ${target}_entitlements
    ENTITLEMENTS ${ARGV_ENTITLEMENTS}
  )

  add_macos_bundle_info(
    ${target}_bundle_info
    NAME "${ARGV_NAME}"
    VERSION "${ARGV_VERSION}"
    PUBLISHER_DISPLAY_NAME "${ARGV_AUTHOR}"
    IDENTIFIER "${ARGV_IDENTIFIER}"
    CATEGORY "${ARGV_CATEGORY}"
    TARGET ${target}
  )

  add_macos_bundle(
    ${target}_bundle
    DESTINATION "${ARGV_NAME}.app"
    ICON "${ARGV_ICON}"
    TARGET ${target}
    RESOURCES
      FILE "${ARGV_SPLASH}" "splash.png"
  )

  code_sign_macos_bundle(
    ${target}_sign
    PATH "${CMAKE_CURRENT_BINARY_DIR}/${ARGV_NAME}.app"
    IDENTITY "${ARGV_SIGNING_IDENTITY}"
    KEYCHAIN "${ARGV_SIGNING_KEYCHAIN}"
    DEPENDS ${target}_bundle
  )
endfunction()

function(configure_pear_appling_windows target)
  set(one_value_keywords
    NAME
    VERSION
    AUTHOR
    DESCRIPTION
    SPLASH
    LOGO
    ICON
    SIGNING_SUBJECT
    SIGNING_SUBJECT_NAME
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" ""
  )

  if(NOT ARGV_LOGO)
    set(ARGV_LOGO "assets/win32/icon.png")
  endif()

  if(NOT ARGV_ICON)
    set(ARGV_ICON "assets/win32/icon.ico")
  endif()

  set_target_properties(
    ${target}
    PROPERTIES
    OUTPUT_NAME "${ARGV_NAME}"
  )

  target_link_options(
    ${target}
    PRIVATE
      $<$<CONFIG:Release>:/subsystem:windows /entry:mainCRTStartup>
  )

  add_appx_manifest(
    ${target}_manifest
    NAME "${ARGV_NAME}"
    VERSION "${ARGV_VERSION}"
    DESCRIPTION "${ARGV_DESCRIPTION}"
    PUBLISHER "${ARGV_SIGNING_SUBJECT}"
    PUBLISHER_DISPLAY_NAME "${ARGV_AUTHOR}"
    UNVIRTUALIZED_PATHS "$(KnownFolder:RoamingAppData)\\pear"
  )

  add_appx_mapping(
    ${target}_mapping
    LOGO "${ARGV_LOGO}"
    ICON "${ARGV_ICON}"
    TARGET ${target}
    RESOURCES
      FILE "${ARGV_SPLASH}" "splash.png"
  )

  add_msix_package(
    ${target}_msix
    DESTINATION "${ARGV_NAME}.msix"
    DEPENDS ${target}
  )

  code_sign_msix_package(
    ${target}_signature
    PATH "${CMAKE_CURRENT_BINARY_DIR}/${ARGV_NAME}.msix"
    SUBJECT_NAME "${ARGV_SIGNING_SUBJECT_NAME}"
    DEPENDS ${target}_msix
  )
endfunction()

function(configure_pear_appling_linux target)
  set(one_value_keywords
    NAME
    DESCRIPTION
    ICON
    CATEGORY
    SPLASH
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" ""
  )

  if(NOT ARGV_ICON)
    set(ARGV_ICON "assets/linux/icon.png")
  endif()

  string(TOLOWER ARGV_NAME ARGV_OUTPUT_NAME)

  set_target_properties(
    ${target}
    PROPERTIES
    OUTPUT_NAME "${ARGV_OUTPUT_NAME}"
  )

  add_app_image(
    ${target}_app_image
    NAME "${ARGV_NAME}"
    DESCRIPTION "${ARGV_DESCRIPTION}"
    ICON "${ARGV_ICON}"
    CATEGORY "${ARGV_CATEGORY}"
    TARGET ${target}
    RESOURCES
      FILE "${ARGV_SPLASH}" "splash.png"
  )
endfunction()

function(add_pear_appling target)
  set(one_value_keywords
    KEY
    NAME
    VERSION
    DESCRIPTION
    AUTHOR
    SPLASH

    MACOS_IDENTIFIER
    MACOS_ICON
    MACOS_CATEGORY
    MACOS_SIGNING_IDENTITY
    MACOS_SIGNING_KEYCHAIN

    WINDOWS_LOGO
    WINDOWS_ICON
    WINDOWS_SIGNING_SUBJECT
    WINDOWS_SIGNING_SUBJECT_NAME

    LINUX_ICON
    LINUX_CATEGORY
  )

  set(multi_value_keywords
    MACOS_ENTITLEMENTS
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(NOT ARGV_SPLASH)
    set(ARGV_SPLASH "assets/splash.png")
  endif()

  add_executable(${target})

  set_target_properties(
    ${target}
    PROPERTIES
    POSITION_INDEPENDENT_CODE ON
  )

  target_sources(
    ${target}
    PRIVATE
      "${pear_module_dir}/pear.c"
  )

  target_compile_definitions(
    ${target}
    PRIVATE
      KEY="${ARGV_KEY}"
      NAME="${ARGV_NAME}"
  )

  target_link_libraries(
    ${target}
    PRIVATE
      $<LINK_LIBRARY:WHOLE_ARCHIVE,pear>
  )

  if(pear_host MATCHES "darwin")
    configure_pear_appling_macos(
      ${target}
      NAME "${ARGV_NAME}"
      VERSION "${ARGV_VERSION}"
      AUTHOR "${ARGV_AUTHOR}"
      SPLASH "${ARGV_SPLASH}"
      IDENTIFIER "${ARGV_MACOS_IDENTIFIER}"
      ICON "${ARGV_MACOS_ICON}"
      CATEGORY "${ARGV_MACOS_CATEGORY}"
      ENTITLEMENTS ${ARGV_MACOS_ENTITLEMENTS}
      SIGNING_IDENTITY "${ARGV_MACOS_SIGNING_IDENTITY}"
      SIGNING_KEYCHAIN "${ARGV_MACOS_SIGNING_KEYCHAIN}"
    )
  elseif(pear_host MATCHES "win32")
    configure_pear_appling_windows(
      ${target}
      NAME "${ARGV_NAME}"
      VERSION "${ARGV_VERSION}"
      AUTHOR "${ARGV_AUTHOR}"
      DESCRIPTION "${ARGV_DESCRIPTION}"
      SPLASH "${ARGV_SPLASH}"
      LOGO "${ARGV_WINDOWS_LOGO}"
      ICON "${ARGV_WINDOWS_ICON}"
      SIGNING_SUBJECT "${ARGV_WINDOWS_SIGNING_SUBJECT}"
      SIGNING_SUBJECT_NAME "${ARGV_WINDOWS_SIGNING_SUBJECT_NAME}"
    )
  elseif(pear_host MATCHES "linux")
    configure_pear_appling_linux(
      ${target}
      NAME "${ARGV_NAME}"
      DESCRIPTION "${ARGV_DESCRIPTION}"
      SPLASH "${ARGV_SPLASH}"
      ICON "${ARGV_LINUX_ICON}"
      CATEGORY "${ARGV_LINUX_CATEGORY}"
    )
  endif()
endfunction()
