% demo_agent_line.m - 完整 demo（直线轨迹 + Place/Grid cells）
%
% 功能：
%   1. 加载配置
%   2. 创建环境和 Agent（从轨迹文件）
%   3. 创建 PlaceCells 和 GridCells
%   4. 运行更新循环
%   5. 可视化 rate map 和时间序列
%   6. 导出图片（paper-visual 规范）
%
% 使用：
%   >> demo_agent_line

clear; close all; clc;

fprintf('====== RatInABox MATLAB Demo：直线轨迹演示 ======\n\n');

%% 1. 加载配置
fprintf('1. 正在加载配置...\n');
cfg = config();

%% 2. 创建环境和 Agent
fprintf('2. 创建环境与 Agent...\n');

% 环境
env_params = struct(...
    'extent', cfg.env.extent, ...
    'boundary_conditions', cfg.env.boundary_conditions, ...
    'dimensionality', cfg.env.dimensionality, ...
    'dx', cfg.env.dx);
env = EnvironmentStub(env_params);

% Agent（从轨迹文件）
agent = AgentStub(cfg.file.agent_path, env);

fprintf('   环境范围: [%.1f, %.1f] x [%.1f, %.1f] 米\n', ...
    env.extent(1), env.extent(2), env.extent(3), env.extent(4));
fprintf('   轨迹: %d 步, dt = %.3f 秒\n', ...
    length(agent.trajectory.t), agent.dt);

%% 3. 创建 PlaceCells
fprintf('3. 创建 PlaceCells...\n');

pc_params = struct(...
    'n', cfg.place.n, ...
    'description', cfg.place.description, ...
    'widths', cfg.place.widths, ...
    'wall_geometry', cfg.place.wall_geometry, ...
    'min_fr', cfg.neurons.min_fr, ...
    'max_fr', cfg.neurons.max_fr);
pcs = PlaceCells(agent, pc_params);

fprintf('   PlaceCells: 数量 = %d, 宽度 = %.2f 米\n', pcs.n, pcs.params.widths);

%% 4. 创建 GridCells
fprintf('4. 创建 GridCells...\n');

gc_params = struct(...
    'n', cfg.grid.n, ...
    'gridscale', cfg.grid.gridscale, ...
    'orientation', cfg.grid.orientation, ...
    'description', cfg.grid.description, ...
    'min_fr', cfg.neurons.min_fr, ...
    'max_fr', cfg.neurons.max_fr);
gcs = GridCells(agent, gc_params);

fprintf('   GridCells: 数量 = %d, 模块数 = %d\n', gcs.n, length(cfg.grid.gridscale));

%% 5. 运行更新循环
fprintf('5. 运行更新循环...\n');

n_steps = length(agent.trajectory.t);
for i = 1:n_steps
    % 更新神经元
    pcs.update();
    gcs.update();
    
    % 前进一步
    if i < n_steps
        agent.step();
    end
    
    % 进度
    if mod(i, 20) == 0 || i == n_steps
        fprintf('   进度: %d/%d (%.1f%%)\n', i, n_steps, 100*i/n_steps);
    end
end

fprintf('   完成！总时长: %.2f 秒\n', agent.t);

%% 6. 可视化：PlaceCells rate map
fprintf('6. 绘制 PlaceCells rate map...\n');

fig_pc_map = figure('Name', 'PlaceCells Rate Map');
chosen = pcs.return_list_of_neurons(min(6, pcs.n));
n_cols = min(length(chosen), 3);
n_rows = ceil(length(chosen) / n_cols);

% 调整窗口大小
set(fig_pc_map, 'Position', [50, 50, 1200, 400*n_rows]);
set(fig_pc_map, 'Color', 'w');

for i = 1:length(chosen)
    ax = subplot(n_rows, n_cols, i);
    
    % 获取 rate map
    rate_maps = pcs.get_state('evaluate_at', 'all');
    rate_map = rate_maps(chosen(i), :);
    
    % 重塑为图像
    H = size(env.discrete_coords, 1);
    W = size(env.discrete_coords, 2);
    rate_map = reshape(rate_map, H, W);
    
    % 绘制
    imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
    set(ax, 'YDir', 'normal');
    colormap(ax, cfg.plot.colormap);
    axis(ax, 'equal', 'tight');
    title(ax, sprintf('位置细胞 %d', chosen(i)), 'FontSize', 11);
    
    if mod(i-1, n_cols) == 0
        ylabel(ax, 'y (m)', 'FontSize', 10);
    end
    if i > length(chosen) - n_cols
        xlabel(ax, 'x (m)', 'FontSize', 10);
    end
    
    % 调整位置
    pos = get(ax, 'Position');
    set(ax, 'Position', [pos(1)*1.02, pos(2)*1.08, pos(3)*0.9, pos(4)*0.85]);
