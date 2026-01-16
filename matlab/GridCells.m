classdef GridCells < Neurons
    % GridCells - Grid cell 神经元（网格细胞）
    % input: Agent 对象，提供位置信息
    % output: 基于位置的周期性六边形网格发放率
    % pos: Neurons 子类，实现周期性空间编码
    % 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的md。
    % 最近更新：2026-01-16 14:55:46 开放 rotate_vec 供子类使用
    %
    % ========== 生物学背景 ==========
    % Grid cells（网格细胞）是哺乳动物内嗅皮层（entorhinal cortex）中的一类
    % 神经元，其发放模式在空间中呈现周期性的六边形网格，为动物提供了一种
    % 类似"坐标系统"的空间表征。
    %
    % ========== 三余弦叠加算法 ==========
    % 本实现采用三个互成 60° 的余弦波叠加来生成六边形网格模式：
    %   r(x) = (1/3) * [cos(φ₁) + cos(φ₂) + cos(φ₃)]
    % 其中：
    %   φᵢ = 2π/λ * [(x - x₀) · wᵢ]
    %   λ: gridscale（网格尺度，控制网格密度）
    %   x₀: origin（网格原点，由 phase_offset 决定）
    %   wᵢ: 方向向量（w₁, w₂, w₃ 互成 60°）
    %
    % ========== 关键参数 ==========
    % - gridscale: 网格尺度（米），决定六边形网格的大小
    % - orientation: 网格方向（弧度），决定网格的旋转角度
    % - phase_offset: 相位偏移，决定网格在空间中的平移
    % - description: 'rectified_cosines'（整流，峰值尖锐）或
    %                'shifted_cosines'（平移，有基础发放率）
    %
    % ========== 模块化组织 ==========
    % Grid cells 通常组织成多个"模块"（modules），每个模块有不同的尺度，
    % 形成多尺度的空间表征（类似傅里叶分解）。
    %
    % ========== 使用示例 ==========
    %   % 创建三个模块的 grid cells
    %   gcs = GridCells(agent, struct('n', 30, 'gridscale', [0.3, 0.5, 0.8]));
    %   gcs.update();           % 更新发放率
    %   fr = gcs.firingrate;    % 获取当前发放率
    
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
            
            %% 阶段1: 准备所有参数（父类构造函数调用前） =====
            % - gridscale: 网格尺度（米）；gridscale_distribution: 尺度采样分布
            % - phase_offset: 相位偏移；phase_offset_distribution: 相位采样分布
            % - orientation: 网格方向（弧度）；orientation_distribution: 方向采样分布
            % - n: 细胞数量；D: 环境维度（1D/2D）
            
            % 1.1 采样 gridscale 网格尺度（米）
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
            
            % 1.2 确定维度(1D\2D)
            if strcmp(agent.Environment.dimensionality, '2D')
                D = 2;
            else
                D = 1;
            end
            
            % 1.3 采样 phase_offsets 相位偏移
            phase_offsets = GridCells.distribution_sampler(...
                merged_params.phase_offset_distribution, ...
                merged_params.phase_offset, ...
                merged_params.n, D);
            
            % 1.4 采样 orientations 网格方向（弧度）并计算 w 向量（仅 2D）
            if strcmp(agent.Environment.dimensionality, '2D')
                if isnumeric(merged_params.orientation) && length(merged_params.orientation) > 1
                    orientations = merged_params.orientation(:);
                else
                    orientations = GridCells.distribution_sampler(...
                        merged_params.orientation_distribution, ...
                        merged_params.orientation, ...
                        merged_params.n);
                end
                
                % ========== 三余弦计算准备：构建方向向量 ==========
                % Grid cell 的六边形网格模式由三个方向的余弦波叠加形成
                % 这三个方向相互间隔 60° (pi/3)，形成等角分布
                %
                % 数学原理：
                %   firing_rate = (1/3) * [cos(φ₁) + cos(φ₂) + cos(φ₃)]
                %   其中：φᵢ = 2π/λ * (vec · wᵢ)
                %   λ: gridscale（网格尺度）
                %   vec: 从当前位置到原点的向量
                %   wᵢ: 第 i 个方向的单位向量
                %
                % w₁, w₂, w₃ 的几何关系：
                %   w₁ = [cos(θ), sin(θ)]           基准方向
                %   w₂ = rotate(w₁, 60°)            逆时针旋转 60°
                %   w₃ = rotate(w₁, 120°)           逆时针旋转 120°
                
                w_vectors = zeros(merged_params.n, 3, 2);
                for i = 1:merged_params.n
                    % 基准方向向量（由 orientation 参数决定）
                    w1 = [cos(orientations(i)), sin(orientations(i))];
                    
                    % 旋转 60° 得到第二个方向
                    w2 = GridCells.rotate_vec(w1, pi/3);
                    
                    % 旋转 120° 得到第三个方向
                    w3 = GridCells.rotate_vec(w1, 2*pi/3);
                    
                    % 存储：w_vectors(i, :, :) = [w1; w2; w3]
                    %   维度：(n个细胞, 3个方向, 2个坐标分量)
                    w_vectors(i, :, :) = [w1; w2; w3];
                end
            else
                orientations = [];
                w_vectors = [];
            end
            
            %% 阶段2: 调用父类构造函数 =====
            obj@Neurons(agent, merged_params);
            
            %% 阶段3: 设置子类特定属性 =====
            obj.gridscales = gridscales;
            obj.phase_offsets = phase_offsets;
            obj.orientations = orientations;
            obj.w = w_vectors;
            obj.description = obj.params.description;
            obj.width_ratio = obj.params.width_ratio;
            
            %% 阶段4: 参数验证 =====
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
                pos = obj.Agent.pos; %Agent的当前位置，用于计算每个细胞在当前位置的发放率
            elseif strcmp(p.Results.evaluate_at, 'all')
                pos = obj.Agent.Environment.flattened_discrete_coords; %环境离散化后的坐标，用于计算每个细胞在每个位置的发放率
            else
                pos = p.Results.pos; %用户手动传入的位置，用于计算每个细胞在指定位置的发放率
            end
            
            pos = reshape(pos, [], size(pos, ndims(pos)));  % 确保 N×D
            N_pos = size(pos, 1);
            
            if strcmp(obj.Agent.Environment.dimensionality, '2D')
                % ============================================================
                % 三余弦叠加算法 - 2D Grid Cell 核心计算
                % ============================================================
                % 生成六边形网格的数学模型：
                %   r(x) = (1/3) * [cos(φ₁) + cos(φ₂) + cos(φ₃)]
                % 其中：
                %   φᵢ = 2π/λ * [(x - x₀) · wᵢ]
                %   λ: gridscale（网格尺度，控制网格密度）
                %   x₀: origin（网格原点，由 phase_offset 决定）
                %   wᵢ: 方向向量（三个互成 60° 的单位向量）
                % ============================================================
                
                % -------- 步骤1: 计算网格原点 --------
                % origin = λ * φ₀ / (2π)
                % 其中 φ₀ 是 phase_offset，控制网格相位偏移
                origin = obj.gridscales .* obj.phase_offsets / (2 * pi);
                % 维度：n×2（n 个细胞，每个有 2D 坐标）
                
                % -------- 步骤2: 计算位置向量 --------
                % vec = origin - pos（从 pos 指向 origin）
                % 注意：与 Python 版本 utils.get_vectors_between(origin, pos) 一致
                vecs = zeros(obj.n, N_pos, 2);
                for i = 1:obj.n
                    vecs(i, :, :) = origin(i, :) - pos;
                end
                % 维度：n×N_pos×2（n 个细胞，N_pos 个位置，2D 向量）
                
                % -------- 步骤3: 计算三个方向的相位 --------
                % φᵢ = 2π/λ * (vec · wᵢ)
                % 点积计算空间位移在每个方向上的投影
                phi_1 = zeros(obj.n, N_pos);  % 方向1的相位
                phi_2 = zeros(obj.n, N_pos);  % 方向2的相位（60°）
                phi_3 = zeros(obj.n, N_pos);  % 方向3的相位（120°）
                
                for i = 1:obj.n
                    % 提取当前细胞的三个方向向量
                    % reshape 是为了避免维度被 MATLAB 自动压缩，确保点积计算稳定可靠。
                    w1_i = reshape(obj.w(i, 1, :), 1, 2);  % 1×2：方向1 [cos(θ), sin(θ)]
                    w2_i = reshape(obj.w(i, 2, :), 1, 2);  % 1×2：方向2（旋转60°）
                    w3_i = reshape(obj.w(i, 3, :), 1, 2);  % 1×2：方向3（旋转120°）
                    
                    % 提取当前细胞的位置向量
                    vecs_i = reshape(vecs(i, :, :), N_pos, 2);  % N_pos×2
                    
                    % 计算相位 = 2π/λ * (vec · w), 点积计算空间位移在每个方向上的投影
                    % sum(vecs_i .* w_i, 2) 计算点积：Σ(vec_x * w_x + vec_y * w_y)
                    phi_1(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w1_i, 2);
                    phi_2(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w2_i, 2);
                    phi_3(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w3_i, 2);
                end
                % 维度：n×N_pos（每个细胞在每个位置的三个相位值）
                
                % -------- 步骤4: 三余弦波叠加 --------
                if strcmp(obj.description, 'rectified_cosines')
                    % 整流余弦模式（负值截断为0）
                    % r(x) = (1/3) * [cos(φ₁) + cos(φ₂) + cos(φ₃)]
                    % 范围：[-1, 1] → 归一化后 → [0, 1]
                    firingrate = (1/3) * (cos(phi_1) + cos(phi_2) + cos(phi_3));
                    
                    % 归一化：使网格"峰"处发放率=1，"全宽"处=0
                    % 全宽位置：到六边形顶点最大距离处
                    % 发放率阈值 = (1/3) * [2*cos(√3π*w/2) + 1]
                    % 其中 w 是 width_ratio（控制网格"点"的大小）
                    firing_rate_at_full_width = (1/3) * (2*cos(sqrt(3)*pi*obj.width_ratio/2) + 1);
                    
                    % 线性归一化到 [0, 1]
                    firingrate = (firingrate - firing_rate_at_full_width) / (1 - firing_rate_at_full_width);
                    
                    % 整流：截断负值（超出网格"点"的区域）
                    firingrate(firingrate < 0) = 0;
                    
                elseif strcmp(obj.description, 'shifted_cosines')
                    % 平移余弦模式（无截断，有基础发放率）
                    % r(x) = (2/3) * [(1/3)(cos(φ₁) + cos(φ₂) + cos(φ₃)) + 0.5]
                    % 范围：[0, 1]（网格"谷"处有基础发放率）
                    firingrate = (2/3) * ((1/3) * (cos(phi_1) + cos(phi_2) + cos(phi_3)) + 0.5);
                else
                    error('GridCells:InvalidDescription', 'Unknown description: %s', obj.description);
                end
                
                % ============================================================
                % 六边形网格形成原理：
                %   当三个相位 φ₁, φ₂, φ₃ 同时接近 0（或 2πk）时，
                %   cos(φᵢ) ≈ 1，三者叠加达到最大值，形成网格"峰"。
                %   由于三个方向互成 60°，这些峰点在空间上形成
                %   周期性的六边形点阵（三角格子的对偶）。
                % ============================================================
                
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
    
    methods (Static, Access = protected)
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
            % 旋转 2D 向量（三余弦方向向量计算的辅助函数）
            %
            % 输入：
            %   v: 2D 向量 [vx, vy]
            %   angle: 旋转角度（弧度，逆时针为正）
            %
            % 输出：
            %   v_rot: 旋转后的向量
            %
            % 数学原理：
            %   旋转矩阵 R(θ) = [cos(θ), -sin(θ)]
            %                    [sin(θ),  cos(θ)]
            %   v_rot = R(θ) * v
            %
            % 在三余弦算法中的应用：
            %   w₂ = rotate_vec(w₁, π/3)   % 旋转 60°
            %   w₃ = rotate_vec(w₁, 2π/3)  % 旋转 120°
            
            R = [cos(angle), -sin(angle); sin(angle), cos(angle)];
            v_rot = (R * v(:))';  % 转置确保输出为行向量
        end
    end
end
