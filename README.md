<p align="center">
  <img src="images/PixelStreamIcon.svg" alt="NebulaRender Logo" width="240" />
</p>

# NebulaRender 云渲染管理平台

> 让 UE 像素流真正落地商用：开箱即用的管理后台、应用分发、渲染集群调度与运营监控，支持私有化部署与国产化环境。

NebulaRender 是一套**基于 UEPixelStreaming二次开发的企业级云渲染运营平台**：把 UE 做好的应用上传到平台，即可一键生成链接分发给用户，用户用浏览器点开即用，无需安装任何软件。

产品以**离线包**形式私有化交付，部署在企业自己的服务器上（可完全在内网），业务数据不出本地。

![运行效果](images/运行效果.png)

## 下载（离线包）

> 最新版本 **v1.0.0** 已发布 —— [Release 发布页](https://github.com/starTechnology1994/UEPixelStreamingPlatform/releases) · [版本记录](https://github.com/starTechnology1994/UEPixelStreamingPlatform/releases/tag/v1.0.0)

平台以离线包形式交付，解压即用（[部署形态](#部署形态)）：

- **Windows 离线包**（后台 + 渲染服务器 + SFU）→ [下载 NebulaRender-Windows.zip](https://github.com/starTechnology1994/UEPixelStreamingPlatform/releases/download/v1.0.0/NebulaRender-Windows.zip)
- **Linux 离线包**（Docker 镜像 + 渲染服务器裸机包）→ [下载 NebulaRender-Linux.zip](https://github.com/starTechnology1994/UEPixelStreamingPlatform/releases/download/v1.0.0/NebulaRender-Linux.zip)

## 适用场景

- 水务、电力、交通等行业的数字孪生与仿真系统
- 工业设计评审与大型设备展示
- 教学实训与医疗仿真
- 虚拟展厅与云游戏
- 信创/国产化环境下的三维应用云化

## 核心功能

### 应用管理与分享

- 应用包网页上传（大文件支持断点续传），多版本管理、一键激活与回滚
- 生成带权限的**分享链接**，发给用户即可打开云渲染应用

![应用管理界面](images/应用管理.jpg)

### 可视化管理后台

- 数据总览：在线用户、服务器状态、应用使用情况一目了然
- 应用、渲染节点、账号、平台设置全部在网页上完成，无需命令行
- 管理员 / 普通用户双角色，普通用户只能看到自己的应用

![数据总览界面](images/数据总览.jpg)

![运行监控界面](images/运行监控.jpg)

![账号管理界面](images/账号管理.jpg)

### 渲染集群调度

- 多台渲染服务器自动组网、负载均衡，用户请求自动分配到合适节点
- 节点资源不足时自动进入排队提示；节点离线自动告警
- 支持**协作模式**（多人共享同一画面，适合会议、讲解）与**独立模式**（每人独占一台实例，适合设计、仿真）

![渲染节点界面](images/渲染节点.jpg)

### 用户访问体验

- 浏览器即点即用，无需安装客户端
- 网络波动时自动调节清晰度，多人同时在线互不干扰
- 分享链接可对接现有账号系统（免登录直达）

![浏览器即点即用的运行效果](images/运行效果.png)

### 复杂网络增强（可选）

- 跨网段、内网穿透等场景可开启中心化媒体转发，连接更稳定；不开启也不影响使用

### 国产化适配

- 支持人大金仓数据库与常见国产 GPU（含摩尔线程、砺算等），提供 Linux 国产硬件部署支持

### UE 全版本兼容

- 提供与 UE 5.1-5.8 各引擎版本对应的定制插件包，UE 工程接入后即可打包发布

## 与原生 UE Pixel Streaming 的对比

NebulaRender 不是对官方插件的简单封装，而是在 UE 5.1-5.8 的 UEPixelStreaming 插件与前端信令上做了大量源码级二次定制，并与自研渲染服务器深度集成。以下为与原生能力的逐项对比：

| 维度            | 原生 UE Pixel Streaming               | NebulaRender                                                                  |
| ------------- | ----------------------------------- | ----------------------------------------------------------------------------- |
| 开箱即用          | 需自行集成信令服务器与前端，无法直接对外提供服务            | 离线包解压即用，自带管理后台、调度服务与播放页，浏览器点开即玩                                               |
| 应用与版本管理       | 不支持，仅能一对一访问单个已打包应用，无法管理             | 网页上传（大文件断点续传）、多版本管理、一键激活与回滚，生成带权限的分享链接                                        |
| 启动与缓存         | 每次冷启动都完整加载应用资源，等待时间长                | 首次使用自动缓存到渲染服务器，二次打开"秒开"；启动全过程可视化进度，可随时取消                                      |
| 渲染集群调度        | 不支持多机多应用统一调度                        | 多渲染服务器自动组网、负载均衡、忙时自动排队；节点离线自动告警                                               |
| 使用模式          | 仅支持一对一                              | 协作模式（多人共享同一画面，适合会议、讲解）与独立模式（每人独占实例，适合设计、仿真），席位与授权实时管控                         |
| 管理后台与权限       | 无管理后台、无账号体系                         | 数据总览、应用/节点/账号/授权全网页化管理；管理员/普通用户双角色，支持企业单点登录免登录直达                              |
| 视频编码与带宽       | 编码参数固定不可调；多人各自拉流，上行带宽占用高            | 帧率、码率、画质可在后台与链接参数中灵活调节，网络波动时浏览器端自动降级清晰度保流畅；可选中心媒体转发，协作模式下多路画面共享一路码流，显著节省服务器带宽 |
| 鼠标键盘输入（插件级定制） | 原生插件在无桌面的 Linux 渲染服务器上组合键失效，按键行为不可控 | 源码级定制插件（适配 UE 5.1-5.8）：浏览器修饰键状态实时同步进引擎，Ctrl+A/C/V 等组合键、鼠标多键（前进/后退）完整可用        |
| 中文输入与剪贴板      | 不支持中文输入，复制粘贴不可用                     | 浏览器中文输入法（IME）候选窗光标跟随，支持双向复制粘贴并与 UE 剪贴板无缝打通，规避重复粘贴等常见问题                        |
| 可用性与恢复        | 播放中断、实例异常无人接管，需用户手动刷新               | 实例启动失败自动重新匹配、断线快速重连可复用原实例、UE 进程异常自动回收，节点状态定期对账，杜绝僵尸实例                         |
| 运维与国产化        | 需自行搭建监控、部署与适配                       | 后台远程运维与自动告警；支持人大金仓数据库与摩尔线程、砺算（需额外编码插件）等国产 GPU，提供国产化环境（统信 UOS / 麒麟）离线部署方案      |

## 部署形态

平台由**后台服务器**、**渲染服务器**与\*\*媒体转发（可选）\*\*三部分组成，分别交付 **Windows** 与 **Linux** 两种离线包：

- 解压即用，包内自带运行环境，无需手工安装依赖；
- 后台服务器与渲染服务器可同机部署，也可拆分到多台横向扩容；
- 支持内网离线运行，数据保留在客户服务器本地。

按 [快速开始](https://github.com/starTechnology1994/UEPixelStreamingPlatform/wiki/快速开始) 操作即可完成部署并跑通第一个应用。

*NebulaRender — 让 UE 像素流送真正可用、可管、可运营。*

## 使用文档

完整使用文档已迁移至 GitHub Wiki：

- [使用手册（Wiki 首页）](https://github.com/starTechnology1994/UEPixelStreamingPlatform/wiki)
- [快速开始](https://github.com/starTechnology1994/UEPixelStreamingPlatform/wiki/快速开始)
- [功能介绍](https://github.com/starTechnology1994/UEPixelStreamingPlatform/wiki/功能介绍)
- [部署与运维](https://github.com/starTechnology1994/UEPixelStreamingPlatform/wiki/部署与运维)
- [数据库与国产化](https://github.com/starTechnology1994/UEPixelStreamingPlatform/wiki/数据库与国产化)
- [授权与购买](https://github.com/starTechnology1994/UEPixelStreamingPlatform/wiki/商业授权)

## 联系我们

- 商务合作 / 授权咨询 / 技术支持：**<startechnology1994@163.com>**
- 企业微信：<https://work.weixin.qq.com/ca/cawcdef9a4d05fef8c>
- Bilibili 视频教程：<https://space.bilibili.com/3546688536971381>

