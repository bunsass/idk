@echo off
title Install Python Packages
echo ==============================
echo Installing required packages...
echo ==============================

python -m pip install --upgrade pip

python -m pip install altgraph certifi charset-normalizer click colorama contourpy customtkinter cycler darkdetect decompyle3 fonttools idna keyboard kiwisolver matplotlib numpy packaging pandas patsy pefile pillow psutil pyinstaller pyinstaller-hooks-contrib pyparsing python-dateutil pytz pywin32 pywin32-ctypes requests scipy setuptools six spark-parser statsmodels tls-client typing_extensions tzdata uncompyle6 urllib3 WMI xdis

echo.
echo ==============================
echo Installation Complete!
echo ==============================
pause