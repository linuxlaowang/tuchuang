## 安装prometheus server
使用外网访问官网：https://prometheus.io/
### 二进制安装
Get started-------Download the latest release---------选择适配的二进制安装包即可。
```
export VERSION=3.7.0
wget https://github.com/prometheus/prometheus/releases/download/v3.7.0-rc.0/prometheus-3.7.0-rc.0.darwin-amd64.tar.gz
```
解压，并可以把prometheus的相关命令。添加到系统环境变量
解压后，当前目录会有一个配置文件：prometheus.yml
作为一个时间序列数据库，其采集的数据会以文件的形式存储在本地中，默认为data/。需要手动创建
```
mkdir -p data
```
用户也可以使用参数： `--storage.tsdb.path="data/"` 修改本地数据存储的路径

启动prometheus服务，其会默认加载当前路径下的prometheus.yaml文件
```
./prometheus
```
### 容器安装
Get started-------Download the latest release---------Docker images----选择通用的X86架构： prom/prometheus----Tags-----copy拉取命令：docker pull prom/prometheus:latest

运行
```shell
docker run --name prometheus -d -p 127.0.0.1:9090:9090 prom/prometheus
```
#解释：   
#--name，通过指定名称，后续可以更方便地管理这个容器，比如使用 docker stop prometheus 来停止该容器，或者使用 docker rm prometheus 来删除它
#-d：表示以后台守护进程的方式运行容器。使用这个参数后，容器会在后台运行，不会占用当前终端，用户可以继续在终端执行其他命令。
#p 127.0.0.1:9090:9090：这是端口映射参数。它的作用是将容器内部的端口映射到宿主机的端口上。格式为 -p [宿主机IP]:[宿主机端口]:[容器端口] 。这里 127.0.0.1 表示只允许通过本地回环地址访问容器的 9090 端口，即只有宿主机自身能访问容器中 Prometheus 提供服务的 9090 端口，外部网络无法访问。如果想要外部网络也能访问，可以写成 -p 0.0.0.0:9090:9090 ，表示将容器的 9090 端口映射到宿主机所有可用 IP 地址的 9090 端口上。
```
docker run -p 9090:9090 -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
```
#解释：  
#-p 9090:9090：同样是端口映射参数，这里省略了宿主机 IP ，默认是 0.0.0.0 ，即把容器内部的 9090 端口映射到宿主机所有可用 IP 地址的 9090 端口，外部网络只要能访问宿主机的 IP ，就可以通过 宿主机IP:9090 来访问容器中 Prometheus 提供的服务。
#-v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml：-v 是 Docker 用于挂载卷（Volume） 的参数，格式为 -v [宿主机路径]:[容器内路径] 。
#作用：
#数据持久化：容器是一种轻量级、可销毁的运行环境，当容器被删除或重新创建时，容器内部的数据默认会丢失。通过挂载宿主机的文件到容器内，即使容器被删除，宿主机上的数据依然存在。下次重新创建容器并挂载相同的文件时，容器可以继续使用之前的配置。
#方便配置修改：可以直接在宿主机上编辑 /etc/prometheus/prometheus.yml 文件，修改 Prometheus 的配置，而不需要进入容器内部进行操作。修改保存后，容器内的 Prometheus 会读取更新后的配置文件，实现配置的动态更新。
#总的来说， -v 参数提供了一种在宿主机和容器之间共享数据的机制，对于需要持久化数据或者方便配置管理的应用（如 Prometheus 这种依赖配置文件的监控系统）非常重要。
综上，启动完成后，可以通过http://localhost:9090  访问prometheus的UI界面。
## 基础概念
### PromQL 数据理解:
#### 样本  
Prometheus 会按照固定的时间间隔（比如每 15 秒一次，这个间隔叫 **scrape_interval**）从目标（如服务器、应用）采集指标数据，每次采集到的一个**具体数值 + 时间戳**，就是一个 “样本”。  
例如，对于 node_cpu{mode="idle"} 这个指标（CPU 空闲时间累计值），假设采集间隔是 15 秒，那么 2 分钟（120 秒）内会产生 8 个样本（120/15=8），每个样本包含：
时间戳（如 10:00:00、10:00:15、10:00:30 ... 10:01:45）；
对应的值（如 1000 秒、1002 秒、1004 秒 ... 1016 秒，随时间递增）。
##### 窗口内最后两个样本
假设你用 irate(node_cpu{mode="idle"}[2m])，时间窗口是 [2m]（最近 2 分钟）：
Prometheus 会先找出这 2 分钟内所有采集到的样本（共 8 个，如上面的例子）；
“最后两个样本” 就是这 8 个样本中时间戳最新的两个，比如：
倒数第二个样本：时间 10:01:30，值 1014 秒；
最后一个样本：时间 10:01:45，值 1016 秒。
##### 场景使用
irate() 的计算逻辑非常简单：只看最后两个样本的 “差值” 和 “时间差”，公式为：  
```
增长率 = (最后一个样本值 - 倒数第二个样本值) / (最后一个样本时间 - 倒数第二个样本时间)
```
总结:  
“最后两个样本” 就是 Prometheus 在你指定的时间窗口内，最新采集的两个指标数据点（包含值和时间戳）。irate() 只基于这两个点计算增长率，因此能快速捕捉窗口末尾的突发变化，但结果受这两个点的影响极大，波动较明显。
这也是为什么 irate() 适合 “实时告警”（能快速发现异常），而 rate() 适合 “趋势监控”（结果更稳定）。
### 数据模型
Prometheus 存储的是时序数据, 即按照相同时序(相同的名字和标签)，以时间维度存储连续的数据的集合
数据模型
    * 时序索引
    * 时序样本
    * 格式
