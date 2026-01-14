# MATLAB Port Verification Checklist

本文档提供验证步骤，确保所有实现符合要求。

## 运行前准备

1. 确保 MATLAB 版本 ≥ R2024a
2. 确保所有文件在正确位置：
   ```
   matlab/
   ├── config.m
   ├── Neurons.m
   ├── PlaceCells.m
   ├── GridCells.m
   ├── EnvironmentStub.m
   ├── AgentStub.m
   ├── paper_visual.m
   ├── plot_utils.m
   ├── demo_agent_line.m
   ├── demo_gridcells_visual.m
   └── data/
       └── agent_path.csv
   ```

## 验证步骤

### 1. 基础功能测试

在 MATLAB 命令窗口运行：

```matlab
% 1.1 配置加载
cfg = config();
assert(~isempty(cfg), 'Config loaded');
fprintf('✓ Config loaded successfully\n');

% 1.2 环境创建
env = EnvironmentStub(struct('extent', [0,1,0,1]));
assert(size(env.flattened_discrete_coords, 2) == 2, 'Environment discretized');
fprintf('✓ Environment created successfully\n');

% 1.3 Agent 创建
agent = AgentStub('matlab/data/agent_path.csv', env);
assert(~isempty(agent.pos), 'Agent initialized');
fprintf('✓ Agent created successfully\n');

% 1.4 PlaceCells 创建与更新
pcs = PlaceCells(agent, struct('n', 5));
pcs.update();
assert(length(pcs.firingrate) == 5, 'PlaceCells firing rate computed');
fprintf('✓ PlaceCells working\n');

% 1.5 GridCells 创建与更新
gcs = GridCells(agent, struct('n', 6));
gcs.update();
assert(length(gcs.firingrate) == 6, 'GridCells firing rate computed');
fprintf('✓ GridCells working\n');

fprintf('\n=== Basic tests passed ===\n\n');
```

### 2. Demo 运行测试

```matlab
% 2.1 运行完整 demo（需要几秒钟）
demo_agent_line;
fprintf('✓ demo_agent_line completed\n');

% 2.2 运行可视化 demo
demo_gridcells_visual;
fprintf('✓ demo_gridcells_visual completed\n');

fprintf('\n=== All demos completed ===\n\n');
```

### 3. 输出验证

检查 `matlab/output/` 目录，应包含以下文件：

#### demo_agent_line 输出：
- [ ] `placecells_ratemap.png`
- [ ] `placecells_ratemap.eps`
- [ ] `gridcells_ratemap.png`
- [ ] `gridcells_ratemap.eps`
- [ ] `placecells_timeseries.png`
- [ ] `placecells_timeseries.eps`

#### demo_gridcells_visual 输出：
- [ ] `gridcells_modules_visual.png`
- [ ] `gridcells_modules_visual.eps`
- [ ] `gridcell_single_detail.png`
- [ ] `gridcell_single_detail.eps`
- [ ] `gridcells_types_comparison.png`
- [ ] `gridcells_types_comparison.eps`

### 4. Paper-Visual 规范验证

打开任一 PNG 图片，验证：

1. **物理尺寸**：
   - 在图片属性中查看尺寸
   - 应为 8.8cm × 2.0 = 17.6cm 宽度（或相应比例）

2. **分辨率**：
   - 应为 600 DPI

3. **字体**：
   - 所有文本使用 Arial
   - 字号为 9pt × 2.0 = 18pt

4. **布局**：
   - 刻度外向
   - 无边框（或仅部分边框）
   - 底部有足够空间，标签不被裁切

5. **矢量格式**：
   - EPS 文件可在 Illustrator/Inkscape 中打开
   - 文本和线条可编辑（矢量）

### 5. 核心算法验证

#### 5.1 PlaceCells 高斯特性

```matlab
cfg = config();
env = EnvironmentStub();
agent = AgentStub('matlab/data/agent_path.csv', env);
pcs = PlaceCells(agent, struct('n', 1, 'widths', 0.2, 'description', 'gaussian'));

% 在中心位置应最大
center = pcs.place_cell_centres(1, :);
fr_center = pcs.get_state('pos', center);
assert(fr_center(1) > 0.99, 'Place cell fires maximally at center');

% 在远处应接近零
far_pos = center + [1, 1];
fr_far = pcs.get_state('pos', far_pos);
assert(fr_far(1) < 0.1, 'Place cell fires minimally far from center');

fprintf('✓ PlaceCells Gaussian response verified\n');
```

#### 5.2 GridCells 周期性

```matlab
gcs = GridCells(agent, struct('n', 1, 'gridscale', 0.5, 'description', 'rectified_cosines'));

% 获取完整 rate map
rate_map_full = gcs.get_state('evaluate_at', 'all');
max_fr = max(rate_map_full);
min_fr = min(rate_map_full);

% 应有明显的最大和最小
assert(max_fr > 0.8, 'GridCell has high peaks');
assert(min_fr < 0.2, 'GridCell has low troughs');

fprintf('✓ GridCells periodicity verified\n');
```

### 6. 历史记录验证

```matlab
% 运行若干步
agent = AgentStub('matlab/data/agent_path.csv', env);
pcs = PlaceCells(agent, struct('n', 3));

for i = 1:10
    pcs.update();
    if i < 10
        agent.step();
    end
end

% 检查历史
hist = pcs.get_history_arrays();
assert(length(hist.t) == 10, 'History length correct');
assert(size(hist.firingrate, 1) == 10, 'Firing rate history correct');
assert(size(hist.firingrate, 2) == 3, 'Firing rate has correct number of neurons');

fprintf('✓ History recording verified\n');
```

## 预期结果

所有测试应通过，输出：
```
✓ Config loaded successfully
✓ Environment created successfully
✓ Agent created successfully
✓ PlaceCells working
✓ GridCells working

=== Basic tests passed ===

✓ demo_agent_line completed
✓ demo_gridcells_visual completed

=== All demos completed ===

✓ PlaceCells Gaussian response verified
✓ GridCells periodicity verified
✓ History recording verified

ALL TESTS PASSED!
```

## 故障排查

### 常见问题

1. **找不到文件**：
   - 检查当前工作目录：`pwd`
   - 切换到项目根目录：`cd('F:\__CODE__\251224_RatInABox\RatInABox')`

2. **CSV 读取错误**：
   - 检查 `matlab/data/agent_path.csv` 存在
   - 确保文件格式正确（t, x, y 三列）

3. **绘图不显示**：
   - 确保 `figure('Visible', 'on')`
   - 检查 MATLAB 图形系统正常

4. **导出失败**：
   - 确保 `matlab/output/` 目录存在（自动创建）
   - 检查文件写入权限

5. **字体不正确**：
   - 确认系统安装了 Arial 字体
   - 或在 config.m 中修改为其他字体

## 性能基准

在标准配置下（Windows 10, i7, 16GB RAM）：

- `demo_agent_line`: ~5-10 秒
- `demo_gridcells_visual`: ~3-5 秒
- 单个 update 循环（81 步）: <1 秒

## 下一步

验证通过后，可以：
1. 修改 `config.m` 中的参数
2. 自定义轨迹数据
3. 扩展更多 Neuron 子类
4. 集成到更大的项目中
