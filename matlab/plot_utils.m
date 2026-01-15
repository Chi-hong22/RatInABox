% plot_utils.m - 绘图工具函数集合
% input: Neurons/Environment/Agent 对象与 config.m 视觉规范
% output: 返回图窗/坐标轴句柄并按需导出图像
% pos: MATLAB 可视化工具函数集合
% 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的md。
%
% 提供：
%   - plot_rate_map: 绘制 rate map
%   - plot_rate_timeseries: 绘制发放率时间序列
%   - plot_agent_trajectory: 绘制 Agent 轨迹
%   - plot_environment: 绘制环境
%
% 所有函数遵循 paper-visual 规范

classdef plot_utils
    methods (Static)


function [fig, ax] = plot_rate_map(neurons, varargin)
% plot_rate_map - 绘制神经元 rate map
%
% 参数：
%   neurons: Neurons 对象
%   可选参数：
%     'chosen_neurons': 'all' 或索引数组
%     'method': 'groundtruth' (默认) 或 'history'
%     'colormap': colormap 名称（默认从 config）
%     'colorbar': true/false
%     'export': 输出文件路径（不含扩展名）
%     'layout': 'subplot' 或 'tiled'
%     'n_cols': 每行子图数量
%     'fig_position': 图窗位置 [x y w h]
%     'fig_name': 图窗名称
%     'title_prefix': 标题前缀（空则默认 Neuron）
%     'title_fontsize': 标题字号
%     'label_fontsize': 坐标轴字号
%     'apply_paper_visual': 是否应用 paper-visual
%
% 返回：
%   fig, ax: 图窗和轴句柄

% 解析参数
p = inputParser;
addParameter(p, 'chosen_neurons', 'all');
addParameter(p, 'method', 'groundtruth');
addParameter(p, 'colormap', 'hot');
addParameter(p, 'colorbar', true);
addParameter(p, 'export', '');
addParameter(p, 'layout', 'subplot');
addParameter(p, 'n_cols', 5);
addParameter(p, 'fig_position', []);
addParameter(p, 'fig_name', '');
addParameter(p, 'title_prefix', 'Neuron');
addParameter(p, 'title_fontsize', []);
addParameter(p, 'label_fontsize', []);
addParameter(p, 'apply_paper_visual', true);
parse(p, varargin{:});

% 加载配置
cfg = config();

% 选择神经元
chosen = neurons.return_list_of_neurons(p.Results.chosen_neurons);
N_neurons = length(chosen);

n_cols = min(N_neurons, p.Results.n_cols);
n_rows = ceil(N_neurons / n_cols);

% 获取 rate map
if strcmp(p.Results.method, 'groundtruth')
    rate_maps = neurons.get_state('evaluate_at', 'all');  % n×N_pos
    rate_maps = rate_maps(chosen, :);
else
    error('plot_rate_map:MethodNotImplemented', 'Only groundtruth method implemented');
end
% 重塑为图像（假设 2D）
env = neurons.Agent.Environment;
H = size(env.discrete_coords, 1);
W = size(env.discrete_coords, 2);

% 创建图窗
if isempty(p.Results.fig_name)
    fig = figure('Visible', 'on');
else
    fig = figure('Visible', 'on', 'Name', p.Results.fig_name);
end

if ~isempty(p.Results.fig_position)
    set(fig, 'Position', p.Results.fig_position);
end

if strcmp(p.Results.layout, 'tiled')
    tl = tiledlayout(fig, n_rows, n_cols, 'Padding', 'compact', 'TileSpacing', 'compact');
end

for i = 1:N_neurons
    if strcmp(p.Results.layout, 'tiled')
        ax = nexttile(tl, i);
    else
        ax = subplot(n_rows, n_cols, i);
    end
    
    % 获取该神经元的 rate map
    rate_map = reshape(rate_maps(i, :), H, W);
    
    % 绘制
    imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
    set(ax, 'YDir', 'normal');  % 修正 Y 轴方向
    colormap(ax, p.Results.colormap);
    axis(ax, 'equal', 'tight');
    
    % 标题
    if isempty(p.Results.title_prefix)
        title_text = sprintf('Neuron %d', chosen(i));
    else
        title_text = sprintf('%s %d', p.Results.title_prefix, chosen(i));
    end
    if isempty(p.Results.title_fontsize)
        title(ax, title_text);
    else
        title(ax, title_text, 'FontSize', p.Results.title_fontsize);
    end
    
    % 色条（仅最后一个）
    if p.Results.colorbar && i == N_neurons
        cb = colorbar(ax);
        ylabel(cb, 'Firing rate (Hz)');
    end
    
    % 标签
    if mod(i-1, n_cols) == 0
        if isempty(p.Results.label_fontsize)
            ylabel(ax, 'y (m)');
        else
            ylabel(ax, 'y (m)', 'FontSize', p.Results.label_fontsize);
        end
    end
    if i > N_neurons - n_cols
        if isempty(p.Results.label_fontsize)
            xlabel(ax, 'x (m)');
        else
            xlabel(ax, 'x (m)', 'FontSize', p.Results.label_fontsize);
        end
    end
