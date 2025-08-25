
菜单：
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh)

bash <(curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh?$(date +%s)")


MOONTV安装：
bash <(curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/mootvinstall.sh?$(date +%s)")



https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh




  更新：mtv：
  bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/updatemtv.sh)

  
  cd /opt/moontv
  curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install.sh
  bash install.sh
  docker compose pull
  docker compose up -d


  
2： _rustdesk
  bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh)

   bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh?$(date +%s)")

  https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh




  🌀 zjsync（GitHub 文件自动同步）

功能：将 GitHub 仓库文件定时同步到 VPS 网站目录

用法：

zjsync.sh


按提示输入：

GitHub 文件地址（如 https://github.com/xxx/xxx/blob/main/file）

保存目录（默认 /var/www/zj）

保存文件名（默认自动加 .txt）

同步间隔分钟数（默认 5 分钟）

结果：文件会自动定时更新，可通过网站直接访问。
