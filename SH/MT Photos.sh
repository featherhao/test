# 1. 彻底清理之前冲突的残留容器
docker stop mtphotos mtphotos_ai mtphotos_face_api 2>/dev/null
docker rm mtphotos mtphotos_ai mtphotos_face_api 2>/dev/null

# 2. 创建文件夹并赋予正确的权限
mkdir -p /DATA/docker/mt_photos/compose
mkdir -p /DATA/docker/mt_photos/config/pgsql  # 👈 提前创建好 pgsql 目录
mkdir -p /DATA/docker/mt_photos/upload
chmod -R 777 /DATA/docker/mt_photos

# 💡【核心修正】单独收紧数据库目录权限，防止底层 PostgreSQL 报权限错误
chmod -R 700 /DATA/docker/mt_photos/config/pgsql
chown -R 103:105 /DATA/docker/mt_photos/config/pgsql

# 3. 进入目录并写入干净的纯文本配置
cd /DATA/docker/mt_photos/compose

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

# 4. 启动容器
docker compose up -d

echo "--------------------------------------------------------"
echo "🎉 部署完成！请等待 1-2 分钟让容器完全初始化。"
echo "👉 访问地址：http://[你的小主机IP]:8063"
echo "--------------------------------------------------------"
