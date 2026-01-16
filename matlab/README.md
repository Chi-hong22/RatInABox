<!--
input: matlab 目录内的脚本与类文件
output: 目录结构与使用说明
pos: matlab 根目录说明文档
一旦我被更新，务必更新我的开头注释，以及所属的文件夹的md。
最近更新：2026-01-16 15:00:33 demo 子图布局改为紧凑模式
-->
# MATLAB Port of RatInABox Core Neurons
一旦我所属的文件夹有所变化，请更新我。

架构概述（3行内）：
本目录提供 RatInABox 核心神经元的 MATLAB 版本与可视化 demo。
核心类位于 `Neurons.m` 与各子类文件（含双余弦变体）；环境与代理为 demo 轻量实现。
绘图与复现实验路径由 `config.m` 与可视化脚本统一约束。

This directory contains the MATLAB implementation of core neuron models from RatInABox.

## Directory Structure

```
matlab/
├── config.m                    # 统一配置文件（参数、路径、绘图规范）
├── Neurons.m                   # 基类
├── PlaceCells.m                # Place cell 实现
├── GridCells.m                 # Grid cell 实现（三余弦60°）
├── GridCells2Cos.m             # Grid cell 双余弦变体（两余弦90°）
├── EnvironmentStub.m           # 简化环境类（支持 demo）
├── AgentStub.m                 # 简化 Agent 类（支持 demo）
├── paper_visual.m              # 论文级可视化规范封装
├── plot_utils.m                # 绘图工具函数（静态方法，调用 plot_utils.xxx）
├── demo_agent_line.m           # Demo：轨迹显示 + Place/Grid cells
├── demo_gridcells_visual.m     # Demo：Grid cells 可视化（无需 Agent）
├── demo_gridcells2cos_visual.m # Demo：双余弦网格细胞可视化（对比三余弦）
├── docs/                       # 文档说明（算法与验证）
│   ├── DOCS_INDEX.md           # docs 目录索引
│   ├── GRIDCELL_ALGORITHM.md   # 三余弦算法说明
│   ├── IMPLEMENTATION_SUMMARY.md # 实现摘要
│   └── VERIFICATION_CHECKLIST.md # 验证清单
├── data/
│   └── agent_path.csv          # 示例轨迹数据 (t,x,y)
└── output/                     # 输出图片与缓存
```

## Usage

1. 运行完整 demo（包含 Agent 轨迹）：
   ```matlab
   demo_agent_line
   ```
   - 轨迹、rate map、时间序列由 `plot_utils.m` 统一提供
   - PlaceCells 时间序列默认展示全部细胞
   - 所有可视化图窗使用紧凑布局

2. 仅可视化 Grid cells（无需 Agent）：
   ```matlab
   demo_gridcells_visual
   ```
   - 图2与图3默认使用"最大尺度"的网格细胞用于展示

3. 可视化双余弦网格细胞（对比三余弦）：
   ```matlab
   demo_gridcells2cos_visual
   ```
   - 展示矩形/条纹网格模式（两余弦90°交叉）
   - 对比不同方向角、描述类型的影响
   - 对比三余弦六边形 vs 双余弦矩形网格

3. 配置参数：编辑 `config.m`

## Requirements

- MATLAB R2024a or later
- No additional toolboxes required

## Paper-Visual Compliance

所有绘图遵循 paper-visual 规范：
- 基准：8.8cm/9pt/Arial
- 导出：2.0倍放大、600dpi、png+eps
- 插入文档后等比缩小至基准尺寸
