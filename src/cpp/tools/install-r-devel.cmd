REM This script installs R-devel from source on Windows.
REM Update the variables up here as new versions of R are released;
REM we attempt to build from tarballs.
REM
REM This script assumes you have 'wget' on your path, as it
REM is used to download. You can find a binary here:
REM
REM     https://eternallybored.org/misc/wget/wget64.exe 
REM
REM Ensure that this is run from a command prompt with administrator
REM privileges! Otherwise, files can be created _without_ read permissions
REM and all manner of weird failures can and will happen.
REM
REM If you find that the build is failing for strange reason, ensure that
REM everyone has access to the source tree with
REM
REM     icacls "." /grant Everyone:(F) /T
REM
REM to just indiscriminately give everyone full access to the folder.

REM ---------------------------------
REM - BEGIN CONFIGURATION VARIABLES -
REM ---------------------------------

IF NOT DEFINED WGET (
	SET "WGET=wget"
)

IF NOT DEFINED SVN (
	SET "SVN=svn"
)

IF NOT DEFINED ROOT_DIR (
	SET "ROOT_DIR=C:\R-src"
)

if NOT DEFINED RTOOLS_DIR (
	SET "RTOOLS_DIR=C:\Rtools"
)

IF NOT DEFINED RTOOLS_BIN_DIR (
	SET "RTOOLS_BIN_DIR=C:\Rtools\bin"
)

IF NOT DEFINED TMPDIR (
	SET "TMPDIR=C:\tmp"
)

REM -------------------------------
REM - END CONFIGURATION VARIABLES -
REM -------------------------------

SET "CRAN=http://cran.r-project.org"
SET "RTOOLS_VERSION=33"
SET "R_HOME=%ROOT_DIR%\trunk"

REM Ensure that some essential tools are on the PATH.
WHERE /Q %WGET% || (
	ECHO 'wget' not found on PATH; exiting
	exit /b
)

where /Q %SVN% || (
	ECHO 'svn' not found on PATH; exiting
	exit /b
)


REM Set the current directory.
if not exist "%ROOT_DIR%" (
	mkdir "%ROOT_DIR%"
)
cd "%ROOT_DIR%"
SET OLDPATH=%PATH%

REM URI to RTools.exe
SET "RTOOLS_URL=%CRAN%/bin/windows/Rtools/Rtools%RTOOLS_VERSION%.exe"

REM URI to updated toolchains.
REM TODO Remove this once Rtools stabilized.
SET "TOOLCHAIN_BASE=http://www.stats.uwo.ca/faculty/murdoch/temp"
SET "TOOLCHAIN_32BIT=%TOOLCHAIN_BASE%/mingw32mingw32_gcc-4.9.2.toolchain.tar.gz"
SET "TOOLCHAIN_64BIT=%TOOLCHAIN_BASE%/mingw32mingw64_gcc-4.9.2.toolchain.tar.gz"

REM Download Rtools, and the updated toolchains.
REM TODO: Downloading the upgraded toolchains will not be necessary
REM once RTOOLS has been fully stabilized.
wget -c %RTOOLS_URL%
wget -c %TOOLCHAIN_32BIT%
wget -c %TOOLCHAIN_64BIT%

REM Install Rtools.
SET "RTOOLS_INSTALLER=.\Rtools%RTOOLS_VERSION%.exe"
"%RTOOLS_INSTALLER%" /VERYSILENT

REM Put Rtools on the path.
SET "PATH=%RTOOLS_BIN_DIR%;%PATH%"

REM Overwrite the toolchain paths with our own.
rmdir /S /Q %RTOOLS_DIR%\gcc492_32
rmdir /S /Q %RTOOLS_DIR%\gcc492_64

REM Untar the downloaded toolchains and move them.
tar -zxvf mingw32mingw32_gcc-4.9.2.toolchain.tar.gz
move mingw32 %RTOOLS_DIR%\gcc492_32

tar -zxvf mingw32mingw64_gcc-4.9.2.toolchain.tar.gz
move mingw64 %RTOOLS_DIR%\gcc492_64

REM Download the R sources. Get the latest R-devel sources using SVN.
REM
REM If you need a Windows SVN client, you can download SlikSVN here:
REM
REM     https://sliksvn.com/download/
REM
REM Be sure to place the installed binary directory on your PATH.
svn checkout https://svn.r-project.org/R/trunk/
cd trunk

REM Copy in the 'extras' for a 64bit build. This includes tcltk
REM plus some other libraries. Note that the R64 directory should
REM have been populated by the RTools installation.
xcopy /E /Y C:\R64 %R_HOME%\trunk\

REM Ensure the temporary directory exists.
if not exist "%TMPDIR%" (
	mkdir "%TMPDIR%"
)

REM Create the binary directories that will eventually
REM be populated ourselves, rather than letting the
REM bundled cygwin toolkit do it. The RTools 'mkdir'
REM apparently can build directories without read
REM permissions, which will cause any attempt to link
REM to DLLs within those folders to fail.
rmdir /S /Q bin
mkdir bin\i386
mkdir bin\x64

REM Move into the root directory for 'Windows' builds.
cd src\gnuwin32

REM Since we're building from source, we need to get Recommended packages.
make rsync-recommended

REM Download external software -- libpng, libgsl, and so on.
make rsync-extsoft

REM Look at MkRules.dist and if settings need to be altered, copy it to
REM MkRules.local and edit the settings there.
if exist MkRules.local (
	rm MkRules.local
)
cp MkRules.dist MkRules.local

REM Don't use MIKTEX.
sed -i 's/^MIKTEX = TRUE//g' MkRules.local

REM Ensure that the make rules are properly set -- need to
REM point to 'extsoft'.
sed -i 's/^# LOCAL_SOFT/LOCAL_SOFT/g' MkRules.local
sed -i 's/^# EXT_LIBS/EXT_LIBS/g' MkRules.local

REM Make it!
REM For this part, we ensure only Rtools is on the PATH. This
REM is important as if the wrong command line utilites are picked
REM up things can fail for strange reason.
SET "PATH=C:\Windows\system32;C:\Windows;C:\Rtools\bin"
make clean

REM We need to build all of the R library DLLs first, and then
REM copy them to locations where R will find them. Not sure why
REM this step is necessary.
make rlibs
cp ..\extra\graphapp\Rgraphapp.dll Rgraphapp.dll
cp ..\extra\win_iconv\Riconv.dll Riconv.dll

REM Now we should be able to build R + recommended packages.
make all recommended

REM Clean up.
SET "PATH=%OLDPATH%"