#### 时序索引
时序(time series) 是由名字(Metric)，以及一组 key/value 标签定义的，具有相同的名字以及标签属于相同时序。  
时序的名字:  
由 ASCII 字符，数字，下划线，以及冒号组成，它必须满足正则表达式 ` [a-zA-Z_:][a-zA-Z0-9_:]* `, 其名字应该具有语义化，一般表示一个可以度量的指标，例如 http_requests_total , 可以表示http 请求的总数。
时序的标签：  
可以使 Prometheus 的数据更加丰富，能够区分具体不同的实例，例如 http_requests_total{method="POST"} 可以表示所有http 中的 POST 请求  
标签名称由 ASCII 字符，数字，以及下划线组成， 其中 __ 开头，属于 Prometheus 保留，标签的值可以是任何 Unicode 字符，支
持中文。
#### 时序样本  
按照某个时序以时间维度采集的数据，称之为样本，其值包含：
* 一个 float64 值
* 一个毫秒级的 unix 时间戳
格式：  #Prometheus 时序格式与 OpenTSDB 相似
`<metric name>{<label name>=<label value>,...} ` #其中包含时序名字以及时序的标签。

### 四种 Metric Type
时序4种类型
    * Counter
    * Gauge
    * Histogram
    * Summary
    * Histogram vs summary
Prometheus 时序数据分为 Counter, Gauge, Histogram,Summary 四种类型
#### Counter
Counter（计数器）：  
查询时通常用 rate()/irate() 计算「单位时间增长率」（比直接查原始值更有意义）。  
**核心简化：Counter 就是「只会往上加的计数器」**
1. 你可以把 Counter 想象成：  
* 家里的电表（只增不减，记录总用电量）；
* 汽车的里程表（只增不减，记录总行驶里程）；
* 网站的总访问次数统计（每来一个访客，数字 + 1）。  
Prometheus 里的 Counter 完全一样：只有「加 1」或「加一个正数」的操作，永远不会减少，服务重启后才会重置为 0。

2. 部署node_exporter，解压后启动`./node_exporter`
指标暴露  
浏览器访问 http://服务器IP:9100/metrics，会看到一大堆指标，其中很多就是 Counter 类型！  
在 http://服务器IP:9100/metrics 页面，搜索带 `_total `后缀的指标（Prometheus 约定：Counter 指标名必须以 _total 结尾），比如：
node_cpu_seconds_total：CPU 累计运行秒数（每个 CPU 核心单独统计，只增不减）；
node_network_transmit_bytes_total：网卡累计发送字节数（只增不减）；
node_http_requests_total：node_exporter 自身接收的 HTTP 请求总数（每访问一次 /metrics，数字 + 1）。

3. 下载prometheus安装包后，修改`prometheus.yml` 配置，添加`node_exporter`的监控指标
```
scrape_configs:
  - job_name: "node"
    static_configs:
      - targets: ["服务器IP:9100"]  # 指向 node_exporter 的地址
```
启动 Prometheus：./prometheus --config.file=prometheus.yml，访问 http://PrometheusIP:9090 进入 UI。

4. 查询原始值
搜索`node_http_requests_total` 

