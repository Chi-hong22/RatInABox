function paper_visual(fig, cfg)
% paper_visual - 应用论文级可视化规范
% 
% 用途：设置图窗尺寸、字体、轴外观，确保显示与导出等比放大
%
% 参数：
%   fig: 图窗句柄
%   cfg: 配置结构体（从 config.m 获取）
%
% 规范：
%   - 基准：8.8cm / 9pt / Arial
%   - 导出：2.0倍放大、600dpi、png+eps
%   - 插入文档后等比缩小至基准尺寸
%
% 使用示例：
%   cfg = config();
%   fig = figure();
%   plot(x, y);
%   paper_visual(fig, cfg);
%   paper_visual_export(fig, 'output/my_figure', cfg);

if nargin < 2
    cfg = config();
end

% 提取绘图参数
width_inch = cfg.plot.width_inch;
fontsize_pt = cfg.plot.fontsize_pt;
font_name = cfg.plot.font_name;
tick_direction = cfg.plot.tick_direction;
box_setting = cfg.plot.box;
tight_inset = cfg.plot.tight_inset;

% 设置图窗尺寸（等比放大）
set(fig, 'Units', 'inches');
pos = get(fig, 'Position');
% 保持宽高比，设置宽度
aspect_ratio = pos(4) / pos(3);
pos(3) = width_inch;
pos(4) = width_inch * aspect_ratio;
set(fig, 'Position', pos);

% 设置背景
set(fig, 'Color', 'w');

% 获取所有轴对象
axes_handles = findall(fig, 'Type', 'axes');

for ax = axes_handles'
    % 字体设置（等比放大）
    set(ax, 'FontName', font_name);
    set(ax, 'FontSize', fontsize_pt);
    
    % 轴标签字体
    set(get(ax, 'XLabel'), 'FontName', font_name, 'FontSize', fontsize_pt);
    set(get(ax, 'YLabel'), 'FontName', font_name, 'FontSize', fontsize_pt);
    set(get(ax, 'Title'), 'FontName', font_name, 'FontSize', fontsize_pt);
    
    % 刻度外向
    set(ax, 'TickDir', tick_direction);
    
    % 边框
    set(ax, 'Box', box_setting);
    
    % 紧凑布局（为底部标签预留空间）
    set(ax, 'Units', 'normalized');
    current_pos = get(ax, 'Position');
    % [left, bottom, width, height]
    new_pos = [
        tight_inset(1), ...
        tight_inset(2), ...
        1 - tight_inset(1) - tight_inset(3), ...
        1 - tight_inset(2) - tight_inset(4)
    ];
    set(ax, 'Position', new_pos);
end

% 处理色条
cbars = findall(fig, 'Type', 'colorbar');
for cb = cbars'
    set(cb, 'FontName', font_name, 'FontSize', fontsize_pt);
    set(cb, 'TickDirection', tick_direction);
end

end