end
% 应用 paper-visual
if p.Results.apply_paper_visual
    paper_visual(fig, cfg);
end

% 导出（需开启开关且提供路径）
if cfg.plot.export_enabled && ~isempty(p.Results.export)
    paper_visual_export(fig, p.Results.export, cfg);
end

end


function [fig, ax] = plot_rate_timeseries(neurons, varargin)
% plot_rate_timeseries - 绘制发放率时间序列
%
% 参数：
%   neurons: Neurons 对象
%   可选参数：
%     'chosen_neurons': 'all' 或索引数组
%     't_start': 开始时间（默认 0）
%     't_end': 结束时间（默认最后）
%     'export': 输出文件路径
%     'fig_position': 图窗位置 [x y w h]
%     'fig_name': 图窗名称
%     'xlabel': X 轴标题
%     'ylabel': Y 轴标题
%     'title': 图标题
%     'line_width': 线宽
%     'axis_fontsize': 坐标轴字号
%     'apply_paper_visual': 是否应用 paper-visual
%
% 返回：
%   fig, ax

% 解析参数
p = inputParser;
addParameter(p, 'chosen_neurons', 'all');
addParameter(p, 't_start', 0);
addParameter(p, 't_end', []);
addParameter(p, 'export', '');
addParameter(p, 'fig_position', []);
addParameter(p, 'fig_name', '');
addParameter(p, 'xlabel', 'Time (min)');
addParameter(p, 'ylabel', 'Neurons');
addParameter(p, 'title', '');
addParameter(p, 'line_width', 1);
addParameter(p, 'axis_fontsize', []);
addParameter(p, 'apply_paper_visual', true);
parse(p, varargin{:});

% 加载配置
cfg = config();

% 获取历史数据
hist = neurons.get_history_arrays();
t = hist.t;
if isempty(p.Results.t_end)
    t_end = t(end);
else
    t_end = p.Results.t_end;
end

% 时间片
slice = (t >= p.Results.t_start) & (t <= t_end);
t = t(slice);
rate_timeseries = hist.firingrate(slice, :);  % T×n

% 选择神经元
chosen = neurons.return_list_of_neurons(p.Results.chosen_neurons);
rate_timeseries = rate_timeseries(:, chosen);  % T×N_chosen

% 创建图窗
if isempty(p.Results.fig_name)
    fig = figure('Visible', 'on');
else
    fig = figure('Visible', 'on', 'Name', p.Results.fig_name);
end
if ~isempty(p.Results.fig_position)
    set(fig, 'Position', p.Results.fig_position);
end
ax = axes(fig);

% 绘制（堆叠）
N_neurons = length(chosen);
for i = 1:N_neurons
    plot(ax, t / 60, rate_timeseries(:, i) + (i-1), 'LineWidth', p.Results.line_width);
    hold(ax, 'on');
end
hold(ax, 'off');

% 设置
xlabel(ax, p.Results.xlabel);
ylabel(ax, p.Results.ylabel);
ylim(ax, [-0.5, N_neurons + 0.5]);
yticks(ax, 0:(N_neurons-1));
yticklabels(ax, arrayfun(@num2str, chosen, 'UniformOutput', false));
grid(ax, 'on');
if ~isempty(p.Results.axis_fontsize)
    set(ax, 'FontSize', p.Results.axis_fontsize);
end
if ~isempty(p.Results.title)
    title(ax, p.Results.title);
end

% 应用 paper-visual
if p.Results.apply_paper_visual
    paper_visual(fig, cfg);
end

% 导出（需开启开关且提供路径）
if cfg.plot.export_enabled && ~isempty(p.Results.export)
    paper_visual_export(fig, p.Results.export, cfg);
end

end