5. 计算增长率（Counter 核心用法）
原始累计数意义不大（比如数字 100，不知道是 1 秒内涨的还是 1 小时内涨的），所以通常用 rate() 函数计算「单位时间内的增长率」（比如 QPS）：  
查询：rate(node_http_requests_total[5m])
意思：「过去 5 分钟内，node_http_requests_total 指标的平均每秒增长率」（也就是平均 QPS）；
结果：比如 0.0167，代表平均每秒约 0.017 次请求（即每分钟 1 次）；
如果你频繁刷新 /metrics 页面，这个数值会明显上涨。
#“刷新 /metrics 页面，rate() 上涨”，是因为你访问的是 “node_exporter 所在机器的 /metrics 接口”，触发的是该机器上 node_exporter 的指标增长。
#### Gauge
1. Gauge（仪表盘）是 Prometheus 中最灵活的指标类型，核心特点是 可增可减、可直接设置数值（不像 Counter 只能累加），适合统计「瞬时状态值」—— 比如当前内存使用率、在线用户数、温度等，数值会随时间动态变化（涨或跌都有可能）。
核心简化：Gauge 就是「能实时显示当前值的仪表盘」  
你可以把 Gauge 想象成：  
* 汽车的时速表（实时显示当前速度，可快可慢）；
* 手机的电量百分比（实时显示剩余电量，只会跌不会涨，但符合 “瞬时状态”）；
* 电梯的当前楼层（实时变化，可上可下）；
* 服务器的当前内存使用率（随程序运行涨涨跌跌）。
核心区别于 Counter：Gauge 关注「现在是什么值」，Counter 关注「累计了多少」。

2. 举例
node_exporter 只会暴露最基础的原始指标（如 node_memory_MemTotal_bytes、node_memory_MemAvailable_bytes 等），而 “内存使用率百分比” 是通过这些原始指标计算推导出来的，并不是一个直接存在的原生指标。  
含义：(1- 可用内存/ 总内存)* 100 
```
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)*100
```
3. 在服务器上执行一个耗内存的命令（比如 dd if=/dev/zero of=/tmp/test bs=1G count=2，创建 2G 临时文件）；
4. 刷新页面，数值上涨：node_memory_usage_percent 68.7（内存使用率涨到 68.7%）；
5. 删除临时文件（rm /tmp/test），再刷新页面，数值下跌：`node_memory_usage_percent 36.1`（内存使用率回落）。
注意：node_memory_usage_percent 这些可能属于第三方封装。可能在个人部署的prometheus 搜索不到，需要自行计算。当然，也有可能是访问的url不通。
`http://服务器IP:9100/metrics（node_exporter 接口）`
`http://10.1.28.200:9090/graph（Prometheus UI）`
识别：指标名不带 _total，类型是 gauge（在 /metrics 页面能看到 # TYPE 指标名 gauge）
#### Histogram(直方图)
Histogram 由 `<basename>_bucket{le="<upper inclusive bound>"}` ， `<basename>_bucket{le="+Inf"} `,
`<basename>_sum` ， `<basename>_count` 组成，主要用于表示一段时间范围内对数据进行采样，（通常是请求持续时间或响应大小），并能够对其指定区间以及总数进行统计，通常我们用它计算分位数的直方图。
1. Histogram 就像 超市的 “商品价格区间统计”：  
* 超市想知道 “不同价格段的商品有多少件”，于是划分区间：0~10元、10~50元、50~100元、100元以上；
* 统计后发现：0~10 元有 20 件，10~50 元有 50 件，50~100 元有 15 件，100 元以上有 5 件；
最终能清楚看到 “大部分商品集中在 10~50 元”—— 这就是 Histogram 的核心作用：看数据的分布范围。  
对应到 Prometheus 中：
* 「价格区间」= Histogram 的 Buckets（区间）；
* 「每个区间的商品数」= Buckets 对应的样本数；
* 「所有商品总数」= Histogram 的 _count（20+50+15+5=90）；
* 「所有商品总价」= Histogram 的 _sum（可算平均价格）。
2. 指标：node_disk_io_time_seconds_total—— 统计「磁盘 I/O 耗时的分布」
第三方或者去 http://服务器IP:9100/metrics，搜索node_disk_io_time_seconds_total_bucket
```
# HELP node_disk_io_time_seconds_total 磁盘 I/O 操作耗时的分布
# TYPE node_disk_io_time_seconds_total histogram
node_disk_io_time_seconds_total_bucket{device="vda",le="0.005"} 12
node_disk_io_time_seconds_total_bucket{device="vda",le="0.01"} 25
node_disk_io_time_seconds_total_bucket{device="vda",le="0.025"} 48
node_disk_io_time_seconds_total_bucket{device="vda",le="0.05"} 63
node_disk_io_time_seconds_total_bucket{device="vda",le="0.1"} 75
node_disk_io_time_seconds_total_bucket{device="vda",le="+Inf"} 80
node_disk_io_time_seconds_total_count 80
node_disk_io_time_seconds_total_sum 3.2
```
Buckets 区间统计（带 _bucket 后缀）： 
* le="0.005"：耗时 小于 0.005 秒 的磁盘 I/O 操作有 12 次；
* le="0.01"：耗时 小于 0.01 秒 的有 25 次（包含前一个区间的 12 次）；
* le="0.1"：耗时 小于 0.1 秒 的有 75 次；
* le="+Inf"：所有磁盘 I/O 操作（不管耗时多久），共 80 次（和下面的 _count 相等）。
结论：75/80=93.75% 的磁盘 I/O 耗时都在 0.1 秒以内（大部分操作很快）。  
_count：总样本数：node_disk_io_time_seconds_total_count 80 → 一共统计了 80 次磁盘 I/O 操作。  
_sum：总数值和：ode_disk_io_time_seconds_total_sum 3.2 → 这 80 次操作的总耗时是 3.2 秒；能算出 平均耗时：3.2 秒 / 80 次 = 0.04 秒（每次操作平均 40 毫秒）。
3.区别：
* Counter：只增不减的 “累计数”（比如总请求数）→ 回答 “一共发生了多少次”；
* Gauge：可增可减的 “瞬时值”（比如当前内存使用率）→ 回答 “现在是什么值”；
* Histogram：分区间的 “分布统计”（比如请求耗时分布）→ 回答 “数据都集中在哪个范围”。
核心数据：_bucket（区间计数）、_count（总样本数）、_sum（总数值和）；用途：排查性能问题（如 “慢请求占比多少”）、分析数据分布（如 “大部分操作耗时在哪个范围”）。
#### Summary（摘要）
Summary 和 Histogram 类似，由 `<basename>{quantile=" <φ>"} `， `<basename>_sum` ， `<basename>_count` 组成，主要用于表示一段时间内数据采样结果，（通常是请求持续时间或响应大小），它直接存储了 quantile 数据，而不是根据统计区间计算出来的。
1. Summary（摘要）是 Prometheus 中专门用于精准统计分位数的指标类型，核心作用是直接给出 “Top N% 的数值是多少”（比如 “95% 的请求耗时都在 0.5 秒以内”），无需手动划分区间（区别于 Histogram），适合需要精准性能指标的场景。  
Summary 就像 班级考试成绩的 “排名统计”：    
班级 50 人考试，成绩出来后，老师直接告诉你：
    * 平均分：82 分（所有成绩的总和 / 人数）；
    * 中位数（50% 分位数）：80 分（有 50% 的人成绩 ≤80 分）；
    * 90% 分位数：92 分（有 90% 的人成绩 ≤92 分，只有 10% 的人超 92 分）；
