%% demo_gridcells2cos_visual.m - GridCells2Cos 可视化 demo（无需 Agent）
%
% input: config.m, EnvironmentStub.m, GridCells2Cos.m
% output: 双余弦网格细胞可视化窗口与可选导出图片
% pos: GridCells2Cos 可视化 demo 脚本（无需 Agent 轨迹）
% 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的md。
% 最近更新：2026-01-16 15:00:33 子图布局改为紧凑模式
%
% 功能：
%   1. 创建"虚拟"环境和 Agent（与 demo_gridcells_visual.m 参数一致）
%   2. 创建多组不同参数的 GridCells2Cos
%   3. 可视化 rate map（展示矩形/条纹网格模式）
%   4. 导出图片（paper-visual 规范）
%
% 特点：
%   - 展示两余弦90°交叉的矩形网格效果
%   - 对比不同尺度、方向角的影响
%   - 对比两余弦与三余弦的网格差异
%
% 使用：
%   >> demo_gridcells2cos_visual

clear; close all; clc;

fprintf('====== RatInABox MATLAB Demo：GridCells2Cos 可视化 ======\n\n');

%% 1. 加载配置
fprintf('1. 正在加载配置...\n');
cfg = config();

%% 2. 创建虚拟环境和 Agent（与 demo_gridcells_visual.m 完全一致）
fprintf('2. 创建虚拟环境与 Agent...\n');

% 环境（使用与原 demo 相同的参数）
env_params = struct(...
    'extent', [0, 10, 0, 10], ...  % 与原 demo 一致
    'boundary_conditions', cfg.env.boundary_conditions, ...
    'dimensionality', cfg.env.dimensionality, ...
    'dx', cfg.env.dx);
env = EnvironmentStub(env_params);

% 虚拟 Agent（与原 demo 一致）
agent = struct();
agent.Environment = env;
agent.dt = 0.01;
agent.t = 0;
agent.pos = [5, 5];  % 固定位置
agent.velocity = [0, 0];
agent.head_direction = [1, 0];
agent.speed_mean = 0.1;
agent.speed_std = 0.0;

fprintf('   环境范围: [%.1f, %.1f] x [%.1f, %.1f] 米\n', ...
    env.extent(1), env.extent(2), env.extent(3), env.extent(4));

%% 3. 创建多组 GridCells2Cos（不同尺度）
fprintf('3. 创建多组 GridCells2Cos（不同尺度）...\n');

% 配置：3 个尺度模块（与原 demo 一致）
gridscales = [1, 2, 4];
orientations = [0, pi/6, pi/3];  % 与原 demo 一致
n_modules = length(gridscales);
n_per_module = 5;  % 每个尺度模块 5 个细胞
max_gridscale = max(gridscales);

gcs2_list = cell(n_modules, 1);
for i = 1:n_modules
    gc2_params = struct(...
        'n', n_per_module, ...
        'gridscale', gridscales(i), ...
        'gridscale_distribution', 'delta', ...
        'orientation', orientations(i), ...
        'orientation_distribution', 'delta', ...
        'phase_offset', cfg.grid.phase_offset, ...
        'phase_offset_distribution', 'uniform', ...
        'description', cfg.grid.description, ...
        'min_fr', cfg.neurons.min_fr, ...
        'max_fr', cfg.neurons.max_fr);
    
    gcs2_list{i} = GridCells2Cos(agent, gc2_params);
    fprintf('   尺度模块 %d: gridscale = %.2f m, orientation = %.2f rad\n', ...
        i, gridscales(i), orientations(i));
end

%% 4. 可视化：展示不同尺度模块的 rate map
fprintf('4. 绘制各尺度模块 rate map（双余弦）...\n');

fig = figure('Name', 'GridCells2Cos Modules Visualization');
set(fig, 'Position', [100, 100, 1400, 550]);
set(fig, 'Color', 'w');

tiledlayout(fig, n_modules, n_per_module, 'Padding', 'compact', 'TileSpacing', 'compact');
plot_idx = 1;
for mod_idx = 1:n_modules
    gcs2 = gcs2_list{mod_idx};
    
    for cell_idx = 1:n_per_module
        ax = nexttile(plot_idx);
        
        % 获取 rate map
        rate_maps = gcs2.get_state('evaluate_at', 'all');
        rate_map = rate_maps(cell_idx, :);
        
        % 重塑为图像
        H = size(env.discrete_coords, 1);
        W = size(env.discrete_coords, 2);
        rate_map = reshape(rate_map, H, W);
        
        % 绘制
        imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
        set(ax, 'YDir', 'normal');
        colormap(ax, cfg.plot.colormap);
        axis(ax, 'equal', 'tight');
        
        % 标题
        title(ax, sprintf('尺度模块%d 细胞%d (%.2fm)', ...
            mod_idx, cell_idx, gridscales(mod_idx)), 'FontSize', 11);
        
        % 标签
        if cell_idx == 1
            ylabel(ax, 'y (m)', 'FontSize', 10);
        end
        if mod_idx == n_modules
            xlabel(ax, 'x (m)', 'FontSize', 10);
        end
        
        plot_idx = plot_idx + 1;
    end
