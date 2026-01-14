# MATLAB Port of RatInABox Core Neurons

This directory contains the MATLAB implementation of core neuron models from RatInABox.

## Directory Structure

```
matlab/
├── config.m                    # 统一配置文件（参数、路径、绘图规范）
├── Neurons.m                   # 基类
├── PlaceCells.m                # Place cell 实现
├── GridCells.m                 # Grid cell 实现
├── EnvironmentStub.m           # 简化环境类（支持 demo）
├── AgentStub.m                 # 简化 Agent 类（支持 demo）
├── paper_visual.m              # 论文级可视化规范封装
├── plot_utils.m                # 绘图工具函数
├── demo_agent_line.m           # Demo：直线轨迹 + Place/Grid cells
├── demo_gridcells_visual.m     # Demo：Grid cells 可视化（无需 Agent）
├── data/
│   └── agent_path.csv          # 示例轨迹数据 (t,x,y)
└── output/                     # 输出图片与缓存
```

## Usage

1. 运行完整 demo（包含 Agent 轨迹）：
   ```matlab
   demo_agent_line
   ```

2. 仅可视化 Grid cells（无需 Agent）：
   ```matlab
   demo_gridcells_visual
   ```

3. 配置参数：编辑 `config.m`

## Requirements

- MATLAB R2024a or later
- No additional toolboxes required

## Paper-Visual Compliance

所有绘图遵循 paper-visual 规范：
- 基准：8.8cm/9pt/Arial
- 导出：2.0倍放大、600dpi、png+eps
- 插入文档后等比缩小至基准尺寸
