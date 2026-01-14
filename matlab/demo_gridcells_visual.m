% demo_gridcells_visual.m - GridCells 可视化 demo（无需 Agent）
%
% 功能：
%   1. 创建"虚拟"环境和 Agent
%   2. 创建多组不同参数的 GridCells
%   3. 可视化 rate map（展示网格模式）
%   4. 导出图片（paper-visual 规范）
%
% 特点：
%   - 无需真实轨迹，仅用于展示 Grid cells 的理论特性
%   - 展示不同 gridscale、orientation 的效果
%   - 大部分参数从 config.m 读取，特殊参数有注释说明
%
% 参数说明：
%   - 通用参数（min_fr, max_fr, description 等）从 config 读取
%   - 展示用特殊参数（gridscales, orientations 等）在代码中设置并注释
%
% 使用：
%   >> demo_gridcells_visual

clear; close all; clc;

fprintf('====== RatInABox MATLAB Demo：GridCells 可视化 ======\n\n');

%% 1. 加载配置
fprintf('1. 正在加载配置...\n');
cfg = config();

%% 2. 创建虚拟环境和 Agent
fprintf('2. 创建虚拟环境与 Agent...\n');

% 环境（使用 config 参数，但扩大范围以更好展示网格）
env_params = struct(...
    'extent', [0, 1.5, 0, 1.5], ...  % 特殊设置：比默认更大，便于展示网格模式
    'boundary_conditions', cfg.env.boundary_conditions, ...
    'dimensionality', cfg.env.dimensionality, ...
    'dx', cfg.env.dx);
env = EnvironmentStub(env_params);

% 虚拟 Agent（只需提供位置，不需要轨迹）
agent = struct();
agent.Environment = env;
agent.dt = 0.01;
agent.t = 0;
agent.pos = [0.5, 0.5];  % 固定位置
agent.velocity = [0, 0];
agent.head_direction = [1, 0];
agent.speed_mean = 0.1;
agent.speed_std = 0.0;

fprintf('   环境范围: [%.1f, %.1f] x [%.1f, %.1f] 米\n', ...
    env.extent(1), env.extent(2), env.extent(3), env.extent(4));

%% 3. 创建多组 GridCells（不同参数）
fprintf('3. 创建多组 GridCells...\n');

% 配置：3 个模块，不同尺度（特殊设置以展示效果）
gridscales = [0.2, 0.4, 0.6];  % 特殊设置：更密集的尺度以便观察
orientations = [0, 0.1, 0.2];  % 特殊设置：略微不同的方向
n_modules = length(gridscales);
n_per_module = 2;  % 每个模块 2 个细胞

gcs_list = cell(n_modules, 1);
for i = 1:n_modules
    gc_params = struct(...
        'n', n_per_module, ...
        'gridscale', gridscales(i), ...
        'gridscale_distribution', 'delta', ...
        'orientation', orientations(i), ...
        'orientation_distribution', 'delta', ...
        'phase_offset', cfg.grid.phase_offset, ...        % 从 config 读取
        'phase_offset_distribution', 'uniform', ...
        'description', cfg.grid.description, ...          % 从 config 读取
        'min_fr', cfg.neurons.min_fr, ...                 % 从 config 读取
        'max_fr', cfg.neurons.max_fr);                    % 从 config 读取
    
    gcs_list{i} = GridCells(agent, gc_params);
    fprintf('   模块 %d: gridscale = %.2f m, orientation = %.2f rad\n', ...
        i, gridscales(i), orientations(i));
end

%% 4. 可视化：展示不同模块的 rate map
fprintf('4. 绘制各模块 rate map...\n');

fig = figure('Name', 'GridCells Modules Visualization');
% 调整窗口大小：增加高度以容纳标题和标签
set(fig, 'Position', [100, 100, 1400, 550]);
set(fig, 'Color', 'w');