end

% 不应用 paper-visual
% paper_visual(fig_pc_map, cfg);

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'placecells_ratemap');
    paper_visual_export(fig_pc_map, export_path, cfg);
end

%% 7. 可视化：GridCells rate map
fprintf('7. 绘制 GridCells rate map...\n');

fig_gc_map = figure('Name', 'GridCells Rate Map');
chosen = gcs.return_list_of_neurons(min(6, gcs.n));
n_cols = min(length(chosen), 3);
n_rows = ceil(length(chosen) / n_cols);

% 调整窗口大小
set(fig_gc_map, 'Position', [100, 100, 1200, 400*n_rows]);
set(fig_gc_map, 'Color', 'w');

for i = 1:length(chosen)
    ax = subplot(n_rows, n_cols, i);
    
    % 获取 rate map
    rate_maps = gcs.get_state('evaluate_at', 'all');
    rate_map = rate_maps(chosen(i), :);
    
    % 重塑为图像
    H = size(env.discrete_coords, 1);
    W = size(env.discrete_coords, 2);
    rate_map = reshape(rate_map, H, W);
    
    % 绘制
    imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
    set(ax, 'YDir', 'normal');
    colormap(ax, cfg.plot.colormap);
    axis(ax, 'equal', 'tight');
    title(ax, sprintf('网格细胞 %d', chosen(i)), 'FontSize', 11);
    
    if mod(i-1, n_cols) == 0
        ylabel(ax, 'y (m)', 'FontSize', 10);
    end
    if i > length(chosen) - n_cols
        xlabel(ax, 'x (m)', 'FontSize', 10);
    end
    
    % 调整位置
    pos = get(ax, 'Position');
    set(ax, 'Position', [pos(1)*1.02, pos(2)*1.08, pos(3)*0.9, pos(4)*0.85]);
end

% 不应用 paper-visual
% paper_visual(fig_gc_map, cfg);

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'gridcells_ratemap');
    paper_visual_export(fig_gc_map, export_path, cfg);
end

%% 8. 可视化：PlaceCells 时间序列
fprintf('8. 绘制 PlaceCells 时间序列...\n');

fig_pc_ts = figure('Name', 'PlaceCells Timeseries');
% 调整窗口大小
set(fig_pc_ts, 'Position', [150, 150, 1000, 500]);
set(fig_pc_ts, 'Color', 'w');

ax = axes(fig_pc_ts);

hist = pcs.get_history_arrays();
t = hist.t;
chosen = pcs.return_list_of_neurons(min(5, pcs.n));
rate_ts = hist.firingrate(:, chosen);  % T×N

% 绘制（堆叠）
for i = 1:length(chosen)
    plot(ax, t / 60, rate_ts(:, i) + (i-1), 'LineWidth', 1.5);
    hold(ax, 'on');
end
hold(ax, 'off');

xlabel(ax, '时间 (分钟)', 'FontSize', 12);
ylabel(ax, '神经元编号', 'FontSize', 12);
ylim(ax, [-0.5, length(chosen) + 0.5]);
yticks(ax, 0:(length(chosen)-1));
yticklabels(ax, arrayfun(@num2str, chosen, 'UniformOutput', false));
title(ax, '位置细胞发放率时间序列', 'FontSize', 13);
set(ax, 'FontSize', 10);

% 调整轴位置
pos = get(ax, 'Position');
set(ax, 'Position', [pos(1)*1.12, pos(2)*1.12, pos(3)*0.85, pos(4)*0.8]);

% 不应用 paper-visual
% paper_visual(fig_pc_ts, cfg);

% 导出
if cfg.plot.export_enabled
    export_path = fullfile(cfg.dir.output, 'placecells_timeseries');
    paper_visual_export(fig_pc_ts, export_path, cfg);
end

%% 9. 完成
fprintf('\n====== Demo 结束 ======\n');
if cfg.plot.export_enabled
    fprintf('图片已导出到: %s\n', cfg.dir.output);
    fprintf('查看文件:\n');
    fprintf('  - placecells_ratemap.png/.eps\n');
    fprintf('  - gridcells_ratemap.png/.eps\n');
    fprintf('  - placecells_timeseries.png/.eps\n');
else
    fprintf('未导出图片（config.plot.export_enabled = false）。\n');
end
