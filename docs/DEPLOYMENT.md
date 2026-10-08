# Fn Project Kubernetes 部署操作文档

> 适用环境：2 台虚拟机的 kubeadm 集群（AlmaLinux 10.2，Kubernetes v1.37.1，containerd + docker 运行时，flannel CNI，无 ingress controller，节点无法直连 docker.io）
>
> 本文档记录了一次完整可复现的部署过程，包含全部踩坑点与解决方案。

---

## 1. 环境信息

| 节点 | IP | 角色 | 组件 |
|---|---|---|---|
| node71 | 192.168.74.71 | control-plane | kube-apiserver / etcd / kubectl |
| node72 | 192.168.74.71 → 72 | worker（业务全部调度在此） | fn 全部负载 |

| 本地工具 | 用途 |
|---|---|
| helm >= 3.8（需支持 OCI 依赖） | chart 渲染与安装 |
| kubeconfig（取自 node71 `/etc/kubernetes/admin.conf`） | helm 直连集群 |
| python3 + paramiko（可选） | 批量远程执行脚本（见 `.deploy/` 目录） |

---

## 2. 前置条件检查

```bash
# 两个节点都执行
kubectl get nodes                          # 双节点 Ready
systemctl is-active containerd docker      # 双运行时均在运行
docker --version                           # 宿主机需有 docker（fn runner 依赖它拉起函数容器）
crictl info > /dev/null && echo cri-ok     # containerd CRI 正常
```

网络连通性探测（决定镜像加速方案）：

```bash
curl -sI --max-time 8 https://registry-1.docker.io/v2/ -o /dev/null -w 'docker.io: %{http_code}\n'
curl -sI --max-time 8 https://docker.1ms.run/v2/        -o /dev/null -w '1ms.run: %{http_code}\n'
```

- `docker.io` 返回 `000`（不可达）、镜像站返回 `401`（可达，401 是匿名的正常响应）→ 必须配置镜像加速。
- 多备几个镜像站逐一验证：`docker.1ms.run`、`dockerproxy.net`、`docker.m.daocloud.io`（注意 daocloud 有白名单，fnproject 镜像不在其中）。

---

## 3. 配置镜像加速（两个节点都要执行）

### 3.1 containerd（kubelet 拉取业务镜像）

containerd 配置启用了 `config_path`（`/etc/containerd/certs.d`）时，**不能**在 `config.toml` 里写内联 `mirrors`，否则 CRI 插件加载失败、节点 NotReady。必须用 hosts.toml 方式：

```bash
# 注意：docker.io 和 registry-1.docker.io 是两个独立的匹配域，
# Bitnami chart 硬编码了 registry-1.docker.io，两个都要配
mkdir -p /etc/containerd/certs.d/docker.io /etc/containerd/certs.d/registry-1.docker.io

cat > /etc/containerd/certs.d/docker.io/hosts.toml <<'EOF'
server = "https://registry-1.docker.io"

[host."https://docker.1ms.run"]
  capabilities = ["pull", "resolve"]

[host."https://dockerproxy.net"]
  capabilities = ["pull", "resolve"]
EOF

cp /etc/containerd/certs.d/docker.io/hosts.toml \
   /etc/containerd/certs.d/registry-1.docker.io/hosts.toml

systemctl restart containerd
sleep 2 && systemctl is-active containerd

# 验证（任选一个镜像）
crictl pull bitnamilegacy/postgresql:17.6.0-debian-12-r4 && echo OK
```

> ⚠️ 若重启 containerd 后节点 NotReady，检查 `journalctl -u containerd | grep "failed to load plugin"`，出现 `mirrors cannot be set when config_path is provided` 即为上述冲突。

