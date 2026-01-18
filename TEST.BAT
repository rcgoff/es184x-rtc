@echo off
if %1==from goto from
echo Todos:
ds1307 /todos
if errorlevel 3 goto err3
if errorlevel 2 goto err2
if errorlevel 1 goto err1
echo errorlevel is 0
:from
echo Fromdos:
ds1307 /fromdos
if errorlevel 3 goto err3
if errorlevel 2 goto err2
if errorlevel 1 goto err1
echo errorlevel is 0
echo Noparms:
ds1307
if errorlevel 3 goto err3
if errorlevel 2 goto err2
if errorlevel 1 goto err1
echo errorlevel is 0
goto end
:err3
echo errorlevel is 3
goto end
:err2
echo errorlevel is 2
goto end
:err1
echo errorlevel is 1
goto end
:end
