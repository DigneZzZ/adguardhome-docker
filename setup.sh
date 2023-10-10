#!/bin/bash

echo '  



      ██████╗ ██╗    ██╗ ██████╗ 
      ██╔══██╗██║    ██║██╔════╝ 
      ██║  ██║██║ █╗ ██║██║  ███╗
      ██║  ██║██║███╗██║██║   ██║
      ██████╔╝╚███╔███╔╝╚██████╔╝
      ╚═════╝  ╚══╝╚══╝  ╚═════╝ 
                           
BBBB  Y   Y     DDD  III  GGG  N   N EEEE ZZZZZ ZZZZZ ZZZZZ 
B   B  Y Y      D  D  I  G     NN  N E       Z     Z     Z  
BBBB    Y       D  D  I  G  GG N N N EEE    Z     Z     Z   
B   B   Y       D  D  I  G   G N  NN E     Z     Z     Z    
BBBB    Y       DDD  III  GGG  N   N EEEE ZZZZZ ZZZZZ ZZZZZ 
                                                            

'
sleep 2s


GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Получаем внешний IP-адрес
MYHOST_IP=$(curl -s https://checkip.amazonaws.com/) 
# Обновление пакетов
printf "\e[42mОбновление пакетов системы...\e[0m\n"
apt update
printf "\e[42mПакеты успешно обновлены.\e[0m\n"

# Установка Git
printf "\e[42mУстановка Git...\e[0m\n"
apt install git -y
printf "\e[42mGit успешно установлен.\e[0m\n"

# Клонирование репозитория
printf "\e[42mКлонирование репозитория dwg...\e[0m\n"
git clone https://github.com/dignezzz/adguardhome-docker.git temp

if [ ! -d "dwg" ]; then
  mkdir adguardhome-docker
  echo "Папка adguardhome-docker создана."
else
  echo "Папка adguardhome-docker уже существует."
fi

# копирование содержимого временной директории в целевую директорию с перезаписью существующих файлов и папок
cp -rf temp/* adguardhome-docker/

# удаление временной директории со всем ее содержимым
rm -rf temp
printf "\e[42mРепозиторий adguardhome-docker успешно клонирован до актуальной версии из репозитория автора.\e[0m\n"

# Установка прав на директорию tools
printf "\e[42mУстановка прав на директорию adguardhome-docker...\e[0m\n"
chmod +x -R adguardhome-docker
printf "\e[42mПрава на директорию adguardhome-docker успешно установлены.\e[0m\n"

# Переходим в папку DWG
printf "\e[42mПереходим в папку adguardhome-docker...\e[0m\n"
cd adguardhome-docker
printf "\e[42mПерешли в папку adguardhome-docker\e[0m\n"

# Устанавливаем редактор Nano
if ! command -v nano &> /dev/null
then
    read -p "Хотите установить текстовый редактор Nano? (y/n) " INSTALL_NANO
    if [ "$INSTALL_NANO" == "y" ]; then
        apt-get update
        apt-get install -y nano
    fi
else
    echo "Текстовый редактор Nano уже установлен."
fi
printf "\e[42mЗапускаем скрипт для установки Docker и Docker-compose...\e[0m\n"
./tools/docker.sh
printf "\e[42mЗакончили выполнение скрипта\e[0m\n"


# Устанавливаем apache2-utils, если она не установлена
if ! [ -x "$(command -v htpasswd)" ]; then
  echo -e "${RED}Установка apache2-utils...${NC}" >&2
   apt-get update
   apt-get install apache2-utils -y
fi


# Если логин не введен, устанавливаем логин по умолчанию "admin"
while true; do
  echo -e "${YELLOW}Введите логин (только латинские буквы и цифры), если пропустить шаг будет задан логин admin:${NC}"  
  read username
  if [ -z "$username" ]; then
    username="admin"
    break
  fi
  if ! [[ "$username" =~ [^a-zA-Z0-9] ]]; then
    break
  else
    echo -e "${RED}Логин должен содержать только латинские буквы и цифры.${NC}"
  fi
done

# Запрашиваем у пользователя пароль
while true; do
  echo -e "${YELLOW}Введите пароль (если нажать Enter, пароль будет задан по умолчанию admin):${NC}"  
  read password
  if [ -z "$password" ]; then
    password="admin"
    break
  fi
  if ! [[ "$password" =~ [^a-zA-Z0-9] ]]; then
    break
  else
    echo -e "${RED}Пароль должен содержать латинские буквы верхнего и нижнего регистра, цифры.${NC}"
  fi
done

# Генерируем хеш пароля с помощью htpasswd из пакета apache2-utils
hashed_password=$(htpasswd -nbB $username "$password" | cut -d ":" -f 2)

# Экранируем символы / и & в hashed_password
hashed_password=$(echo "$hashed_password" | sed -e 's/[\/&]/\\&/g')

# Проверяем наличие файла AdGuardHome.yaml и его доступность для записи
if [ ! -w "conf/AdGuardHome.yaml" ]; then
  echo -e "${RED}Файл conf/AdGuardHome.yaml не существует или не доступен для записи.${NC}" >&2
  exit 1
fi

# Записываем связку логина и зашифрованного пароля в файл conf/AdGuardHome.yaml
if 
  sed -i -E "s/- name: .*/- name: $username/g" conf/AdGuardHome.yaml &&
  sed -i -E "s/password: .*/password: $hashed_password/g" conf/AdGuardHome.yaml
then
  # Выводим сообщение об успешной записи связки логина и пароля в файл
  echo -e "${GREEN}Связка логина и пароля успешно записана в файл conf/AdGuardHome.yaml${NC}"
else
  echo -e "${RED}Не удалось записать связку логина и пароля в файл conf/AdGuardHome.yaml.${NC}" >&2
  exit 1
fi

# Запускаем docker-compose
docker compose up -d
