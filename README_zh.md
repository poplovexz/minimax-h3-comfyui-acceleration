# MiniMax H3 ComfyUI 加速包（ROCm 云部署适配版）

本项目基于上游 [JH427/minimax-h3-comfyui-acceleration](https://github.com/JH427/minimax-h3-comfyui-acceleration)，
增加了**国内网络适配**与 **AMD Radeon Cloud 一键部署**支持。原仓库的节点、工作流、测试与文档全部保留。

## 这是什么

为 ComfyUI 中的 MiniMax H3 视频生成提供三条可选加速路线（opt-in，不改变原生路径）：

| 路线 | 步数 | 参考加速比 | 适用场景 |
|---|---:|---:|---|
| Turbo 8 | 8 | ~2.1x | 草稿、快速迭代 |
| Spectrum 20 | 20 | ~1.6x | 日常出片 |
| FBC Safe 20 | 20 | ~1.5x | 求稳加速 |
| Native 20 | 20 | 1.0x | 画质基准 |

> 参考数据来自 AMD ROCm 平台实测（上游 Strix Halo 参考机；48GB RDNA3 独显实测加速比与之一致）。

## 快速开始（AMD ROCm 环境）

```bash
git clone https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git
cd minimax-h3-comfyui-acceleration
python tools/install_into_comfyui.py --comfyui ~/ComfyUI   # 安装三个加速节点
bash deploy/download_models_modelscope.sh ~/ComfyUI        # 从魔搭下载全套模型（约 85GB）
```

要求：ComfyUI ≥ 0.31.0、Python 3.10+、PyTorch ROCm 运行时。详见上游 `docs/` 目录。

## Radeon Cloud 一键部署

在 [developer.amd.com.cn/radeon/profile](https://developer.amd.com.cn/radeon/profile) 创建模板：

- **Container Image**: 任选 ROCm ComfyUI 镜像（如 `comfyui_zimage_rocm7.2.1_ubuntu24.04_py3.12_pytorch_2.9`）
- **Deploy Type**: `ComfyUI (one-click)`，端口 `8188`
- **Start Command**:

```bash
bash -lc 'git clone https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git /root/h3acc || git clone https://gh-proxy.com/https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git /root/h3acc; bash /root/h3acc/deploy/radeon_cloud_start.sh'
```

实例首次启动会自动：安装加速包 → 从魔搭下载模型（断点续传，重启不重复下载）→ 启动 ComfyUI。

## 工作流使用建议

- 草稿用 `h3-turbo8-t2v.json`（8 步），满意后换 `h3-spectrum-t2v.json` 或原生 20 步出正片
- 帧数必须满足 H3 的 `17k+5` 网格（24fps 下 124 帧 ≈ 5.2 秒），模板工作流内的数学节点会自动对齐
- 参考图生视频用 ref2va 权重 + `MiniMaxH3ReferenceToVideo` 节点（prompt 中保留 `<Picture 1>` 标签）
- **不要同时启用多条加速路线**；对比画质时固定 seed/分辨率/帧数

## 与上游的差异

- 新增 `deploy/download_models_modelscope.sh`：魔搭模型下载（含 fl2va + ref2va 双 backbone）
- 新增 `deploy/radeon_cloud_start.sh`：Radeon Cloud 模板启动脚本
- 新增本中文说明
- 其余内容与上游保持一致，可直接同步上游更新

## 许可

混合许可，与上游相同：集成代码 Apache-2.0，FirstBlockCache MIT，Spectrum GPL-3.0+，
详见 `NOTICE.md` 与 `vendored-components.json`。模型权重需按各自许可另行获取。
