@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo === Gerando o site do Ortodoctor (pode levar alguns minutos) ===
echo.
call flutter pub get || goto erro
call flutter build web --release || goto erro
echo.
echo === Pronto! ===
echo A pasta do site e: %~dp0build\web
echo Agora arraste essa pasta "web" para https://app.netlify.com/drop
echo (ou, se o site ja existe, para a aba Deploys do seu site no Netlify).
explorer "%~dp0build"
pause
exit /b 0
:erro
echo.
echo Deu erro. Tire um print desta janela e mande para o Claude.
pause
exit /b 1