### 3.2 宿主机 docker（fn runner 用它拉起函数容器）

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://docker.1ms.run", "https://dockerproxy.net"]
}
EOF
systemctl restart docker
docker info | grep -A3 "Registry Mirrors"
```

---

## 4. 准备 chart 与依赖

```bash
git clone <本仓库> && cd fn-helm-master
```

子 chart 依赖（Bitnami OCI 仓库，需外网可达时）：

```bash
helm dependency build fn        # 生成 fn/charts/*.tgz 和 Chart.lock
```

外网不可达时，从可达的镜像仓库手动拉取后放入 `fn/charts/`：

```bash
helm pull oci://docker.m.daocloud.io/bitnamicharts/postgresql --version 16.7.27 --destination fn/charts
helm pull oci://docker.m.daocloud.io/bitnamicharts/redis    --version 23.1.3  --destination fn/charts
```

获取 kubeconfig（在能连集群 6443 端口的机器上执行）：

```bash
scp root@192.168.74.71:/etc/kubernetes/admin.conf .deploy/kubeconfig
export KUBECONFIG=$PWD/.deploy/kubeconfig
helm list -A    # 验证 helm 可连通集群
```

---

## 5. 部署

### 5.1 一键部署命令（评估环境小规模资源配置）

```bash
helm install fn fn --namespace fn --create-namespace \
  --set ingress.enabled=false \
  --set fn_api.service.type=NodePort \
  --set ui.service.type=NodePort \
  --set postgresql.image.repository=bitnamilegacy/postgresql \
  --set redis.image.repository=bitnamilegacy/redis \
  --set fn_runner.replicas=1 \
  --set fn_runner.resources.requests.memory=256Mi \
  --set fn_runner.resources.requests.cpu=100m \
  --set fn_api.resources.requests.memory=256Mi \
  --set fn_api.resources.requests.cpu=100m \
  --set fn_lb_runner.resources.requests.memory=256Mi \
  --set fn_lb_runner.resources.requests.cpu=100m \
  --set flow.resources.requests.memory=256Mi \
  --set flow.resources.requests.cpu=100m \
  --set ui.flowui.resources.requests.memory=128Mi \
  --set ui.flowui.resources.requests.cpu=50m