function [fig, ax] = plot_agent_trajectory(agent, varargin)
% plot_agent_trajectory - 绘制 Agent 轨迹
%
% 参数：
%   agent: AgentStub 对象
%   可选参数：
%     'fig_position': 图窗位置 [x y w h]
%     'fig_name': 图窗名称
%     'line_width': 轨迹线宽
%     'marker_size': 起止点标记大小
%     'xlabel': X 轴标题
%     'ylabel': Y 轴标题
%     'title': 图标题
%     'title_fontsize': 标题字号
%     'label_fontsize': 坐标轴字号
%     'axis_fontsize': 坐标轴字号
%     'apply_paper_visual': 是否应用 paper-visual
%     'export': 输出文件路径
%
% 返回：
%   fig, ax

% 解析参数
p = inputParser;
addParameter(p, 'fig_position', []);
addParameter(p, 'fig_name', '');
addParameter(p, 'line_width', 1.5);
addParameter(p, 'marker_size', 6);
addParameter(p, 'xlabel', 'x (m)');
addParameter(p, 'ylabel', 'y (m)');
addParameter(p, 'title', '');
addParameter(p, 'title_fontsize', []);
addParameter(p, 'label_fontsize', []);
addParameter(p, 'axis_fontsize', []);
addParameter(p, 'apply_paper_visual', true);
addParameter(p, 'export', '');
parse(p, varargin{:});

env = agent.Environment;

% 创建图窗
if isempty(p.Results.fig_name)
    fig = figure('Visible', 'on');
else
    fig = figure('Visible', 'on', 'Name', p.Results.fig_name);
end
if ~isempty(p.Results.fig_position)
    set(fig, 'Position', p.Results.fig_position);
end

ax = axes(fig);
plot(ax, agent.trajectory.x, agent.trajectory.y, 'LineWidth', p.Results.line_width);
hold(ax, 'on');
plot(ax, agent.trajectory.x(1), agent.trajectory.y(1), 'o', 'MarkerSize', p.Results.marker_size);
plot(ax, agent.trajectory.x(end), agent.trajectory.y(end), 's', 'MarkerSize', p.Results.marker_size);
hold(ax, 'off');
axis(ax, 'equal', 'tight');
xlim(ax, env.extent([1, 2]));
ylim(ax, env.extent([3, 4]));

if isempty(p.Results.label_fontsize)
    xlabel(ax, p.Results.xlabel);
    ylabel(ax, p.Results.ylabel);
else
    xlabel(ax, p.Results.xlabel, 'FontSize', p.Results.label_fontsize);
    ylabel(ax, p.Results.ylabel, 'FontSize', p.Results.label_fontsize);
end

if ~isempty(p.Results.title)
    if isempty(p.Results.title_fontsize)
        title(ax, p.Results.title);
    else
        title(ax, p.Results.title, 'FontSize', p.Results.title_fontsize);
    end
end

if ~isempty(p.Results.axis_fontsize)
    set(ax, 'FontSize', p.Results.axis_fontsize);
end

if p.Results.apply_paper_visual
    cfg = config();
    paper_visual(fig, cfg);
end

if ~isempty(p.Results.export)
    cfg = config();
    if cfg.plot.export_enabled
        paper_visual_export(fig, p.Results.export, cfg);
    end
end

end


function [fig, ax] = plot_environment(env, varargin)
% plot_environment - 绘制环境
%
% 参数：
%   env: EnvironmentStub 对象
%   可选参数：
%     'fig', 'ax': 已有的图窗/轴
%     'export': 输出文件路径
%
% 返回：
%   fig, ax

% 解析参数
p = inputParser;
addParameter(p, 'fig', []);
addParameter(p, 'ax', []);
addParameter(p, 'export', '');
parse(p, varargin{:});

% 创建或使用现有图窗
if isempty(p.Results.fig)
    fig = figure('Visible', 'on');
else
    fig = p.Results.fig;
end

if isempty(p.Results.ax)
    ax = axes(fig);
else
    ax = p.Results.ax;
end

% 绘制边界
ext = env.extent;
rectangle(ax, 'Position', [ext(1), ext(3), ext(2)-ext(1), ext(4)-ext(3)], ...
    'EdgeColor', 'k', 'LineWidth', 2);

% 设置
axis(ax, 'equal', 'tight');
xlim(ax, [ext(1), ext(2)]);
ylim(ax, [ext(3), ext(4)]);
xlabel(ax, 'x (m)');
ylabel(ax, 'y (m)');

% 应用 paper-visual（如果是新创建的图窗）
if isempty(p.Results.fig)
    cfg = config();
    paper_visual(fig, cfg);
end

% 导出（需开启开关且提供路径）
if ~isempty(p.Results.export)
    cfg = config();
    if cfg.plot.export_enabled
        paper_visual_export(fig, p.Results.export, cfg);
    end
end

    end
end
end
