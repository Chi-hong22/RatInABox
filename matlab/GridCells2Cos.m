classdef GridCells2Cos < GridCells
    % GridCells2Cos - 双余弦网格细胞（两余弦90°交叉）
    % input: Agent 对象，提供位置信息
    % output: 基于两个正交方向余弦叠加的周期性发放率
    % pos: GridCells 子类，用于展示两余弦90°交叉的网格图样
    % 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的md。
    %
    % ========== 算法说明 ==========
    % 本类与父类 GridCells 的区别在于：
    %   - GridCells：三个互成60°的余弦波叠加 → 六边形网格
    %   - GridCells2Cos：两个互成90°的余弦波叠加 → 矩形/条纹网格
    %
    % ========== 两余弦叠加算法 ==========
    % 发放率计算公式：
    %   r(x) = (1/2) * [cos(φ₁) + cos(φ₂)]
    % 其中：
    %   φᵢ = 2π/λ * [(x - x₀) · wᵢ]
    %   λ: gridscale（网格尺度）
    %   x₀: origin（网格原点，由 phase_offset 决定）
    %   w₁, w₂: 两个正交的方向向量（相差 90°）
    %
    % ========== 归一化策略 ==========
    % - rectified_cosines: 线性归一化后截断负值（峰值尖锐）
    % - shifted_cosines: 平移到 [0,1] 范围（有基础发放率）
    %
    % ========== 使用示例 ==========
    %   % 创建双余弦网格细胞
    %   gc2 = GridCells2Cos(agent, struct('n', 20, 'gridscale', 0.4));
    %   gc2.update();
    %   fr = gc2.firingrate;
    %   
    %   % 可视化 rate map
    %   figure; 
    %   plot_utils.plot_ratemap(gc2, agent.Environment);
    
    methods
        function obj = GridCells2Cos(agent, params)
            % 构造函数
            % agent: Agent 对象
            % params: 参数结构体
            
            if nargin < 2
                params = struct();
            end
            
            % 调用父类构造函数（复用参数采样与初始化逻辑）
            obj@GridCells(agent, params);
            
            % 验证环境维度（仅支持 2D）
            if ~strcmp(agent.Environment.dimensionality, '2D')
                error('GridCells2Cos:DimensionError', ...
                    'GridCells2Cos 仅支持 2D 环境，当前环境为 %s', ...
                    agent.Environment.dimensionality);
            end
            
            % 重新计算方向向量为两个正交方向（90°）
            % 覆盖父类的三方向向量
            w_vectors_2d = zeros(obj.n, 2, 2);
            for i = 1:obj.n
                % 基准方向向量
                w1 = [cos(obj.orientations(i)), sin(obj.orientations(i))];
                
                % 旋转 90° 得到第二个方向
                w2 = obj.rotate_vec(w1, pi/2);
                
                % 存储：w_vectors_2d(i, :, :) = [w1; w2]
                %   维度：(n个细胞, 2个方向, 2个坐标分量)
                w_vectors_2d(i, :, :) = [w1; w2];
            end
            
            % 更新 w 属性为两方向向量
            obj.w = w_vectors_2d;
        end
        
        function firingrate = get_state(obj, varargin)
            % 获取双余弦网格细胞发放率
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
            
            % ============================================================
            % 两余弦叠加算法 - 2D Grid Cell 核心计算
            % ============================================================
            % 生成矩形网格的数学模型：
            %   r(x) = (1/2) * [cos(φ₁) + cos(φ₂)]
            % 其中：
            %   φᵢ = 2π/λ * [(x - x₀) · wᵢ]
            %   λ: gridscale（网格尺度）
            %   x₀: origin（网格原点，由 phase_offset 决定）
            %   wᵢ: 方向向量（两个互成 90° 的单位向量）
            % ============================================================
            
            % -------- 步骤1: 计算网格原点 --------
            origin = obj.gridscales .* obj.phase_offsets / (2 * pi);
            % 维度：n×2
            
            % -------- 步骤2: 计算位置向量 --------
            vecs = zeros(obj.n, N_pos, 2);
            for i = 1:obj.n
                vecs(i, :, :) = origin(i, :) - pos;
            end
            % 维度：n×N_pos×2
            
            % -------- 步骤3: 计算两个方向的相位 --------
            phi_1 = zeros(obj.n, N_pos);  % 方向1的相位
            phi_2 = zeros(obj.n, N_pos);  % 方向2的相位（90°）
            
            for i = 1:obj.n
                % 提取当前细胞的两个方向向量
                w1_i = reshape(obj.w(i, 1, :), 1, 2);  % 1×2：方向1
                w2_i = reshape(obj.w(i, 2, :), 1, 2);  % 1×2：方向2（旋转90°）
                
                % 提取当前细胞的位置向量
                vecs_i = reshape(vecs(i, :, :), N_pos, 2);  % N_pos×2
                
                % 计算相位 = 2π/λ * (vec · w)
                phi_1(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w1_i, 2);
                phi_2(i, :) = (2*pi / obj.gridscales(i)) * sum(vecs_i .* w2_i, 2);
            end
            % 维度：n×N_pos
            
            % -------- 步骤4: 两余弦波叠加 --------
            if strcmp(obj.description, 'rectified_cosines')
                % 整流余弦模式（负值截断为0）
                % r(x) = (1/2) * [cos(φ₁) + cos(φ₂)]
                % 范围：[-1, 1] → 归一化后 → [0, 1]
                firingrate = (1/2) * (cos(phi_1) + cos(phi_2));
                
                % 归一化：使网格"峰"处发放率=1，"全宽"处=0
                % 对于两余弦90°模式，最小值出现在两个相位均为π时
                % 此时 cos(π) = -1，故 r_min = (1/2) * (-1 + -1) = -1
                % 为了与父类逻辑一致，我们使用 width_ratio 来控制阈值
                firing_rate_at_full_width = (1/2) * (2*cos(sqrt(2)*pi*obj.width_ratio/2));
                
                % 线性归一化到 [0, 1]
                firingrate = (firingrate - firing_rate_at_full_width) / (1 - firing_rate_at_full_width);
                
                % 整流：截断负值
                firingrate(firingrate < 0) = 0;
                
            elseif strcmp(obj.description, 'shifted_cosines')
                % 平移余弦模式（无截断，有基础发放率）
                % r(x) = 0.5 * [(1/2)(cos(φ₁) + cos(φ₂)) + 1]
                % 范围：[0, 1]
                firingrate = 0.5 * ((1/2) * (cos(phi_1) + cos(phi_2)) + 1);
            else
                error('GridCells2Cos:InvalidDescription', 'Unknown description: %s', obj.description);
            end
            
            % ============================================================
            % 矩形网格形成原理：
            %   当两个相位 φ₁, φ₂ 同时接近 0（或 2πk）时，
            %   cos(φᵢ) ≈ 1，两者叠加达到最大值，形成网格"峰"。
            %   由于两个方向互成 90°，这些峰点在空间上形成
            %   周期性的矩形点阵（或条纹，取决于 gridscale）。
            % ============================================================
            
            % 缩放到 [min_fr, max_fr]
            firingrate = firingrate * (obj.max_fr - obj.min_fr) + obj.min_fr;
        end
    end
end
