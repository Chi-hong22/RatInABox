% config.m - 统一配置文件
% 用途：集中管理所有 Neurons/PlaceCells/GridCells 的默认参数、绘图规范与路径

function cfg = config()
    %% ==================== 目录约定 ====================
    cfg.dir.data = 'matlab/data/';           % 输入数据目录
    cfg.dir.output = 'matlab/output/';       % 输出图片与缓存目录
    cfg.file.agent_path = 'matlab/data/agent_path.csv';  % Agent 轨迹文件 (t,x,y)
    
    %% ==================== 环境参数 ====================
    % 矩形环境，单位：米
    cfg.env.extent = [0, 1, 0, 1];           % [xmin, xmax, ymin, ymax]
    cfg.env.boundary_conditions = 'solid';   % 边界条件：solid
    cfg.env.dimensionality = '2D';
    cfg.env.dx = 0.01;                       % 离散化分辨率 (m)
    
    %% ==================== Agent 参数 ====================
    cfg.agent.dt = 0.01;                     % 时间步长 (s)
    cfg.agent.speed_mean = 0.08;             % 平均速度 (m/s)
    cfg.agent.speed_std = 0.0;               % 速度标准差
    
    %% ==================== Neurons 基类参数 ====================
    cfg.neurons.noise_std = 0.0;             % 噪声标准差 (Hz)
    cfg.neurons.noise_coherence_time = 0.5;  % 噪声相干时间 (s)
    cfg.neurons.min_fr = 0.0;                % 最小发放率 (Hz)
    cfg.neurons.max_fr = 1.0;                % 最大发放率 (Hz)
    cfg.neurons.save_history = true;         % 是否保存历史
    
    %% ==================== PlaceCells 参数 ====================
    cfg.place.n = 10;                        % 细胞数量
    cfg.place.description = 'gaussian';      % 类型：gaussian/gaussian_threshold/diff_of_gaussians/one_hot/top_hat
    cfg.place.widths = 0.20;                 % 感受野宽度 (m)
    cfg.place.wall_geometry = 'geodesic';    % 距离计算：euclidean/geodesic/line_of_sight
    cfg.place.name = 'PlaceCells';
    
    %% ==================== GridCells 参数 ====================
    cfg.grid.n = 30;                         % 细胞数量
    cfg.grid.gridscale = [0.3, 0.5, 0.8];    % 网格尺度 (m), modules 分布
    cfg.grid.orientation = [0, 0.1, 0.2];    % 方向 (rad), modules 分布
    cfg.grid.phase_offset = [0, 2*pi];       % 相位偏移 (rad), uniform 分布
    cfg.grid.description = 'rectified_cosines';  % shifted_cosines 或 rectified_cosines
    cfg.grid.width_ratio = 4/(3*sqrt(3));    % 宽度比（仅 rectified_cosines）
    cfg.grid.name = 'GridCells';
    
    %% ==================== 绘图规范 (paper-visual) ====================
    % 基准：8.8cm 物理宽度、9pt 基准字号、2.0 倍放大
    cfg.plot.base_width_cm = 8.8;            % 基准物理宽度 (cm)
    cfg.plot.base_fontsize_pt = 9;           % 基准字号 (pt)
    cfg.plot.scale_factor = 2.0;             % 放大倍数（显示/导出时）
    cfg.plot.font_name = 'Arial';            % 字体
    cfg.plot.dpi = 600;                      % 导出分辨率
    cfg.plot.format = {'png', 'eps'};        % 导出格式
    cfg.plot.export_enabled = false;         % 是否导出图片（默认关闭，调试更快）
    
    % 计算实际显示/导出尺寸（等比放大）
    cfg.plot.width_cm = cfg.plot.base_width_cm * cfg.plot.scale_factor;    % 实际宽度
    cfg.plot.fontsize_pt = cfg.plot.base_fontsize_pt * cfg.plot.scale_factor;  % 实际字号
    cfg.plot.width_inch = cfg.plot.width_cm / 2.54;  % 转换为英寸（MATLAB 使用）
    
    % Colormap
    cfg.plot.colormap = 'hot';               % 默认 colormap（对应 Python inferno）
    
    % 颜色定义（统一为 [R,G,B]/255 格式）
    cfg.plot.colors.grey = [128, 128, 128] / 255;       % 灰色
    cfg.plot.colors.darkgrey = [64, 64, 64] / 255;      % 深灰
    cfg.plot.colors.lightgrey = [192, 192, 192] / 255;  % 浅灰
    cfg.plot.colors.C1 = [31, 119, 180] / 255;          % MATLAB 默认蓝色（对应 Python C1）
    
    %% ==================== 布局参数 ====================
    cfg.plot.tick_direction = 'out';         % 刻度外向
    cfg.plot.box = 'off';                    % 关闭边框
    cfg.plot.tight_inset = [0.02, 0.08, 0.01, 0.01];  % [左,下,右,上] 边距比例（为底部标签预留空间）
    
end
