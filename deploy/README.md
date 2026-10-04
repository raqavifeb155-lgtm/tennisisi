# Размещение игры на сервере (Telegram Mini App)

Архив `tennis-web.zip` содержит:

- `web/` — сама игра (готовая веб-сборка);
- `deploy.sh` — ставит nginx и бесплатный HTTPS-сертификат (Let's Encrypt) и кладёт игру
  в `/var/www/tennis`;
- `nginx-tennis.conf` — настройки сайта.

## Установка (Debian/Ubuntu)

```bash
scp tennis-web.zip root@SERVER_IP:/root/
ssh root@SERVER_IP
apt-get install -y unzip && unzip -o tennis-web.zip -d tennis && cd tennis
sudo ./deploy.sh              # без своего домена: адрес будет https://<ip-через-дефисы>.sslip.io/
# или: sudo ./deploy.sh tennis.мой-домен.ru   (A-запись домена должна смотреть на сервер)
```

В конце скрипт напишет адрес вида `https://95-216-1-2.sslip.io/`.
Если порты 80/443 заняты чем-то, кроме nginx (например, VPN), скрипт остановится и
ничего не тронет.

## Новая версия игры

```bash
unzip -o tennis-web.zip -d tennis && sudo tennis/deploy.sh --update
```

## Подключение к боту

@BotFather → бот → Bot Settings → Mini Apps:

- **Main App** → Enable → вставить адрес;
- **Menu Button** → вставить адрес, текст кнопки: «Играть».