plot_idx = 1;
axes_list = [];
for mod_idx = 1:n_modules
    gcs = gcs_list{mod_idx};
    
    for cell_idx = 1:n_per_module
        ax = subplot(n_modules, n_per_module, plot_idx);
        axes_list = [axes_list, ax];
        
        % 获取 rate map
        rate_maps = gcs.get_state('evaluate_at', 'all');
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
        
        % 标题（简化，避免多行）
        title(ax, sprintf('模块%d 细胞%d (%.2fm)', ...
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

% 手动调整子图间距，确保标题和标签显示完整
for i = 1:length(axes_list)
    ax = axes_list(i);
    pos = get(ax, 'Position');
    % 调整：[left, bottom, width, height]
    % 增加底部和顶部空间，减少宽度以增加间距
    new_pos = [pos(1)*1.02, pos(2)*1.1, pos(3)*0.88, pos(4)*0.82];
    set(ax, 'Position', new_pos);
end

% 不应用 paper-visual，避免覆盖手动调整
% paper_visual(fig, cfg);

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcells_modules_visual');
    paper_visual_export(fig, export_path, cfg);
end

%% 5. 可视化：单个 Grid cell 详细展示
fprintf('5. 绘制单个 GridCell 细节...\n');

% 创建单个 grid cell（使用 config 默认参数）
gc_single_params = struct(...
    'n', 1, ...
    'gridscale', cfg.grid.gridscale(1), ...               % 从 config 读取第一个模块尺度
    'gridscale_distribution', 'delta', ...
    'orientation', 0.0, ...
    'orientation_distribution', 'delta', ...
    'phase_offset', [0, 0], ...                           % 修复：使用 [0,0] 展示标准网格
    'phase_offset_distribution', 'delta', ...
    'description', cfg.grid.description, ...              % 从 config 读取
    'min_fr', cfg.neurons.min_fr, ...                     % 从 config 读取
    'max_fr', cfg.neurons.max_fr);                        % 从 config 读取
gc_single = GridCells(agent, gc_single_params);

fig_single = figure('Name', 'GridCell Detail');
% 调整窗口大小以适应色条
set(fig_single, 'Position', [150, 150, 700, 600]);
set(fig_single, 'Color', 'w');

% 获取 rate map
rate_maps = gc_single.get_state('evaluate_at', 'all');
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
title(ax, sprintf('网格细胞 (尺度=%.2f m)', gc_single.gridscales(1)), 'FontSize', 13);

% 添加色条
cb = colorbar(ax);
ylabel(cb, '发放率 (Hz)', 'FontSize', 11);
set(cb, 'FontSize', 10);

% 调整轴位置以容纳色条
pos = get(ax, 'Position');
set(ax, 'Position', [pos(1)*1.1, pos(2)*1.15, pos(3)*0.75, pos(4)*0.75]);

% 不应用 paper-visual
% paper_visual(fig_single, cfg);

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcell_single_detail');
    paper_visual_export(fig_single, export_path, cfg);
end

%% 6. 可视化：不同描述类型对比
fprintf('6. 对比不同描述类型...\n');

descriptions = {'rectified_cosines', 'shifted_cosines'};
desc_names = {'截断余弦 (rectified)', '平移余弦 (shifted)'};
fig_types = figure('Name', 'GridCell Types Comparison');
% 调整窗口大小
set(fig_types, 'Position', [200, 200, 1200, 500]);
set(fig_types, 'Color', 'w');

for i = 1:length(descriptions)
    gc_type_params = struct(...
        'n', 1, ...
        'gridscale', cfg.grid.gridscale(1), ...           % 从 config 读取
        'orientation', 0.0, ...
        'phase_offset', 0.0, ...                          % 特殊设置：固定相位以对比
        'description', descriptions{i}, ...               % 特殊设置：对比不同描述类型
        'min_fr', cfg.neurons.min_fr, ...                 % 从 config 读取
        'max_fr', cfg.neurons.max_fr);                    % 从 config 读取
    gc_type = GridCells(agent, gc_type_params);
    
    ax = subplot(1, 2, i);
    
    % 获取 rate map
    rate_maps = gc_type.get_state('evaluate_at', 'all');
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
    
    % 调整子图位置
    pos = get(ax, 'Position');
    set(ax, 'Position', [pos(1)*1.05, pos(2)*1.15, pos(3)*0.85, pos(4)*0.75]);
end

% 不应用 paper-visual
% paper_visual(fig_types, cfg);

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcells_types_comparison');
    paper_visual_export(fig_types, export_path, cfg);
end

%% 7. 完成
fprintf('\n====== Demo 结束 ======\n');
if cfg.plot.export_enabled
    fprintf('图片已导出到: %s\n', cfg.dir.output);
    fprintf('包含:\n');
    fprintf('  - gridcells_modules_visual.png/.eps\n');
    fprintf('  - gridcell_single_detail.png/.eps\n');
    fprintf('  - gridcells_types_comparison.png/.eps\n');
else
    fprintf('未导出图片（config.plot.export_enabled = false）。\n');
end
fprintf('\n图示内容:\n');
fprintf('  1. 不同尺度模块的网格模式\n');
fprintf('  2. 单个网格细胞的细节\n');
fprintf('  3. rectified 与 shifted cosines 对比\n');