不用自己划分 “60~70 分、70~80 分” 的区间，直接得到 “多少比例的数值不超过某个值”—— 这就是 Summary 的核心：直接输出分位数，精准反映数据的集中趋势。
2. 以 node_http_request_duration_seconds 为例.这是 node_exporter 自身的 HTTP 请求耗时 Summary 指标）
```
# HELP node_http_request_duration_seconds node_exporter 接收 HTTP 请求的耗时摘要
# TYPE node_http_request_duration_seconds summary
node_http_request_duration_seconds{quantile="0.5"} 0.002  # 50% 分位数：一半请求耗时 ≤0.002 秒（2毫秒）
node_http_request_duration_seconds{quantile="0.9"} 0.005  # 90% 分位数：90% 请求耗时 ≤0.005 秒（5毫秒）
node_http_request_duration_seconds{quantile="0.99"} 0.01  # 99% 分位数：99% 请求耗时 ≤0.01 秒（10毫秒）
node_http_request_duration_seconds_sum 0.12  # 所有请求的总耗时（0.12 秒）
node_http_request_duration_seconds_count 50  # 总请求数（50 次）
```
分位数（带 quantile 标签）：
* quantile="0.5"：50% 的请求耗时 ≤0.002 秒（中位数，一半快一半慢）；
* quantile="0.9"：90% 的请求耗时 ≤0.005 秒（只有 10% 的请求耗时超 5 毫秒）；
* quantile="0.99"：99% 的请求耗时 ≤0.01 秒（只有 1% 的请求是 “慢请求”，超 10 毫秒）；
结论：几乎所有请求都很快，慢请求占比极低。

