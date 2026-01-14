function plot_utils()
% plot_utils - 绘图工具函数集合
% 
% 提供：
%   - plot_rate_map: 绘制 rate map
%   - plot_rate_timeseries: 绘制发放率时间序列
%   - plot_environment: 绘制环境
%
% 所有函数遵循 paper-visual 规范

end


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
parse(p, varargin{:});

% 加载配置
cfg = config();

% 选择神经元
chosen = neurons.return_list_of_neurons(p.Results.chosen_neurons);
N_neurons = length(chosen);

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
fig = figure('Visible', 'on');

% 多子图布局
n_cols = min(N_neurons, 5);
n_rows = ceil(N_neurons / n_cols);

for i = 1:N_neurons
    ax = subplot(n_rows, n_cols, i);
    
    % 获取该神经元的 rate map
    rate_map = reshape(rate_maps(i, :), H, W);
    
    % 绘制
    imagesc(ax, env.extent([1, 2]), env.extent([3, 4]), rate_map);
    set(ax, 'YDir', 'normal');  % 修正 Y 轴方向
    colormap(ax, p.Results.colormap);
    axis(ax, 'equal', 'tight');
    
    % 标题
    title(ax, sprintf('Neuron %d', chosen(i)));
    
    % 色条（仅最后一个）
    if p.Results.colorbar && i == N_neurons
        cb = colorbar(ax);
        ylabel(cb, 'Firing rate (Hz)');
    end
    
    % 标签
    if mod(i-1, n_cols) == 0
        ylabel(ax, 'y (m)');
    end
    if i > N_neurons - n_cols
        xlabel(ax, 'x (m)');
    end
end

% 应用 paper-visual
paper_visual(fig, cfg);

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
%
% 返回：
%   fig, ax

% 解析参数
p = inputParser;
addParameter(p, 'chosen_neurons', 'all');
addParameter(p, 't_start', 0);
addParameter(p, 't_end', []);
addParameter(p, 'export', '');
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
fig = figure('Visible', 'on');
ax = axes(fig);

% 绘制（堆叠）
N_neurons = length(chosen);
for i = 1:N_neurons
    plot(ax, t / 60, rate_timeseries(:, i) + (i-1), 'LineWidth', 1);
    hold(ax, 'on');
end
hold(ax, 'off');

% 设置
xlabel(ax, 'Time (min)');
ylabel(ax, 'Neurons');
ylim(ax, [-0.5, N_neurons + 0.5]);
yticks(ax, 0:(N_neurons-1));
yticklabels(ax, arrayfun(@num2str, chosen, 'UniformOutput', false));
grid(ax, 'on');

% 应用 paper-visual
paper_visual(fig, cfg);

% 导出（需开启开关且提供路径）
if cfg.plot.export_enabled && ~isempty(p.Results.export)
    paper_visual_export(fig, p.Results.export, cfg);
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
