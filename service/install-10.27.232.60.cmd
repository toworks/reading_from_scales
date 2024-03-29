@ECHO OFF
CLS

set NSSM=C:\bin\language\perl\perl\bin\nssm_64.exe
set SERVICE_NAME=reading_from_scales.10.27.232.60
set APP_PATH=C:\bin\language\perl32\perl\bin\perl.exe
set APP_DIR=C:\bin\daemon\reading_from_scales
set APP_PARAMETERS="%SERVICE_NAME%.pl"
set APP_DISPLAYNAME="ArcelorMittal.%SERVICE_NAME%"
set APP_DESCRIPTION="read data from 10.27.232.60"
set APP_ROTATEBYTES=26214400
set APP_ENVIRONMENTEXTRA="PATH=C:\bin\language\perl\c\bin;C:\bin\oracle\instantclient_19_10;%PATH%"
set APP_ENVIRONMENTEXTRA_2="ORACLE_HOME=C:\bin\oracle\instantclient_19_10"


:menu
ECHO.
ECHO ...............................................
ECHO PRESS 1, 2, 3 or 4 to EXIT.
ECHO ...............................................
ECHO.
ECHO 1 - Install Service
ECHO 2 - Remove Service
ECHO 3 - Set User Name and Password
ECHO 4 - EXIT
ECHO.

SET /P M="Type 1, 2, 3 or 4 then press ENTER: "
IF %M%==1 GOTO install
IF %M%==2 GOTO remove
IF %M%==3 GOTO user
IF %M%==4 GOTO eof

:install
%NSSM% install %SERVICE_NAME% %APP_PATH%
%NSSM% set %SERVICE_NAME% AppDirectory %APP_DIR%
%NSSM% set %SERVICE_NAME% AppParameters %APP_PARAMETERS%

%NSSM% set %SERVICE_NAME% DisplayName %APP_DISPLAYNAME%
%NSSM% set %SERVICE_NAME% Description %APP_DESCRIPTION%
%NSSM% set %SERVICE_NAME% Start SERVICE_AUTO_START

%NSSM% set %SERVICE_NAME% AppStderr %APP_DIR%\logs\%SERVICE_NAME%.err.log

%NSSM% set %SERVICE_NAME% AppRotateFiles 1
%NSSM% set %SERVICE_NAME% AppRotateOnline 1
%NSSM% set %SERVICE_NAME% AppRotateBytes %APP_ROTATEBYTES%
%NSSM% set %SERVICE_NAME% AppEnvironmentExtra %APP_ENVIRONMENTEXTRA%
GOTO menu

:remove
%NSSM% remove %SERVICE_NAME% confirm
GOTO menu

:user
ECHO.
set /P USER="Enter User Name: "
set /p PASS="Enter Password: "
%NSSM% set %SERVICE_NAME% ObjectName "%USER%" "%PASS%"
%NSSM% get %SERVICE_NAME% ObjectName
GOTO menu

:eof