3. _count：总样本数： node_http_request_duration_seconds_count 50 → 一共统计了 50 次 HTTP 请求。  
4. _sum：总数值和： node_http_request_duration_seconds_sum 0.12 → 50 次请求的总耗时是 0.12 秒；能算出 平均耗时：0.12 秒 / 50 次 = 0.0024 秒（2.4 毫秒）。
区别：  
想直接知道 “95% 的请求有多慢”→ 用 Summary；
想知道 “请求耗时都集中在哪个区间”→ 用 Histogram。  
核心数据：quantile="0.5/0.9/0.99"（分位数）、_count（总样本数）、_sum（总数值和）；
#### Histogram vs Summary
* 都包含 `<basename>_sum` ， `<basename>_count`
* Histogram 需要通过 `<basename>_bucket` 计算 quantile, 而Summary 直接存储了 quantile 的值。
简单说：Histogram 是 “先统计区间，再估算分位数”，Summary 是 “直接计算并存储分位数”—— 前者依赖服务端（Prometheus）后续计算，后者在客户端（如 node_exporter）实时算好，下面拆解细节，再讲透 quantile。  
quantile 英 /ˈkwɒntaɪl/,中文常读 “分位数”，也有人简称 “分位”。  
把一组数据按从小到大排序后，切分成多个等比例部分的 “分割点数值”，核心是反映 “数据的分布位置”。


### 任务和实例：prometheus.yml 配置
prometheus 配置：node exporter
```
scrape_config:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```
实例： 在prometheus中，每一个暴露监控样本数据的HTTP服务。例如：在当前主机上运行的node exporter 可以称为一个实例（Instance）
采集数据：当我们需要采集不同的监控指标，我们只需要：运行相应的监控采集程序。 然后： 让Prometheus Server 知道这些Exporter 实例的访问地址。
### 作业与实例
* 作业和实例
* 自生成标签和时序
#### 作业和实例
prometheus 中，将任意一个独立的数据源（target）称之为实例（instance）。包含相同类型的实例的集合称之为作业（job）。
如下是一个含有四个重复实例的作业：
```
1. - job: api-server
2. - instance 1: 1.2.3.4:5670
3. - instance 2: 1.2.3.4:5671
4. - instance 3: 5.6.7.8:5670
5. - instance 4: 5.6.7.8:5671
```
#### 自生成标签和时序
prometheus 在采集数据的同时，会自动在时序的基础上添加标签，作为数据源（target）的标识，以便区分：    
即：这些标签本质是「数据源（Target）的身份信息」—— 比如 “这个指标来自哪台机器”“属于哪个监控任务”，避免不同设备 / 服务的指标混在一起，方便后续查询、筛选和聚合。  
* job 监控任务名（来自 prometheus.yml 配置）node（对应 scrape_configs 中的 job_name）
* instance 数据源的地址 + 端口（唯一标识一个 Target） 192.168.1.10:9100、localhost:8080
* __address__ 目标的地址 + 端口（内部标签，可用于模板） 192.168.1.11:9100

例如：  
```
up{job="<job-name>", instance="<instance-id>"}: 1 表示该实例正常工作
up{job="<job-name>", instance="<instance-id>"}: 0 表示该实例故障

scrape_duration_seconds{job="<job-name>", instance="<instance-id>"}    表示拉取数据的时间间隔

scrape_samples_post_metric_relabeling{job="<job-name>", instance="<instance-id>"}  #表示采用重定义标签（relabeling）操作后仍然剩余的样本数

scrape_samples_scraped{job="<job-name>", instance="<instance-id>"}  表示从该数据源获取的样本数
``` 
##__address__ 是 Prometheus 的 内部隐藏标签（开头和结尾是双下划线，区别于普通标签），核心作用是「存储数据源的原始地址 + 端口」，主要用于 配置文件中的模板渲染（比如动态生成其他标签、拼接 URL 等）—— 它不会直接出现在 /metrics 页面或查询结果中，但会在 Prometheus 内部传递和使用。
采集指标时，自动给每台服务器添加 “IP 标签”（只保留 IP，去掉端口），此时就可以用 __address__ 做模板渲染 —— 因为 __address__ 存储的是完整的「IP: 端口」，可以通过 Prometheus 的标签替换语法提取 IP。  
例如：
```
scrape_configs:
  - job_name: "node"  # 监控任务名
    static_configs:
      - targets: ["192.168.1.10:9100", "192.168.1.11:9100", "192.168.1.12:9100"]
    # 关键：用 __address__ 动态生成自定义标签
    relabel_configs:
      - source_labels: [__address__]  # 数据源：内部标签 __address__（值是 "IP:端口"）
        regex: "([0-9.]+):(.*)"       # 正则表达式：提取 IP（第一部分）和端口（第二部分）正则中 括号的顺序决定了 $n 的序号：
        target_label: "server_ip"     # 生成新标签：server_ip（只存 IP）
        replacement: "$1"             # 替换规则：用正则提取的第一部分（IP）作为新标签值
```
1. Prometheus 读取 targets 中的地址，给每个目标自动设置 __address__：  
目标 1：__address__ = "192.168.1.10:9100"
目标 2：__address__ = "192.168.1.11:9100"
目标 3：__address__ = "192.168.1.12:9100"
2. 通过 relabel_configs 处理 __address__：
正则 ([0-9.]+):(.*) 匹配 "IP: 端口" 格式，把 192.168.1.10 提取为 $1，9100 提取为 $2；
生成新标签 server_ip = $1（即只保留 IP）。
3. 最终采集的指标会带上 server_ip 标签（而 __address__ 仍隐藏）：
目标 1 指标：node_cpu_usage_percent{job="node", instance="192.168.1.10:9100", server_ip="192.168.1.10"} 35
目标 2 指标：node_cpu_usage_percent{job="node", instance="192.168.1.11:9100", server_ip="192.168.1.11"} 42