```

参数说明：

| 参数 | 说明 |
|---|---|
| `ingress.enabled=false` | 无 ingress controller，改用 NodePort 暴露 |
| `*.service.type=NodePort` | API/UI 通过节点端口访问 |
| `postgresql.image.repository=bitnamilegacy/*` | Bitnami 旧镜像仓库（原 `bitnami/*` 仓库 tag 已下架） |
| `fn_runner.replicas=1` | runner 使用 hostNetwork（固定 9191 端口），**每节点最多 1 个** |
| `resources.requests.*` | 按 8GB 内存节点裁剪，避免调度失败（可按需调回） |

> ⚠️ 升级时若使用 `--reuse-values`，新的 values.yaml **默认值不会生效**（helm 会沿用旧 release 的完整计算值），只对 `--set` 传入的项生效。改了 chart 默认值后应完整重跑上面的 install 参数而非 `--reuse-values`。

### 5.2 生产环境建议

- 修改 `postgresql.auth.password`（默认 `boomsauce`）或改用 `auth.existingSecret`
- 开启持久化：`--set postgresql.primary.persistence.enabled=true`
- 开启 TLS：安装 cert-manager 后设置 `tls.enabled=true`
- 安装 ingress-nginx 后恢复 `ingress.enabled=true`（默认值）

---

## 6. 部署后验证

### 6.1 组件状态

```bash
kubectl get pods -n fn
# 期望全部 Running：
#   fn-fn-*            2/2  （API + LB 同 Pod 双容器）
#   fn-fn-runner-*     1/1
#   fn-fn-flow-depl-*  1/1
#   fn-fn-ui-*         1/1
#   fn-postgresql-0    1/1
#   fn-redis-master-0  1/1

kubectl get svc -n fn    # 记录 fn-fn 的两个 NodePort（80=API，90=LB）与 fn-fn-ui 的 NodePort
```

### 6.2 API 连通性

```bash
API=http://192.168.74.72:30500   # 替换为实际 API NodePort
curl -s $API/version      # {"version":"0.3.770"}
curl -s $API/v2/apps      # {"items":[]}  —— 能列出说明 PostgreSQL 连接正常
```

### 6.3 函数端到端调用

1）准备一个实现 FDK 协议的函数镜像（见第 7 节），预拉取到 worker 节点宿主机 docker：

```bash
# 在 worker 节点执行
docker pull fnproject/fn-test-utils:latest   # 官方测试镜像（经镜像站），或自建的 FDK 函数镜像
```

2）创建应用与函数（通过 REST API）：

```bash
# 创建应用
curl -s -X POST $API/v2/apps -H 'Content-Type: application/json' -d '{"app":{"name":"demo"}}'

# 记录 appID
APP_ID=$(curl -s $API/v2/apps | python3 -c 'import sys,json;print(json.load(sys.stdin)["items"][0]["id"])')

# 创建函数（image 必须是 worker 节点宿主机 docker 上已有的）
curl -s -X POST $API/v2/fns -H 'Content-Type: application/json' -d '{
  "fn": {"name":"hello","app_id":"'"$APP_ID"'","image":"fn-test-utils:latest","memory":64,"timeout":30,"idle_timeout":30}
}'
# 记录返回的 id → FN_ID
```

3）调用函数（走 LB NodePort，格式：`/invoke/<FN_ID>`）：

```bash
LB=http://192.168.74.72:31431
curl -s -X POST $LB/invoke/<FN_ID> -d '{"hello":"fn"}'
# 成功时 fn-test-utils 会回显完整调用上下文（header/config/数据）
```

### 6.4 UI

浏览器访问 `http://<nodeIP>:<uiNodePort>/`（页面返回 200 即部署正常；UI 的 API 地址默认指向集群内部名，浏览器端联调需 ingress 或修改 `ui` 相关环境变量）。

---

## 7. 编写一个自己的函数

Fn 0.3.x 的热容器协议要求函数实现 **FDK listener**（容器不直接对外提供 HTTP 服务，而是通过 `/tmp/iofs` 下的 unix socket 与 runner 通信），普通 HTTP 服务镜像会报 `Container initialization timed out`。

以 Python FDK 为例：

**func.py**

```python
import fdk

def handler(ctx, data=None, loop=None):
    body = data.decode("utf-8") if data and len(data) > 0 else ""
    return {"message": "Hello from Fn!", "input": body}

if __name__ == "__main__":
    fdk.handle(handler)
```

**Dockerfile**

```dockerfile
FROM python:3.11-slim
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple fdk
WORKDIR /function
COPY func.py func.py
ENTRYPOINT ["python", "func.py"]
```

> ⚠️ 新版 fdk 不再支持 `@fdk.handle` 装饰器写法，必须使用 `fdk.handle(handler)` 的 `__main__` 形式，否则容器启动即退出。

构建与分发（在 worker 节点或 CI 环境）：

```bash
docker build -t <registry>/<ns>/my-func:1.0 .
docker push <registry>/<ns>/my-func:1.0     # 推送到节点可达的仓库
# 或离线环境：直接在 worker 节点 build，镜像留在宿主机 docker 中即可被 fn 使用
```

然后用第 6.3 节的 API 更新函数镜像并调用。

**标准开发流（有 fn CLI 的环境）**：

```bash
curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh
fn create context k8s --api-url http://<nodeIP>:<apiNodePort> --provider default
fn use context k8s
fn init --runtime python hello && cd hello
fn deploy --app demo        # 自动 build + push + 创建/更新函数
echo '{"a":1}' | fn invoke demo hello
```

---

## 8. 日常运维

```bash
# 查看日志
kubectl logs -n fn deploy/fn-fn -c api        --tail=100 -f
kubectl logs -n fn deploy/fn-fn -c runner-lb  --tail=100 -f
kubectl logs -n fn -l role=runner             --tail=100 -f

# 升级（完整重跑 install 的参数集）
helm upgrade fn fn --namespace fn --set ...（同 5.1）

# 扩容 runner（每节点 1 个；扩到 node71 需额外容忍 control-plane 污点）
helm upgrade fn fn --namespace fn --reuse-values --set fn_runner.replicas=2 \
  --set 'fn_runner.tolerations[0].key=node-role.kubernetes.io/control-plane' \
  --set 'fn_runner.tolerations[0].operator=Exists' \
  --set 'fn_runner.tolerations[0].effect=NoSchedule'

# 数据库持久化（重建 PG 有状态集，注意数据迁移）
helm upgrade fn fn ... --set postgresql.primary.persistence.enabled=true \
  --set postgresql.primary.persistence.size=20Gi

# 卸载
helm uninstall fn -n fn && kubectl delete ns fn
```

---

## 9. 故障排查手册（本文环境实际踩过的坑）

| 现象 | 原因 | 解决 |
|---|---|---|
| 重启 containerd 后节点 NotReady，CRI 插件加载失败 | `config.toml` 内联 `mirrors` 与 `config_path` 冲突 | 删除内联段，改用 `certs.d/<域>/hosts.toml` |
| bitnami 镜像 `registry-1.docker.io/...` 拉取卡死 | hosts.toml 只配了 `docker.io` 域，Bitnami chart 用 `registry-1.docker.io` 域 | 两个域都配 hosts.toml；已停滞的 Pod 删掉重建 |
| 镜像长期 `ContainerCreating` 不动 | `imagePullPolicy: Always` + 慢速镜像源，每次启动都重新解析 manifest | chart 默认已改 `IfNotPresent`；停滞拉取可删 Pod 重试，或宿主机 docker pull 后 `docker save \| ctr -n k8s.io images import -` 导入 |
| API 报 `pq: SSL is not enabled on the server` | lib/pq 默认 `sslmode=require`，Bitnami PG 未启 TLS | 连接串追加 `?sslmode=disable`（chart 已内置） |
| 同 Pod 的 `runner-lb` 容器崩溃：`bind: address already in use`（2376 端口） | fnserver 镜像内置 dind，双容器共享网络命名空间抢端口 | chart 新增 `dockerExternal: true` 跳过 dind，直连宿主机 docker socket |
| 调用报 `Container initialization timed out` | 函数容器在 docker0 网桥，Pod 网络不可达 | runner 开启 `hostNetwork: true`（chart 已内置） |
| 换了正确 FDK 镜像仍初始化失败 | 热协议的 listener socket 经 `/tmp/iofs` 传递，外接 docker 时 bind-mount 的是宿主机路径 | runner 挂载 hostPath `/tmp/iofs`（chart 已内置） |
| 函数容器秒退 | 镜像不是 FDK 协议（旧版 fn 镜像/普通 HTTP 服务） | 使用新版 FDK 构建（见第 7 节） |
| Flow 报 `Invalid db driver postgres` | flow 0.1.85 仅支持 mysql/sqlite3，项目已停止维护 | chart 默认让 flow 使用 sqlite（`flow.usePostgresql=false`）；如需 PG 支持需自行扩展 flow |
| trigger 创建 API 报错 | fn 0.3.770 触发器接口字段校验较严格 | 直接用 `/invoke/<FN_ID>` 调用，不依赖 trigger |

---

## 10. 已知限制

1. **特权容器**：fn API/LB/runner 需要 `privileged: true`（执行函数容器依赖宿主机 docker），安全敏感环境需自行评估。
2. **函数容器游离于 k8s 之外**：由宿主机 docker 直接管理，kubelet 不可见，资源限额依赖函数定义（`memory` 等）。
3. **每节点 1 个 runner**：hostNetwork 固定端口所致。
4. **UI 跨域访问**：无 ingress 时 UI 页面可打开，但浏览器到 API/Flow 的联动需自行代理。
5. **Fn 项目已归档**（fnproject/fn 最后更新约 2020 年，但官方镜像仍在推送更新版本），生产使用需评估维护风险。

---

## 附：本仓库新增/修改的文件

```
fn/Chart.yaml                     apiVersion v2、OCI 依赖（postgresql/redis）
fn/values.yaml                    全部可调参数（含 dockerExternal/hostNetwork 等新增项）
fn/templates/*.yaml               K8s 1.37 适配的模板（apps/v1、networking.k8s.io/v1、cert-manager.io/v1）
fn/charts/*.tgz                   内置子 chart 依赖（离线部署用）
docs/DEPLOYMENT.md                本文档
.deploy/                          远程部署/诊断脚本（ssh_exec.py、setup_containerd_mirror.sh 等）
```
