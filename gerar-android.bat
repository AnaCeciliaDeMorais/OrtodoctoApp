@echo off
chcp 65001 >nul
cd /d "%~dp0"
if not exist "android\key.properties" (
  echo.
  echo Falta o arquivo android\key.properties com a chave de assinatura.
  echo Siga o passo "Criar a chave de assinatura" do guia antes de gerar o app.
  pause
  exit /b 1
)
echo.
echo === Gerando o app Android para a Google Play (pode levar alguns minutos) ===
echo.
call flutter pub get || goto erro
call flutter build appbundle --release || goto erro
echo.
echo === Pronto! ===
echo O arquivo para enviar na Google Play e:
echo %~dp0build\app\outputs\bundle\release\app-release.aab
explorer "%~dp0build\app\outputs\bundle\release"
pause
exit /b 0
:erro
echo.
echo Deu erro. Tire um print desta janela e mande para o Claude.
pause
exit /b 1