如果不用 __address__，你得手动给每个目标加标签，麻烦且容易错：
```
# 不用 __address__ 的写法（繁琐）
static_configs:
  - targets: ["192.168.1.10:9100"]
    labels:
      server_ip: "192.168.1.10"  # 手动写 IP
  - targets: ["192.168.1.11:9100"]
    labels:
      server_ip: "192.168.1.11"  # 重复工作
```
##############################################################################################################
## 使用Node Exporter 采集主机运行数据
安装Node Exporter
prometheus周期性的从Exporter暴露的HTTP服务地址（通常是/metrics）拉取监控样本数据。Exporter 可以是一个相对开放的概念，其可以是一个独立运行的程序独立于监控目标以外，也可以是直接内置在监控目标中只要能够向prometheus提供标准的监控样本数据即可。
### 使用Node Exporter,采集主机的运行指标
Get started-------Download the latest release--------同上二进制安装：往下翻。可以看到node_exporter
Node Exporter 同样采用Golang编写，并且不存在任何的第三方依赖，只需要下载，解压即可运行
```
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar -xf  xxxxx
```
运行node exporter：
```
cd node_exporter-xxxx
cp node_exporter-xxxx/node_exporter /usr/local/bin
node_exporter
```
访问`http://localhost:9100`可以看到页面
#### 使用Node Exporter 监控指标
访问 `http://localhost:9100/metrics`，可以看到当前node exporter 获取到的当前主机的所有监控数据，如下所示：  

每一个监控指标之前都会有一段类似于如下形式的信息：

```
# HELP node_cpu Seconds the cpus spent in each mode
# TYPE node_cpu counter
node_cpu{cpu="cpu0",mode="idle"} 362812.7890625
```
其中HELP用于解释当前指标的含义：  node_cpu 各模式下 CPU 所花费的秒数
TYPE 解释当前指标的数据类型：counter 为计数器：只增不减。  若是有增有减，可以使用gauge 仪表盘。  /ɡeɪdʒ/（英式发音，与美式一致）
综上，可以理解如下即可
```
# HELP node_1oad1 1m load average
# TYPE node_load1 gauge
node_load1 3.0703125
```
#### Prometheus Server 对接node exporter
为了能够让prometheus server 能够从当前node exporter 获取到监控数据，需要修改prometheus.yml 并在scrape_configs 节点下添加以下内容：
```shell
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    # 采集node exporter 监控数据
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```
重新启动prometheus server
访问`http://localhost:9090`,进入到prometheus server。输入“up” 并且点解执行后，有如下结果：  

若果prometheus 能够正常从node exporter 获取数据，则会看到以下结果：
```
up{instance="localhost:9090",job="prometheus"} 1
up{instance="localhost:9100",job="node"} 1
```
其中 1 表示正常，反之 0 为异常。
####################################################################################################
## PromQL 基本使用
* 字符串和数字
* 查询结果类型
* 查询条件
* 操作符
* 内置函数
### 字符串和数字
1. 字符串：用于标签值的精准匹配，三种引号按需选择（双引号常规、单引号避转义、反引号保留特殊字符）。
例如：  
```
node_cpu_seconds_total{job="node"}      #匹配job标签
http_requests_total{path='/api/v1/metrics'}         #path标签=xxx
app_logs{message=`Error: \n Connection timeout`}
```
2. 数字
正数 / 浮点数：用于数值的计算、比较，支持 PromQL 内置函数（如 rate、avg）和算术运算。 
例如：
```
node_cpu_usage_percent > 80      #数值比较
rate(http_requests_total[5m])     #数值运算
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100  #浮点数参与运算（计算内存使用率）

```
#### 查询结果类型
瞬时数据 (Instant vector): 包含一组时序，每个时序只有一个点。例如： `http_requests_total`
区间数据（Range vector）：包含一组时序，每个时序有多个点。例如：`http_requests_total[5m]`
纯量数据（Scalar）：纯量只有一个数字，没有时序。例如：`count(http_requests_total)`
#### 查询条件
Prometheus 存储的是时序数据，而它的时序是由名字和一组标签构成的. 时序数据=名字+标签 组成。  
名字也可以写出标签的形式，例如  `http_requests_total` 等价于 `{name="http_requests_total"}`  
一个简单的查询相当于是对各种标签的筛选，例如：  
```
http_requests_total{code="200"}   //表示查询名字为http_requests_total，code 为 "200" 的数据
```
查询条件支持正则匹配，例如：  
```
1.http_requests_total{code!="200"} // 表示查询code 不为 "200" 的数据。用途：排除 HTTP 状态码为 200 的请求，比如只关注错误或重定向等非正常请求。
2.http_requests_total{code=~"2.."} // 表示查询code 为 '2xx' 的数据
3.http_requests_toatl{code!~"2.."} // 表示查询code不为 '2xx' 的数据
提示：
=~ 当成一个「匹配判断符号」，!~ 当成「不匹配判断符号」。 即 ~ 一般与 "=" 和 "!" 一起使用。理解为匹配的意思。
```
#### 操作符
 * 算术运算符
 * 比较运算符
 * 逻辑运算符
 * 聚合运算符


