classdef GridCells < Neurons
    % GridCells - Grid cell 神经元
    % input: Agent 对象，提供位置信息
    % output: 基于位置的周期性网格发放率
    % pos: Neurons 子类，实现周期性空间编码
    %
    % 描述：Grid cells 在环境中以六边形网格模式发放。发放率由三个60度
    % 相位差的余弦波叠加形成。支持多个模块（modules）。
    %
    % 使用示例：
    %   gcs = GridCells(agent, struct('n', 30, 'gridscale', [0.3, 0.5, 0.8]));
    %   gcs.update();
    %   fr = gcs.firingrate;
    
    properties
        gridscales      % 网格尺度 (n×1)
        orientations    % 方向 (n×1, 仅 2D)
        phase_offsets   % 相位偏移 (n×2 for 2D, n×1 for 1D)
        w               % 余弦方向向量 (n×3×2, 仅 2D)
        description     % 类型：rectified_cosines 或 shifted_cosines
        width_ratio     % 宽度比（仅 rectified_cosines）
    end
    
    methods
        function obj = GridCells(agent, params)
            % 构造函数
            % agent: Agent 对象
            % params: 参数结构体
            
            if nargin < 2
                params = struct();
            end
            
            % 默认参数
            default_params = struct(...
                'n', 30, ...
                'name', 'GridCells', ...
                'gridscale', [0.3, 0.5, 0.8], ...  % modules 分布
                'gridscale_distribution', 'modules', ...
                'orientation', [0, 0.1, 0.2], ...  % modules 分布
                'orientation_distribution', 'modules', ...
                'phase_offset', [0, 2*pi], ...     % uniform 分布
                'phase_offset_distribution', 'uniform', ...
                'description', 'rectified_cosines', ...
                'width_ratio', 4/(3*sqrt(3)), ...
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
            
            % 采样 gridscale（使用静态方法调用）
            if isnumeric(merged_params.gridscale) && ~isscalar(merged_params.gridscale)
                % 数组：直接使用
                gridscales = merged_params.gridscale(:);
                merged_params.n = length(gridscales);
            else
                % 标量或元组：从分布采样
                gridscales = GridCells.distribution_sampler(...
                    merged_params.gridscale_distribution, ...
                    merged_params.gridscale, ...
                    merged_params.n);
            end
            
            % 调用父类构造函数
            obj@Neurons(agent, merged_params);
            
            % 设置 gridscales
            obj.gridscales = gridscales;
            obj.description = obj.params.description;
            obj.width_ratio = obj.params.width_ratio;
            
            % 采样 phase_offsets
            if strcmp(agent.Environment.dimensionality, '2D')
                D = 2;
            else
                D = 1;
            end
            
            obj.phase_offsets = GridCells.distribution_sampler(...
                obj.params.phase_offset_distribution, ...
                obj.params.phase_offset, ...
                obj.n, D);
            
            % 2D：采样 orientations 并计算余弦方向
            if strcmp(agent.Environment.dimensionality, '2D')
                if isnumeric(obj.params.orientation) && length(obj.params.orientation) > 1
                    orientations = obj.params.orientation(:);
                else
                    orientations = GridCells.distribution_sampler(...
                        obj.params.orientation_distribution, ...
                        obj.params.orientation, ...
                        obj.n);
                end
                obj.orientations = orientations;
                
                % 计算三个余弦方向向量
                obj.w = zeros(obj.n, 3, 2);
                for i = 1:obj.n
                    w1 = [cos(orientations(i)), sin(orientations(i))];
                    w2 = GridCells.rotate_vec(w1, pi/3);
                    w3 = GridCells.rotate_vec(w1, 2*pi/3);
                    obj.w(i, :, :) = [w1; w2; w3];
                end
            end
            
            % 检查 width_ratio
            if strcmp(obj.description, 'rectified_cosines')
                if obj.width_ratio <= 0 || obj.width_ratio > 1
                    warning('GridCells:WidthRatio', ...
                        'width_ratio should be between 0 and 1, got %.2f', obj.width_ratio);
                end
            end
        end
        
        function firingrate = get_state(obj, varargin)
            % 获取 grid cell 发放率
            % 可选参数：
            %   'evaluate_at': 'agent' (默认) | 'all' | pos 数组
            
            % 解析参数
            p = inputParser;
            addParameter(p, 'evaluate_at', 'agent');
            addParameter(p, 'pos', []);
            parse(p, varargin{:});
            
            % 确定位置
            if strcmp(p.Results.evaluate_at, 'agent')
                pos = obj.Agent.pos;
            elseif strcmp(p.Results.evaluate_at, 'all')
                pos = obj.Agent.Environment.flattened_discrete_coords;
            else
                pos = p.Results.pos;
            end
            
            pos = reshape(pos, [], size(pos, ndims(pos)));  % 确保 N×D
            N_pos = size(pos, 1);
            
            if strcmp(obj.Agent.Environment.dimensionality, '2D')
                % 2D：三个余弦波叠加
                % origin: n×2
                origin = obj.gridscales .* obj.phase_offsets / (2 * pi);
                
                % vecs: n×N_pos×2（从 pos 到 origin 的向量，对应 Python utils.get_vectors_between）
                vecs = zeros(obj.n, N_pos, 2);
                for i = 1:obj.n
                    vecs(i, :, :) = origin(i, :) - pos;  % 注意：向量从 pos2 到 pos1
                end
                
                % 计算相位（phi = 2*pi/gridscale * (vec · w)）
                % n×N_pos
                phi_1 = zeros(obj.n, N_pos);
                phi_2 = zeros(obj.n, N_pos);
                phi_3 = zeros(obj.n, N_pos);
                for i = 1:obj.n
                    % 提取当前细胞的方向向量（避免 squeeze 在 n=1 时的维度问题）
                    w1_i = reshape(obj.w(i, 1, :), 1, 2);  % 1×2
                    w2_i = reshape(obj.w(i, 2, :), 1, 2);  % 1×2
                    w3_i = reshape(obj.w(i, 3, :), 1, 2);  % 1×2
                    
                    % 提取当前细胞的向量（N_pos×2）
                    vecs_i = reshape(vecs(i, :, :), N_pos, 2);  % N_pos×2
                    
                    % 计算点积（广播）
                    phi_1(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w1_i, 2);
                    phi_2(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w2_i, 2);
                    phi_3(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w3_i, 2);
                end
                
                % 计算发放率
                if strcmp(obj.description, 'rectified_cosines')
                    firingrate = (1/3) * (cos(phi_1) + cos(phi_2) + cos(phi_3));
                    
                    % 归一化：计算全宽处的发放率
                    firing_rate_at_full_width = (1/3) * (2*cos(sqrt(3)*pi*obj.width_ratio/2) + 1);
                    firingrate = (firingrate - firing_rate_at_full_width) / (1 - firing_rate_at_full_width);
                    firingrate(firingrate < 0) = 0;
                    
                elseif strcmp(obj.description, 'shifted_cosines')
                    firingrate = (2/3) * ((1/3) * (cos(phi_1) + cos(phi_2) + cos(phi_3)) + 0.5);
                else
                    error('GridCells:InvalidDescription', 'Unknown description: %s', obj.description);
                end
                
            else
                % 1D：单个余弦波
                % n×N_pos
                firingrate = cos(((2*pi) ./ obj.gridscales) .* pos.' - obj.phase_offsets);
                
                if contains(obj.description, 'rectified_cosines')
                    firing_rate_at_full_width = cos(obj.width_ratio * pi);
                    firingrate = (firingrate - firing_rate_at_full_width) / (1 - firing_rate_at_full_width);
                    firingrate(firingrate < 0) = 0;
                elseif contains(obj.description, 'shifted_cosines')
                    firingrate = 0.5 * (firingrate + 1);
                end
            end
            
            % 缩放到 [min_fr, max_fr]
            firingrate = firingrate * (obj.max_fr - obj.min_fr) + obj.min_fr;
        end
    end
    
    methods (Static, Access = private)
        function samples = distribution_sampler(dist_name, params, n, D)
            % 从分布采样
            % dist_name: 'modules', 'uniform', 'delta'
            % params: 参数（标量、数组或元组）
            % n: 样本数
            % D: 维度（可选，默认1）
            
            if nargin < 4
                D = 1;
            end
            
            switch dist_name
                case 'modules'
                    % params 是模块值列表，均匀分配给 n 个细胞
                    if isnumeric(params)
                        module_vals = params(:);
                    else
                        error('modules distribution requires numeric array');
                    end
                    n_modules = length(module_vals);
                    samples = repelem(module_vals, ceil(n / n_modules));
                    samples = samples(1:n);
                    if D > 1
                        samples = repmat(samples, 1, D);
                    end
                    
                case 'uniform'
                    % params 是 [low, high]
                    if length(params) == 2
                        low = params(1);
                        high = params(2);
                    elseif isscalar(params)
                        low = 0.5 * params;
                        high = 1.5 * params;
                    else
                        error('uniform distribution requires [low, high]');
                    end
                    samples = low + (high - low) * rand(n, D);
                    
                case 'delta'
                    % params 是单个值或向量
                    if isscalar(params)
                        samples = params * ones(n, D);
                    elseif isvector(params) && length(params) == D
                        % params 是 D 维向量，每个细胞重复此向量
                        samples = repmat(params(:)', n, 1);
                    else
                        error('delta distribution params must be scalar or D-dim vector');
                    end
                    
                otherwise
                    error('GridCells:UnknownDistribution', ...
                        'Unknown distribution: %s', dist_name);
            end
            
            if D == 1
                samples = samples(:);
            end
        end
        
        function v_rot = rotate_vec(v, angle)
            % 旋转 2D 向量
            R = [cos(angle), -sin(angle); sin(angle), cos(angle)];
            v_rot = (R * v(:))';
        end
    end
end
