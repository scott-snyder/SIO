
# Policy for "Support new ``if()`` IN_LIST operator"
CMAKE_POLICY( SET CMP0057 NEW )

MACRO( SIO_ADD_SHARED_LIBRARY _name )
  ADD_LIBRARY( ${_name} SHARED ${ARGN} )
  # change lib_target properties
  SET_TARGET_PROPERTIES( ${_name} PROPERTIES
    # create *nix style library versions + symbolic links
    VERSION ${${PROJECT_NAME}_VERSION}
    SOVERSION ${${PROJECT_NAME}_SOVERSION}
  )
ENDMACRO()

# wrapper macro for installing a shared library with
# correct permissions
MACRO( SIO_INSTALL_SHARED_LIBRARY )
  # install library
  INSTALL( TARGETS ${ARGN}
    PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE
  )
ENDMACRO()

# wrapper macro to install a directory
# excluding any backup, temporary files
# and .svn / CVS directories
MACRO( SIO_INSTALL_DIRECTORY )
    INSTALL( DIRECTORY ${ARGN}
        PATTERN "*~" EXCLUDE
        PATTERN "*#*" EXCLUDE
        PATTERN ".#*" EXCLUDE
        PATTERN "*CVS" EXCLUDE
        PATTERN "*.svn" EXCLUDE
    )
ENDMACRO()

FUNCTION( SIO_GENERATE_DOXYFILE )
  CMAKE_PARSE_ARGUMENTS( ARG "" "OUTPUT_DIR" "INPUT" ${ARGN} )
  # the input directory where the Doxyfile.in is
  SET( DOXYFILE_INPUT_DIR "${PROJECT_SOURCE_DIR}/cmake" )
  # the output location of the Doxyfile 
  SET( DOXYFILE_OUTPUT_DIR "${PROJECT_BINARY_DIR}/Doxygen" )
  IF( ARG_OUTPUT_DIR )
    SET( DOXYFILE_OUTPUT_DIR ${ARG_OUTPUT_DIR} )
  ENDIF()
  # the doxygen input source location
  SET( DOX_INPUT ${ARG_INPUT} )
  # the project version
  SET( DOX_PROJECT_NUMBER "${${PROJECT_NAME}_VERSION}" )
  # output path of doxygen output (html, latex, ...)
  SET( DOX_OUTPUT_DIRECTORY "${DOXYFILE_OUTPUT_DIR}" )
  # configure file to output location
  FILE( MAKE_DIRECTORY ${DOXYFILE_OUTPUT_DIR} )
  CONFIGURE_FILE( "${DOXYFILE_INPUT_DIR}/Doxyfile.in" "${DOXYFILE_OUTPUT_DIR}/Doxyfile" @ONLY )
ENDFUNCTION()