### PromQL查询之监控指标
可以使用关键字`node_load1` 可以查询出Prometheus采集到的主机负载的样本数据，这些样本数据按照时间先后顺序展示，形成了主机负载随时间变化的趋势图表。
### PromQL查询之函数调用
 除了使用监控指标作为查询关键字以外，还内置了大量的函数，帮助用户进一步对时序数据进行处理。 
#### rate、irate函数 
例如：`rate()` 函数：单位时间内样本数据的变化情况：  增长率。 通过该函数我们可以近似的通过cpu使用时间计算cpu的利用率  
**注意** ： rate（）是Prometheus专为计数器Counter设计的函数，不能用于gauge类型的指标（如内存使用率、温度，这类指标会上下波动），否则结果没有参考意义
```
rate(node_cpu[2m])
```
解释：最近 2 分钟内每个时间点的 CPU 累计使用时间（比如从 1000 秒增长到 1012 秒），而 rate(node_cpu[2m]) 会计算：）
增长率 = (结束值 - 开始值) / 时间（秒）
即：(1012 - 1000) / 120 秒 = 12 / 120 = 0.1（单位：秒/秒，即 10%）  
结果 0.1 表示：在这 2 分钟内，CPU 平均每秒有 0.1 秒在被使用（即平均使用率 10%）。  
实际用法：  
`rate(node_cpu[2m])`本身只是计算增长率，结合node_cpu 的 `mode` 标签，才能实现具体的监控需求，最常见的是计算cpu使用率。  
场景1：计算cpu总体使用率（排除空闲时间）
```
1 - rate(node_cpu{mode="idle"}[2m])
```
解释：  
1. rate(...)：计算空闲时间的每秒增长率（即每秒有多少秒处于空闲状态。后续看到**rate** 想到的意思是： **每秒增长率**
2. node_cpu{mode="idle"}[2m]：取最近 2 分钟内 CPU 空闲时间的累计值；
场景2： 单独监控用户态/系统态cpu使用率
```promql
# 用户态cpu使用率（应用程序消耗的cpu）
rate（node_cpu{mode="user"}[2m]）
# 系统态cpu使用率（内核消耗的cpu）
rate（node_cpu{mode="system"[2m]}）
```
提示：  
时间窗口的选择。  
[10s]:容易受瞬间波动影响，结果不稳定
[1h]:无法及时反映短期变化（如突发流量导致的cpu飙升）
推荐： 根据指标采集间隔（scrape_interval）选择，通常是采集间隔的5~10倍（如采集间隔15秒，窗口选[2m]）   
irate() 适合 “实时告警”（能快速发现异常），而 rate() 适合 “趋势监控”（结果更稳定）。irate() 计算 “窗口内最后两个样本的增长率”，对突发变化更敏感，但波动大；   
#### avg 函数 
mode 标签：user 用户态、system 系统态、idle 空闲态、iowait IO 等待等
这时如果要忽略是哪一个cpu的，只需要使用without表达式，将标签cpu去除后聚合数据即可  
即：计算各模式下的平均 CPU 速率
```
avg without(cpu)(rate(node_cpu[2m]))
```
那如果需要计算系统cpu的总体使用率，通过排除系统限制的cpu使用率即可获得：  
即：专门用于计算系统总体 CPU 使用率
**CPU 总体使用率的定义是：非空闲状态的 CPU 时间占比（即 100% 减去空闲时间占比）**
```
1 - avg without(cpu) (rate(node_cpu{mode="idle"}[2m]))
```
解释：  
1. 最内层：rate（node_cpu[2m]）:计算单核心cpu增长率  输出结果如下：假设有2个cpu
```
rate(node_cpu{cpu="0",mode="user"}) → 0.05  # CPU0 的用户态每秒使用率
rate(node_cpu{cpu="0",mode="idle"}) → 0.80  # CPU0 的空闲率
rate(node_cpu{cpu="1",mode="user"}) → 0.06  # CPU1 的用户态每秒使用率
rate(node_cpu{cpu="1",mode="idle"}) → 0.79  # CPU1 的空闲率
...（其他 mode 如 system、iowait 等）
```
2. 中间层：without（cpu）（去除cpu标签，合并同类型指标）  
* without(cpu) 是Prometheus 的标签顾虑函数 ，作用是：保留所有标签，只移除cpu标签。并将相同标签组合的指标值合并（这里会将不同cpu核心的同类型指标合并到一起）
* （原本区分 cpu="0" 和 cpu="1" 的数据，现在只按 mode 分组，每组包含所有核心的速率值）
```
{mode="user"} → [0.05, 0.06]  # 两个 CPU 核心的用户态速率（数组形式）
{mode="idle"} → [0.80, 0.79]  # 两个 CPU 核心的空闲速率（数组形式）
...
```
3. 最外层：avg（...）计算平均值
avg（）是聚合函数，作用是：对括号内“同一标签组合的多个值”计算术平均值
```
{mode="user"} → 0.055  # (0.05 + 0.06) / 2 → 所有 CPU 核心的平均用户态使用率.表示：该服务器所有 CPU 核心的用户态平均使用率为 5.5%（因速率单位是 “秒 / 秒”，乘以 100 即百分比）。
{mode="idle"} → 0.795  # (0.80 + 0.79) / 2 → 所有 CPU 核心的平均空闲率
...
```
4. 关注细节：
without（cpu）在这里的效果等价于 `by(mode)`（by 是只保留指定标签），因为移除cpu标签后，剩下的核心标签就是mode。
因此 
```
avg(without(cpu)(rate(node_cpu[2m])))
```
等价于
```
avg(by(mode)(rate(node_cpu[2m])))
```
两者的区别只是逻辑角度不同（without 是 “排除某标签”，by 是 “保留某标签”），结果完全一致。
avg without(cpu)(rate(node_cpu[2m])) 是一个 “ **从单核心速率→合并核心→计算平均值”** 的流水线式表达式，核心作用是生成服务器所有 CPU 核心在不同模式下的平均增长率，方便从整体角度监控 CPU 负载趋势，是服务器监控中非常实用的 PromQL 表达式

