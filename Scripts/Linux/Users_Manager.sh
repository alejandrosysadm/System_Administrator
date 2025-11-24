#!/bin/bash
# Crear usuario
sudo useradd -m nuevo_usuario
# Cambiar contraseña
echo "nuevo_usuario:Password123" | sudo chpasswd
