@echo off

:: ---------------------------------------------------------------------------
:: Windows build.
::
:: Visual Studio is the only Windows build system upstream supports: the Win32
:: code paths are guarded by the WIN32 macro, which only the MSVC project in
:: win/sac.vcxproj defines (the "mingw" branch of configure.ac defines MINGW,
:: which nothing in the sources uses).  That project is therefore the source of
:: truth for which files make up the Windows program, and it is what is built
:: here.
::
:: The project was written for Visual Studio 2013, targets Win32 only, and
:: expects prebuilt 32 bit libxml2/iconv/zlib binaries under win/lib, so
:: patches/win-x64.patch retargets it to x64 and makes it link against the
:: conda-forge libxml2/zlib import libraries instead.
::
:: Upstream's Windows build produces the sac interpreter only.  The utilities in
:: utils/ and the sacio/libmseed/evalresp libraries use POSIX APIs (unistd.h,
:: getopt, ...) and are not part of the Visual Studio project, so they are not
:: built here either.
:: ---------------------------------------------------------------------------

:: The conda-forge MSVC activation exports the toolset of the installed Visual
:: Studio; v143 is the one shipped with Visual Studio 2022.
if not defined CMAKE_GENERATOR_TOOLSET set "CMAKE_GENERATOR_TOOLSET=v143"

:: Let the compiler and linker find the conda-forge headers and import
:: libraries (libxml2.lib, zlib.lib) that the patched project links against.
:: The sources include the libxml2 headers as <libxml/...>, which live in the
:: libxml2 subdirectory of the include directory, as pkg-config reports on Unix.
set "INCLUDE=%LIBRARY_INC%\libxml2;%LIBRARY_INC%;%INCLUDE%"
set "LIB=%LIBRARY_LIB%;%LIB%"

:: --- locate MSBuild --------------------------------------------------------
set "MSBUILD_EXE=%VSINSTALLDIR%MSBuild\%VS_VERSION%\Bin\MSBuild.exe"
if exist "%MSBUILD_EXE%" goto have_msbuild

set "PF86=%ProgramFiles(x86)%"
set "VSWHERE=%PF86%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto no_msbuild

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set "MSBUILD_EXE=%%i"
if exist "%MSBUILD_EXE%" goto have_msbuild

:no_msbuild
echo Could not locate MSBuild.exe
exit /b 1

:have_msbuild

:: Upstream's Visual Studio build compiles this hand maintained header instead
:: of the one autoconf generates (it defines WIN32, SACAUX, the missing libc
:: functions, ...).
copy /y inc\config_win.h inc\config.h
if errorlevel 1 exit /b 1

"%MSBUILD_EXE%" win\sac.vcxproj /nologo /m ^
    /p:Configuration=Release ^
    /p:Platform=x64 ^
    /p:PlatformToolset=%CMAKE_GENERATOR_TOOLSET% ^
    /p:WindowsTargetPlatformVersion=10.0
if errorlevel 1 exit /b 1

for /r "%SRC_DIR%\win" %%f in (sac.exe) do set "SAC_EXE=%%f"
if not defined SAC_EXE goto no_sac_exe
goto have_sac_exe

:no_sac_exe
echo MSBuild did not produce sac.exe
exit /b 1

:have_sac_exe

:: --- install ---------------------------------------------------------------
copy /y "%SAC_EXE%" "%LIBRARY_BIN%\sac.exe"
if errorlevel 1 exit /b 1

:: src/co/zbasename.c looks for the auxiliary data in a "winaux" directory next
:: to sac.exe, which is also where upstream's Inno Setup installer puts it.
:: ("aux" cannot be used: it is a reserved device name on Windows and cannot
:: even be created.)
xcopy /e /i /q /y aux "%LIBRARY_BIN%\winaux"
if errorlevel 1 exit /b 1

xcopy /e /i /q /y macros "%PREFIX%\macros"
if errorlevel 1 exit /b 1

copy /y include\sac.h "%LIBRARY_INC%\sac.h"
if errorlevel 1 exit /b 1
copy /y include\sacf.h "%LIBRARY_INC%\sacf.h"
if errorlevel 1 exit /b 1
copy /y include\evalresp.h "%LIBRARY_INC%\evalresp.h"
if errorlevel 1 exit /b 1
copy /y sacio\sacio.h "%LIBRARY_INC%\sacio.h"
if errorlevel 1 exit /b 1
copy /y sacio\timespec.h "%LIBRARY_INC%\timespec.h"
if errorlevel 1 exit /b 1