## 使用grafana创建可视化Dashboard
### Dashboard
为了使用长期的监控数据可视化面板（Dashboard），grafana是一个开源的可视化平台，并且提供了对Prometheus的完整支持
```
docker run -d -p 3000:3000 grafana/grafana
```
访问`http://localhost:3000`就可以进入到Grafana的界面中，默认使用admin/admin 进入。在Grafana首页中显示默认的使用向导，包括：安装、添加数据源、创建Dashboard、邀请成员、以及安装应用和插件等主要流程
**Dashboard 分享**，通过`https://grafana.com/dashboards`,可以找到大量可直接使用的Dashboard  
Grafana 中所有的Dashboard 通过JSON共享，下载并且导入这些JSON文件，就可以直接使用这些已经定义好的Dashboard。

grafana 仪表盘本质是：可视化配置文件（JSON格式），官网共享的仪表盘（如14584号）已包含所有图表、指标逻辑，无需依赖插件。唯一前提是：必须配置好监控数据的数据源。  
三步骤 
A. 
1. 提前配置Prometheus数据源  
进入Grafana首页-------Configuration（齿轮图标）------Data Sources
2. 点击 Add data source ------- 搜索 Prometheus
3. 在URL处填写你的Prometheus 地址，其他默认-------点击save & test。提示： Data source is working 即配置成功
B.
1. 进入 Grafana 导入页面，点击 Create（图标）----Import
2. 在 “Import via grafana.com” 输入框中，填写仪表盘 ID：14584 → 点击 “Load”。
（Grafana 会自动从官网拉取 14584 号仪表盘的 JSON 配置）
C.
1. 页面加载后，在 “Options” 下方的 “Select a Prometheus data source” 下拉框中，选择你刚配置好的 Prometheus 数据源;其他选项（如仪表盘名称、文件夹）可默认或自定义 → 点击 “Import”。
D.
检查：
1. 若所有图表正常显示数据（如应用数量、同步状态分布），说明导入成功；
2. 若显示 “NO DATA”，检查两点：① Prometheus 数据源是否正确；② Prometheus 是否真的采集到了 ArgoCD 的指标（可在 Prometheus 界面执行 argocd_app_info 验证是否有数据）。