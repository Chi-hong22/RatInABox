classdef EnvironmentStub < handle
    % EnvironmentStub - 简化环境类（仅支持矩形，用于 demo）
    % input: 环境尺寸参数
    % output: 提供位置采样、距离计算等最小接口
    % pos: 支持 Neurons 类的桩实现
    %
    % 使用示例：
    %   env = EnvironmentStub(struct('extent', [0, 1, 0, 1]));
    %   pos = env.sample_positions(10, 'uniform_jitter');
    
    properties
        extent                      % [xmin, xmax, ymin, ymax]
        boundary_conditions         % 'solid'
        dimensionality              % '2D'
        dx                          % 离散化分辨率
        
        discrete_coords             % 离散化坐标网格
        flattened_discrete_coords   % 展平的坐标 (N×2)
    end
    
    methods
        function obj = EnvironmentStub(params)
            % 构造函数
            if nargin < 1
                params = struct();
            end
            
            % 默认参数
            if ~isfield(params, 'extent')
                params.extent = [0, 1, 0, 1];
            end
            if ~isfield(params, 'boundary_conditions')
                params.boundary_conditions = 'solid';
            end
            if ~isfield(params, 'dimensionality')
                params.dimensionality = '2D';
            end
            if ~isfield(params, 'dx')
                params.dx = 0.01;
            end
            
            obj.extent = params.extent;
            obj.boundary_conditions = params.boundary_conditions;
            obj.dimensionality = params.dimensionality;
            obj.dx = params.dx;
            
            % 离散化环境
            obj.discretise_environment();
        end
        
        function discretise_environment(obj)
            % 离散化环境为网格
            xmin = obj.extent(1);
            xmax = obj.extent(2);
            ymin = obj.extent(3);
            ymax = obj.extent(4);
            
            x = xmin:obj.dx:xmax;
            y = ymin:obj.dx:ymax;
            [X, Y] = meshgrid(x, y);
            
            obj.discrete_coords = cat(3, X, Y);  % H×W×2
            obj.flattened_discrete_coords = [X(:), Y(:)];  % (H*W)×2
        end
        
        function positions = sample_positions(obj, n, method)
            % 采样位置
            % n: 样本数
            % method: 'random', 'uniform', 'uniform_jitter'
            
            if nargin < 3
                method = 'uniform_jitter';
            end
            
            xmin = obj.extent(1);
            xmax = obj.extent(2);
            ymin = obj.extent(3);
            ymax = obj.extent(4);
            
            switch method
                case 'random'
                    x = xmin + (xmax - xmin) * rand(n, 1);
                    y = ymin + (ymax - ymin) * rand(n, 1);
                    positions = [x, y];
                    
                case 'uniform'
                    % 均匀网格
                    n_side = ceil(sqrt(n));
                    x = linspace(xmin, xmax, n_side);
                    y = linspace(ymin, ymax, n_side);
                    [X, Y] = meshgrid(x, y);
                    positions = [X(:), Y(:)];
                    positions = positions(1:n, :);
                    
                case 'uniform_jitter'
                    % 均匀网格 + 抖动
                    n_side = ceil(sqrt(n));
                    x = linspace(xmin, xmax, n_side);
                    y = linspace(ymin, ymax, n_side);
                    [X, Y] = meshgrid(x, y);
                    positions = [X(:), Y(:)];
                    positions = positions(1:n, :);
                    
                    % 添加抖动
                    jitter_scale = 0.3 * min(xmax - xmin, ymax - ymin) / n_side;
                    positions = positions + jitter_scale * randn(n, 2);
                    
                    % 裁剪到边界
                    positions(:, 1) = max(xmin, min(xmax, positions(:, 1)));
                    positions(:, 2) = max(ymin, min(ymax, positions(:, 2)));
                    
                otherwise
                    error('EnvironmentStub:InvalidMethod', 'Unknown method: %s', method);
            end
        end
        
        function dist = get_distances_between___accounting_for_environment(obj, pos1, pos2, wall_geometry)
            % 计算位置间距离（考虑环境）
            % pos1: N1×2
            % pos2: N2×2
            % wall_geometry: 'euclidean', 'geodesic', 'line_of_sight'
            % 返回: N1×N2
            
            if nargin < 4
                wall_geometry = 'euclidean';
            end
            
            % 简化版：仅支持欧氏距离（矩形环境）
            if ~strcmp(wall_geometry, 'euclidean')
                warning('EnvironmentStub:WallGeometry', ...
                    'Only euclidean distance supported in stub. Using euclidean.');
            end
            
            N1 = size(pos1, 1);
            N2 = size(pos2, 1);
            dist = zeros(N1, N2);
            
            for i = 1:N1
                diff = pos2 - pos1(i, :);
                dist(i, :) = sqrt(sum(diff.^2, 2));
            end
        end
    end
end
