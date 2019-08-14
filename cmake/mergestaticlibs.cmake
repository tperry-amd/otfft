# Copyright Modelon AB 2012
# Copyright DEWETRON GmbH 2017

# This program is free software: you can redistribute it and/or modify
# it under the terms of the BSD style license.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# FMILIB_License.txt file for more details.

# You should have received a copy of the FMILIB_License.txt file
# along with this program. If not, contact Modelon AB <http://www.modelon.com>.

# Merge_static_libs(outlib lib1 lib2 ... libn) merges a number of static
# libs into a single static library
function(merge_static_libs outlib )
  set(libs ${ARGV})
  list(REMOVE_AT libs 0)
  # Create a dummy file that the target will depend on
  set(dummyfile ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${outlib}_dummy.c)
  file(WRITE ${dummyfile} "const char * dummy = \"${dummyfile}\";")

  add_library(${outlib} STATIC ${dummyfile})

  if("${CMAKE_CFG_INTDIR}" STREQUAL ".")
    set(multiconfig FALSE)
  else()
    set(multiconfig TRUE)
  endif()

  # First get the file names of the libraries to be merged
  foreach(lib ${libs})
    get_target_property(libtype ${lib} TYPE)
    if(NOT libtype STREQUAL "STATIC_LIBRARY")
      message(FATAL_ERROR "Merge_static_libs can only process static libraries")
    endif()
  endforeach()
  message(STATUS "will be merging ${libfiles}")
  # Just to be sure: cleanup from duplicates
  if(multiconfig)
    foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
      list(REMOVE_DUPLICATES libfiles_${CONFIG_TYPE})
      set(libfiles ${libfiles} ${libfiles_${CONFIG_TYPE}})
    endforeach()
  endif()
  list(REMOVE_DUPLICATES libfiles)

  # Now the easy part for MSVC and for MAC
  if(MSVC)
    # lib.exe does the merging of libraries just need to conver the list into string
    foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
      set(flags "")
      foreach(lib ${libfiles_${CONFIG_TYPE}})
        set(flags "${flags} ${lib}")
      endforeach()
      string(TOUPPER "STATIC_LIBRARY_FLAGS_${CONFIG_TYPE}" PROPNAME)
      set_target_properties(${outlib} PROPERTIES ${PROPNAME} "${flags}")
    endforeach()

  elseif(APPLE)
    # Use OSX's libtool to merge archives
    if(multiconfig)
      message(FATAL_ERROR "Multiple configurations are not supported")
    endif()
    add_custom_command(TARGET ${outlib} POST_BUILD
      COMMAND rm ${outfile}
      COMMAND /usr/bin/libtool -static -o ${outfile}
      ${libfiles}
      )
  else()
    # general UNIX - need to "ar -xv" and then "ar -qc"
    if(multiconfig)
      message(FATAL_ERROR "Multiple configurations are not supported")
    endif()
    foreach(lib ${libfiles})
      set(objdir ${lib}.objdir)
      set(objlistfile "${lib}.objlist")
      file(MAKE_DIRECTORY ${objdir})
      list(APPEND extrafiles "${objdir}")
      file(RELATIVE_PATH relobjdir "${objdir}/.." "${objdir}")
      list(APPEND objectfilepattern "${relobjdir}/*${CMAKE_CXX_OUTPUT_EXTENSION}")
      file(RELATIVE_PATH reloutfile "${objdir}" "${lib}")
      if(${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/cmake.check_cache IS_NEWER_THAN ${objlistfile})
        add_custom_command(TARGET ${outlib} POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E echo "Running: ${CMAKE_AR} -xv ${reloutfile}"
          COMMAND ${CMAKE_AR} -xv "${reloutfile}" > "${objlistfile}"
          WORKING_DIRECTORY ${objdir})
      endif()
    endforeach()
    file(RELATIVE_PATH reloutfile "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}" "${outfile}")
    set(objlistfile "${reloutfile}.objlist")
    if(${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/cmake.check_cache IS_NEWER_THAN ${objlistfile})
      add_custom_command(TARGET ${outlib} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "Running: ${CMAKE_AR} -qvcs ${reloutfile}"
        COMMAND ${CMAKE_AR} -qvcs "${reloutfile}" ${objectfilepattern} > "${objlistfile}"
        WORKING_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    endif()
  endif()
  file(WRITE ${dummyfile}.base "const char* ${outlib}_sublibs=\"${libs}\";")
  add_custom_command(
    OUTPUT  ${dummyfile}
    COMMAND ${CMAKE_COMMAND}  -E copy ${dummyfile}.base ${dummyfile}
    DEPENDS ${libs} ${extrafiles}
    WORKING_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})

endfunction()