end

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcells2cos_modules_visual');
    paper_visual_export(fig, export_path, cfg);
end

%% 5. 可视化：单个 GridCell2Cos 详细展示
fprintf('5. 绘制单个 GridCell2Cos 细节...\n');

% 创建单个 grid cell（使用最大尺度，与原 demo 一致）
gc2_single_params = struct(...
    'n', 1, ...
    'gridscale', max_gridscale, ...
    'gridscale_distribution', 'delta', ...
    'orientation', 0.0, ...
    'orientation_distribution', 'delta', ...
    'phase_offset', [0, 0], ...
    'phase_offset_distribution', 'delta', ...
    'description', cfg.grid.description, ...
    'min_fr', cfg.neurons.min_fr, ...
    'max_fr', cfg.neurons.max_fr);
gc2_single = GridCells2Cos(agent, gc2_single_params);

fig_single = figure('Name', 'GridCell2Cos Detail');
set(fig_single, 'Position', [150, 150, 700, 600]);
set(fig_single, 'Color', 'w');

% 获取 rate map
rate_maps = gc2_single.get_state('evaluate_at', 'all');
rate_map = rate_maps(1, :);
H = size(env.discrete_coords, 1);
W = size(env.discrete_coords, 2);
rate_map = reshape(rate_map, H, W);

% 绘制
ax = axes(fig_single);
imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
set(ax, 'YDir', 'normal');
colormap(ax, cfg.plot.colormap);
axis(ax, 'equal', 'tight');
xlabel(ax, 'x (m)', 'FontSize', 12);
ylabel(ax, 'y (m)', 'FontSize', 12);
title(ax, sprintf('双余弦网格细胞 (尺度=%.2f m, 方向=%.2f rad, 相位=[%.2f, %.2f])', ...
    gc2_single.gridscales(1), ...
    gc2_single.orientations(1), ...
    gc2_single.phase_offsets(1, 1), ...
    gc2_single.phase_offsets(1, 2)), 'FontSize', 13);

% 添加色条
cb = colorbar(ax);
ylabel(cb, '发放率 (Hz)', 'FontSize', 11);
set(cb, 'FontSize', 10);

% 调整轴位置
pos = get(ax, 'Position');
set(ax, 'Position', [pos(1)*1.1, pos(2)*1.1, pos(3)*0.95, pos(4)*0.95]);

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcell2cos_single_detail');
    paper_visual_export(fig_single, export_path, cfg);
end

%% 6. 可视化：不同描述类型对比
fprintf('6. 对比不同描述类型（双余弦）...\n');

