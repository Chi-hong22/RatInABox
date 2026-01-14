function paper_visual_export(fig, filepath, cfg, formats)
% paper_visual_export - 导出图片（论文级规范）
%
% 参数：
%   fig: 图窗句柄
%   filepath: 输出文件路径（不含扩展名）
%   cfg: 配置结构体
%   formats: 格式列表（cell array，默认 {'png', 'eps'}）
%
% 使用示例：
%   paper_visual_export(fig, 'matlab/output/my_figure', cfg);

if nargin < 3
    cfg = config();
end
if nargin < 4
    formats = cfg.plot.format;
end

dpi = cfg.plot.dpi;

% 确保输出目录存在
[folder, ~, ~] = fileparts(filepath);
if ~isempty(folder) && ~exist(folder, 'dir')
    mkdir(folder);
end

% 导出各格式
for i = 1:length(formats)
    fmt = formats{i};
    outfile = [filepath, '.', fmt];
    
    switch lower(fmt)
        case 'png'
            print(fig, outfile, '-dpng', sprintf('-r%d', dpi));
            fprintf('Exported: %s\n', outfile);
            
        case 'eps'
            print(fig, outfile, '-depsc', sprintf('-r%d', dpi));
            fprintf('Exported: %s\n', outfile);
            
        case 'pdf'
            print(fig, outfile, '-dpdf', sprintf('-r%d', dpi));
            fprintf('Exported: %s\n', outfile);
            
        case 'svg'
            print(fig, outfile, '-dsvg', sprintf('-r%d', dpi));
            fprintf('Exported: %s\n', outfile);
            
        otherwise
            warning('paper_visual_export:UnknownFormat', 'Unknown format: %s', fmt);
    end
end

end
