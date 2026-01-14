classdef PlaceCells < Neurons
    % PlaceCells - Place cell 神经元
    % input: Agent 对象，提供位置信息
    % output: 基于位置的空间选择性发放率
    % pos: Neurons 子类，实现空间编码
    %
    % 描述：Place cells 在环境中特定位置发放。发放率由 Agent 到 place cell
    % 中心的距离决定。支持多种激活函数类型。
    %
    % 使用示例：
    %   pcs = PlaceCells(agent, struct('n', 10, 'widths', 0.2));
    %   pcs.update();
    %   fr = pcs.firingrate;
    
    properties
        place_cell_centres  % Place cell 中心位置 (n×2)
        place_cell_widths   % Place cell 宽度 (n×1)
        description         % 激活函数类型
        wall_geometry       % 距离计算几何
    end
    
    methods
        function obj = PlaceCells(agent, params)
            % 构造函数
            % agent: Agent 对象
            % params: 参数结构体
            
            if nargin < 2
                params = struct();
            end
            
            % 默认参数
            default_params = struct(...
                'n', 10, ...
                'name', 'PlaceCells', ...
                'description', 'gaussian', ...
                'widths', 0.20, ...
                'place_cell_centres', [], ...
                'wall_geometry', 'geodesic', ...
                'min_fr', 0.0, ...
                'max_fr', 1.0 ...
            );
            
            % 合并参数（手动，不使用 obj.）
            merged_params = default_params;
            if ~isempty(params)
                fnames = fieldnames(params);
                for i = 1:length(fnames)
                    merged_params.(fnames{i}) = params.(fnames{i});
                end
            end
            
            % 采样 place cell 中心
            if isempty(merged_params.place_cell_centres)
                merged_params.place_cell_centres = ...
                    agent.Environment.sample_positions(merged_params.n, 'uniform_jitter');
            elseif ischar(merged_params.place_cell_centres) || isstring(merged_params.place_cell_centres)
                method = char(merged_params.place_cell_centres);
                if ismember(method, {'random', 'uniform', 'uniform_jitter'})
                    merged_params.place_cell_centres = ...
                        agent.Environment.sample_positions(merged_params.n, method);
                else
                    error('PlaceCells:InvalidCentres', ...
                        'place_cell_centres must be empty, an array, or one of: random, uniform, uniform_jitter');
                end
            else
                % 用户提供的中心，更新 n
                merged_params.n = size(merged_params.place_cell_centres, 1);
            end
            
            % 调用父类构造函数
            obj@Neurons(agent, merged_params);
            
            % 设置属性
            obj.place_cell_centres = obj.params.place_cell_centres;
            obj.place_cell_widths = obj.params.widths * ones(obj.n, 1);
            obj.description = obj.params.description;
            obj.wall_geometry = obj.params.wall_geometry;
            
            % 检查 wall_geometry 兼容性（简化版，矩形环境）
            if strcmp(agent.Environment.boundary_conditions, 'periodic')
                if ismember(obj.wall_geometry, {'line_of_sight', 'geodesic'})
                    warning('PlaceCells:WallGeometry', ...
                        '%s wall geometry only works with solid boundaries. Using euclidean.', ...
                        obj.wall_geometry);
                    obj.wall_geometry = 'euclidean';
                end
            end
        end
        
        function firingrate = get_state(obj, varargin)
            % 获取 place cell 发放率
            % 可选参数：
            %   'evaluate_at': 'agent' (默认) | 'all' | pos 数组
            
            % 解析参数
            p = inputParser;
            addParameter(p, 'evaluate_at', 'agent', @(x) ischar(x) || isstring(x));
            addParameter(p, 'pos', [], @isnumeric);
            parse(p, varargin{:});
            
            % 确定位置
            if strcmp(p.Results.evaluate_at, 'agent')
                pos = obj.Agent.pos;
            elseif strcmp(p.Results.evaluate_at, 'all')
                pos = obj.Agent.Environment.flattened_discrete_coords;
            else
                pos = p.Results.pos;
            end
            
            pos = reshape(pos, [], size(pos, ndims(pos)));  % 确保 N×2
            
            % 计算距离（考虑环境）
            dist = obj.Agent.Environment.get_distances_between___accounting_for_environment(...
                obj.place_cell_centres, pos, obj.wall_geometry);
            
            % dist: n×N_pos
            widths = obj.place_cell_widths;  % n×1
            
            % 根据描述计算发放率
            switch obj.description
                case 'gaussian'
                    firingrate = exp(-(dist.^2) ./ (2 * (widths.^2)));
                    
                case 'gaussian_threshold'
                    firingrate = max(0, ...
                        exp(-(dist.^2) ./ (2 * (widths.^2))) - exp(-0.5)) ...
                        / (1 - exp(-0.5));
                    
                case 'diff_of_gaussians'
                    ratio = 1.5;
                    firingrate = exp(-(dist.^2) ./ (2 * (widths.^2))) - ...
                        (1 / ratio^2) * exp(-(dist.^2) ./ (2 * ((ratio * widths).^2)));
                    firingrate = firingrate * ratio^2 / (ratio^2 - 1);
                    
                case 'one_hot'
                    [~, closest_centres] = min(abs(dist), [], 1);
                    firingrate = zeros(obj.n, size(pos, 1));
                    for i = 1:size(pos, 1)
                        firingrate(closest_centres(i), i) = 1;
                    end
                    
                case 'top_hat'
                    firingrate = double(dist < widths);
                    
                otherwise
                    error('PlaceCells:InvalidDescription', ...
                        'Unknown description: %s', obj.description);
            end
            
            % 缩放到 [min_fr, max_fr]
            firingrate = firingrate * (obj.max_fr - obj.min_fr) + obj.min_fr;
        end
        
        function remap(obj)
            % 重新随机采样 place cell 中心
            obj.place_cell_centres = ...
                obj.Agent.Environment.sample_positions(obj.n, 'uniform_jitter');
        end
    end
end