descriptions = {'rectified_cosines', 'shifted_cosines'};
desc_names = {'截断余弦 (rectified)', '平移余弦 (shifted)'};
fig_types = figure('Name', 'GridCell2Cos Types Comparison');
set(fig_types, 'Position', [200, 200, 1200, 500]);
set(fig_types, 'Color', 'w');
tiledlayout(fig_types, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

for i = 1:length(descriptions)
    gc2_type_params = struct(...
        'n', 1, ...
        'gridscale', max_gridscale, ...
        'orientation', 0.0, ...
        'phase_offset', 0.0, ...
        'description', descriptions{i}, ...
        'min_fr', cfg.neurons.min_fr, ...
        'max_fr', cfg.neurons.max_fr);
    gc2_type = GridCells2Cos(agent, gc2_type_params);
    
    ax = nexttile(i);
    
    % 获取 rate map
    rate_maps = gc2_type.get_state('evaluate_at', 'all');
    rate_map = rate_maps(1, :);
    rate_map = reshape(rate_map, H, W);
    
    % 绘制
    imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
    set(ax, 'YDir', 'normal');
    colormap(ax, cfg.plot.colormap);
    axis(ax, 'equal', 'tight');
    xlabel(ax, 'x (m)', 'FontSize', 12);
    ylabel(ax, 'y (m)', 'FontSize', 12);
    title(ax, desc_names{i}, 'FontSize', 13);
    
end

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcells2cos_types_comparison');
    paper_visual_export(fig_types, export_path, cfg);
end

%% 7. 可视化：对比不同方向角的效果
fprintf('7. 对比不同方向角的效果...\n');

test_orientations = [0, pi/8, pi/4, pi/2];  % 0°, 22.5°, 45°, 90°
orientation_names = {'0°', '22.5°', '45°', '90°'};
fig_orient = figure('Name', 'GridCell2Cos Orientations Comparison');
set(fig_orient, 'Position', [250, 250, 1400, 400]);
set(fig_orient, 'Color', 'w');
tiledlayout(fig_orient, 1, 4, 'Padding', 'compact', 'TileSpacing', 'compact');

for i = 1:length(test_orientations)
    gc2_orient_params = struct(...
        'n', 1, ...
        'gridscale', max_gridscale, ...
        'orientation', test_orientations(i), ...
        'phase_offset', [0, 0], ...
        'description', cfg.grid.description, ...
        'min_fr', cfg.neurons.min_fr, ...
        'max_fr', cfg.neurons.max_fr);
    gc2_orient = GridCells2Cos(agent, gc2_orient_params);
    
    ax = nexttile(i);
    
    % 获取 rate map
    rate_maps = gc2_orient.get_state('evaluate_at', 'all');
    rate_map = rate_maps(1, :);
    rate_map = reshape(rate_map, H, W);
    
    % 绘制
    imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
    set(ax, 'YDir', 'normal');
    colormap(ax, cfg.plot.colormap);
    axis(ax, 'equal', 'tight');
    xlabel(ax, 'x (m)', 'FontSize', 11);
    if i == 1
        ylabel(ax, 'y (m)', 'FontSize', 11);
    end
    title(ax, sprintf('方向角 %s', orientation_names{i}), 'FontSize', 12);
    
end

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcells2cos_orientations_comparison');
    paper_visual_export(fig_orient, export_path, cfg);
end

%% 8. 可视化：对比三余弦 vs 双余弦
fprintf('8. 对比三余弦（六边形）vs 双余弦（矩形）...\n');

fig_compare = figure('Name', 'GridCells vs GridCells2Cos Comparison');
set(fig_compare, 'Position', [300, 300, 1200, 500]);
set(fig_compare, 'Color', 'w');
tiledlayout(fig_compare, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

% 创建三余弦网格细胞（原始 GridCells）
gc_3cos_params = struct(...
    'n', 1, ...
    'gridscale', max_gridscale, ...
    'orientation', 0.0, ...
    'phase_offset', [0, 0], ...
    'description', cfg.grid.description, ...
    'min_fr', cfg.neurons.min_fr, ...
    'max_fr', cfg.neurons.max_fr);
gc_3cos = GridCells(agent, gc_3cos_params);

% 创建双余弦网格细胞
gc_2cos = GridCells2Cos(agent, gc_3cos_params);

% 绘制三余弦
ax1 = nexttile(1);
rate_maps_3cos = gc_3cos.get_state('evaluate_at', 'all');
rate_map_3cos = reshape(rate_maps_3cos(1, :), H, W);
imagesc(ax1, env.extent([1, 2]), env.extent([3, 4]), rate_map_3cos);
set(ax1, 'YDir', 'normal');
colormap(ax1, cfg.plot.colormap);
axis(ax1, 'equal', 'tight');
xlabel(ax1, 'x (m)', 'FontSize', 12);
ylabel(ax1, 'y (m)', 'FontSize', 12);
title(ax1, '三余弦 60° (六边形网格)', 'FontSize', 13);

% 绘制双余弦
ax2 = nexttile(2);
rate_maps_2cos = gc_2cos.get_state('evaluate_at', 'all');
rate_map_2cos = reshape(rate_maps_2cos(1, :), H, W);
imagesc(ax2, env.extent([1, 2]), env.extent([3, 4]), rate_map_2cos);
set(ax2, 'YDir', 'normal');
colormap(ax2, cfg.plot.colormap);
axis(ax2, 'equal', 'tight');
xlabel(ax2, 'x (m)', 'FontSize', 12);
ylabel(ax2, 'y (m)', 'FontSize', 12);
title(ax2, '双余弦 90° (矩形网格)', 'FontSize', 13);


% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcells_vs_gridcells2cos_comparison');
    paper_visual_export(fig_compare, export_path, cfg);
end

%% 9. 完成
fprintf('\n====== Demo 结束 ======\n');
if cfg.plot.export_enabled
    fprintf('图片已导出到: %s\n', cfg.dir.output);
    fprintf('包含:\n');
    fprintf('  - gridcells2cos_modules_visual.png/.eps\n');
    fprintf('  - gridcell2cos_single_detail.png/.eps\n');
    fprintf('  - gridcells2cos_types_comparison.png/.eps\n');
    fprintf('  - gridcells2cos_orientations_comparison.png/.eps\n');
    fprintf('  - gridcells_vs_gridcells2cos_comparison.png/.eps\n');
else
    fprintf('未导出图片（config.plot.export_enabled = false）。\n');
end
fprintf('\n图示内容:\n');
fprintf('  1. 不同尺度模块的双余弦网格模式\n');
fprintf('  2. 单个双余弦网格细胞的细节\n');
fprintf('  3. rectified 与 shifted cosines 对比（双余弦）\n');
fprintf('  4. 不同方向角的影响（0°, 22.5°, 45°, 90°）\n');
fprintf('  5. 三余弦（六边形）vs 双余弦（矩形）对比\n');
