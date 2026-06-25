# =====================================================================
# 1. 创建 /DATA 下的必要程序文件夹
# =====================================================================
echo "正在创建 /DATA 目录及相关文件夹..."
mkdir -p /DATA/docker/mt_photos/compose
mkdir -p /DATA/docker/mt_photos/config
mkdir -p /DATA/docker/mt_photos/upload
chmod -R 777 /DATA/docker/mt_photos

# =====================================================================
# 2. 切换到配置目录，并写入标准的 docker-compose.yml 文件
# =====================================================================
cd /DATA/docker/mt_photos/compose

echo "正在写入 docker-compose.yml 配置文件..."
cat << 'EOF' > docker-compose.yml
version: "3"

services:
  mtphotos:
    image: registry.cn-hangzhou.aliyuncs.com/mtphotos/mt-photos:latest
    container_name: mtphotos
    restart: always
    ports:
      - 8063:8063
    volumes:
      - /DATA/docker/mt_photos/config:/config
      - /DATA/docker/mt_photos/upload:/upload
      - /mnt/娱乐/嗯哼专用:/enheng
    environment:
      - TZ=Asia/Shanghai
      - LANG=C.UTF-8
    dns:
      - 114.114.114.114
    depends_on:
      - mtphotos_ai
      - mtphotos_face_api

  mtphotos_ai:
    image: registry.cn-hangzhou.aliyuncs.com/mtphotos/mt-photos-ai:onnx-latest
    container_name: mtphotos_ai
    restart: always
    ports:
      - 8060:8060
    environment:
      - API_AUTH_KEY=mt_photos_ai_extra

  mtphotos_face_api:
    image: crpi-gcuyquw9co62xzjn.cn-guangzhou.personal.cr.aliyuncs.com/devfox101/mt-photos-insightface-unofficial:latest
    container_name: mtphotos_face_api
    restart: always
    ports:
      - 8066:8066
    environment:
      - API_AUTH_KEY=mt_photos_ai_extra
EOF

# =====================================================================
# 3. 启动 Docker 容器
# =====================================================================
echo "文件夹与配置文件准备就绪，正在后台拉取并启动 MT Photos..."
docker compose up -d

echo "--------------------------------------------------------"
echo "🎉 部署完成！请等待 1-2 分钟让容器完全初始化。"
echo "👉 访问地址：http://[你的小主机IP]:8063"
echo "--------------------------------------------------------"