# helper macro to display standard cmake variables and force write to cache
# otherwise outdated values may appear in ccmake gui
MACRO( SIO_DISPLAY_STD_VARIABLES )
  MESSAGE( STATUS )
  MESSAGE( STATUS "-------------------------------------------------------------------------------" )
  MESSAGE( STATUS "Change values with: cmake -D<Variable>=<Value>" )
  IF( DEFINED CMAKE_INSTALL_PREFIX )
    MESSAGE( STATUS "CMAKE_INSTALL_PREFIX = ${CMAKE_INSTALL_PREFIX}" )
  ENDIF()
  IF( DEFINED CMAKE_BUILD_TYPE )
    MESSAGE( STATUS "CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}" )
  ENDIF()
  IF( DEFINED BUILD_SHARED_LIBS )
    MESSAGE( STATUS "BUILD_SHARED_LIBS = ${BUILD_SHARED_LIBS}" )
  ENDIF()
  IF( DEFINED BUILD_TESTING )
    MESSAGE( STATUS "BUILD_TESTING = ${BUILD_TESTING}" )
  ENDIF()
  IF( DEFINED INSTALL_DOC )
    MESSAGE( STATUS "INSTALL_DOC = ${INSTALL_DOC}" )
  ENDIF()
  IF( DEFINED CMAKE_PREFIX_PATH )
    LIST( REMOVE_DUPLICATES CMAKE_PREFIX_PATH )
    MESSAGE( STATUS "CMAKE_PREFIX_PATH =" )
    FOREACH( _path ${CMAKE_PREFIX_PATH} )
        MESSAGE( STATUS "   ${_path};" )
    ENDFOREACH()
  ENDIF()
  IF( DEFINED CMAKE_MODULE_PATH )
    LIST( REMOVE_DUPLICATES CMAKE_MODULE_PATH )
    MESSAGE( STATUS "CMAKE_MODULE_PATH =" )
    FOREACH( _path ${CMAKE_MODULE_PATH} )
        MESSAGE( STATUS "   ${_path};" )
    ENDFOREACH()
    SET( CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" CACHE PATH "CMAKE_MODULE_PATH" FORCE )
  ENDIF()
  MESSAGE( STATUS "-------------------------------------------------------------------------------" )
  MESSAGE( STATUS )
ENDMACRO()


# set default install prefix to project root directory
# instead of the cmake default /usr/local
IF( CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT )
 	SET(CMAKE_INSTALL_PREFIX "${PROJECT_SOURCE_DIR}" CACHE PATH "Where to install ${PROJECT_NAME}" FORCE)
ENDIF()

# set default cmake build type to RelWithDebInfo
# possible options are: None Debug Release RelWithDebInfo MinSizeRel
IF( NOT CMAKE_BUILD_TYPE )
    SET( CMAKE_BUILD_TYPE "RelWithDebInfo" )
ENDIF()

# write this variable to cache
SET( CMAKE_BUILD_TYPE "${CMAKE_BUILD_TYPE}" CACHE STRING "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel." FORCE )

# enable ctest
ENABLE_TESTING()
INCLUDE(CTest)
MARK_AS_ADVANCED( DART_TESTING_TIMEOUT )

# library *nix style versioning
SET( ${PROJECT_NAME}_SOVERSION "${${PROJECT_NAME}_VERSION_MAJOR}.${${PROJECT_NAME}_VERSION_MINOR}" )
SET( ${PROJECT_NAME}_VERSION   "${${PROJECT_NAME}_SOVERSION}.${${PROJECT_NAME}_VERSION_PATCH}" )

# output directories
SET( EXECUTABLE_OUTPUT_PATH "${PROJECT_BINARY_DIR}/bin" )
SET( LIBRARY_OUTPUT_PATH "${PROJECT_BINARY_DIR}/lib" )
MARK_AS_ADVANCED( EXECUTABLE_OUTPUT_PATH )

# add install path to the rpath list (apple)
IF( APPLE )
  SET( CMAKE_INSTALL_NAME_DIR "${CMAKE_INSTALL_PREFIX}/lib" )
  MARK_AS_ADVANCED( CMAKE_INSTALL_NAME_DIR )
ENDIF()

# append link pathes to rpath list
SET( CMAKE_INSTALL_RPATH_USE_LINK_PATH 1 )
MARK_AS_ADVANCED( CMAKE_INSTALL_RPATH_USE_LINK_PATH )

## Set the default compiler flags for all projects picking up default ilcutil settings
## This runs checks if compilers support the flag and sets them, if they do
## this will create a humongous amount of warnings when compiling :)
INCLUDE(CheckCXXCompilerFlag)

SET( COMPILER_FLAGS
  -Wformat-security
  -Wreturn-type
  -Wlogical-op
  -Wredundant-decls
  -Wno-deprecated-declarations
  -Wall
  -Wunused-value
  -Wextra
  -Wshadow
  -Weffc++
  -pedantic
  -Wno-long-long
  -Wuninitialized
  -Wno-non-virtual-dtor
  -Wheader-hygiene
  -fdiagnostics-color=auto
)

IF( SIO_PROFILING AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" )
  LIST( APPEND COMPILER_FLAGS -pg )
ENDIF()

IF( SIO_WITH_OFAST )
  SET( CMAKE_CXX_FLAGS_RELEASE "-Ofast" )
ELSE()
  SET( CMAKE_CXX_FLAGS_RELEASE "-O3" )
ENDIF()

# resolve which linker we use
EXECUTE_PROCESS(COMMAND ${CMAKE_CXX_COMPILER} -Wl,--version OUTPUT_VARIABLE stdout ERROR_QUIET)
IF("${stdout}" MATCHES "GNU ")
  SET(LINKER_TYPE "GNU")
  MESSAGE( STATUS "Detected GNU compatible linker" )
ELSE()
  EXECUTE_PROCESS(COMMAND ${CMAKE_CXX_COMPILER} -Wl,-v ERROR_VARIABLE stderr )
  IF(("${stderr}" MATCHES "PROGRAM:ld") AND ("${stderr}" MATCHES "PROJECT:ld64"))
    SET(LINKER_TYPE "APPLE")
    MESSAGE( STATUS "Detected Apple linker" )
  ELSE()
    SET(LINKER_TYPE "unknown")
    MESSAGE( STATUS "Detected unknown linker" )
  ENDIF()
ENDIF()

IF("${LINKER_TYPE}" STREQUAL "APPLE")
  SET ( CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-undefined,error")
elseIF("${LINKER_TYPE}" STREQUAL "GNU")
  SET ( CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")
ELSE()
  MESSAGE( WARNING "No known linker (GNU or Apple) has been detected, pass no flags to linker" )
ENDIF()

# Dealing with CXX standard
SET( SIO_POSSIBLE_CXX_STANDARDS 11 14 17 20 23 26 )
LIST( GET SIO_POSSIBLE_CXX_STANDARDS 0 SIO_MINIMUM_CXX_REQUIRED )

IF( CMAKE_CXX_STANDARD )
  MESSAGE( STATUS "Checking CXX standard set by user ..." )
  IF( NOT ${CMAKE_CXX_STANDARD} IN_LIST SIO_POSSIBLE_CXX_STANDARDS )
    MESSAGE( FATAL_ERROR "Invalid cxx standard (set=${CMAKE_CXX_STANDARD}, minimum=${SIO_MINIMUM_CXX_REQUIRED})" )
  ENDIF()
ELSE()
  MESSAGE( STATUS "Setting CXX standard to minimum required ..." )
  SET( CMAKE_CXX_STANDARD ${SIO_MINIMUM_CXX_REQUIRED} )
ENDIF()

MESSAGE( STATUS "Using CXX standard ${CMAKE_CXX_STANDARD}" )

MESSAGE( STATUS "FLAGS ${COMPILER_FLAGS}" )
FOREACH( FLAG ${COMPILER_FLAGS} )
  ## meed to replace the minus or plus signs from the variables, because it is passed
  ## as a macro to g++ which causes a warning about no whitespace after macro
  ## definition
  STRING(REPLACE "-" "_" FLAG_WORD ${FLAG} )
  STRING(REPLACE "+" "P" FLAG_WORD ${FLAG_WORD} )

  CHECK_CXX_COMPILER_FLAG( "${FLAG}" CXX_FLAG_WORKS_${FLAG_WORD} )
  IF( ${CXX_FLAG_WORKS_${FLAG_WORD}} )
    MESSAGE ( STATUS "Adding ${FLAG} to CXX_FLAGS" )
    ### We prepend the flag, so they are overwritten by whatever the user sets in his own configuration
    SET ( CMAKE_CXX_FLAGS "${FLAG} ${CMAKE_CXX_FLAGS}")
  ELSE()
    MESSAGE ( STATUS "NOT Adding ${FLAG} to CXX_FLAGS" )
  ENDIF()
ENDFOREACH()


#  When building, don't use the install RPATH already (but later on when installing)
SET(CMAKE_SKIP_BUILD_RPATH FALSE)         # don't skip the full RPATH for the build tree
SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE) # use always the build RPATH for the build tree
SET(CMAKE_MACOSX_RPATH TRUE)              # use RPATH for MacOSX
SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE) # point to directories outside the build tree to the install RPATH

# Check whether to add RPATH to the installation (the build tree always has the RPATH enabled)
IF(APPLE)
  SET(CMAKE_INSTALL_NAME_DIR "@rpath")
  SET(CMAKE_INSTALL_RPATH "@loader_path/../lib")    # self relative LIBDIR
  # the RPATH to be used when installing, but only if it's not a system directory
  LIST(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib" isSystemDir)
  IF("${isSystemDir}" STREQUAL "-1")
    SET(CMAKE_INSTALL_RPATH "@loader_path/../lib")
  ENDIF("${isSystemDir}" STREQUAL "-1")
ELSEIF(SIO_SET_RPATH)
  SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib") # install LIBDIR
  # the RPATH to be used when installing, but only if it's not a system directory
  LIST(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib" isSystemDir)
  IF("${isSystemDir}" STREQUAL "-1")
    SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
  ENDIF("${isSystemDir}" STREQUAL "-1")
ELSE()
  SET(CMAKE_SKIP_INSTALL_RPATH TRUE)           # skip the full RPATH for the install tree
ENDIF()
