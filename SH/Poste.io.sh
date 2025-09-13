# ========================
# 核心配置区域
# ========================
# 定义工作目录、数据目录、容器名等变量，方便集中管理和修改。

# ========================
# 辅助函数
# ========================
# DOCKER_COMPOSE()：兼容新旧版本的 Docker Compose。
# ensure_docker()：检查 Docker 是否安装。
# check_installed()：检查 Poste.io 容器是否已存在。
# read_compose_info()：从现有的 docker-compose.yml 文件中读取配置信息（域名、端口等）。
# get_server_ip()：获取服务器 IP 地址。
# show_info()：根据配置信息和 IP 地址，美观地展示服务访问信息。

# ========================
# 功能函数
# ========================
# install_poste()：
#   1. 调用 ensure_docker() 检查环境。
#   2. 检查是否已安装，如果已安装则直接显示信息。
#   3. 引导用户输入域名、管理员邮箱和密码。
#   4. 智能检测 80/443 端口占用情况，并设置备用端口。
#   5. 根据用户输入和端口设置，动态生成 docker-compose.yml 文件。
#   6. 使用 DOCKER_COMPOSE 命令启动服务。
#   7. 调用 show_info() 显示最终的访问信息。

# update_poste()：
#   1. 调用 ensure_docker() 检查环境。
#   2. 检查是否已安装。
#   3. 使用 DOCKER_COMPOSE pull 和 up -d 更新镜像和容器。
#   4. 调用 show_info() 显示更新后的信息。

# uninstall_poste()：
#   1. 调用 ensure_docker() 检查环境。
#   2. 检查是否已安装。
#   3. 交互式确认，避免误操作。
#   4. 使用 DOCKER_COMPOSE down 停止并删除容器。
#   5. 交互式确认是否删除数据目录。
#   6. 删除 compose 文件。

# ========================
# 主程序入口
# ========================
# 使用一个 while 循环和 case 语句，根据 check_installed() 的结果，显示不同的菜单选项，引导用户执行相应的函数。