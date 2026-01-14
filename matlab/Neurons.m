classdef Neurons < handle
    % Neurons - 神经元基类（抽象类）
    % input: 依赖 Agent 实例，提供位置/速度等状态
    % output: 提供 firingrate、history 等数据与更新方法
    % pos: 核心神经元模块，子类需实现 get_state() 方法
    %
    % 使用示例：
    %   neurons = PlaceCells(agent, params);  % 通过子类实例化
    %   neurons.update();                     % 更新发放率
    %   fr = neurons.firingrate;              % 获取当前发放率
    %   hist = neurons.get_history_arrays();  % 获取历史数据
    
    properties
        Agent           % Agent 对象引用
        params          % 参数结构体
        n               % 神经元数量
        name            % 名称
        color           % 绘图颜色
        
        % 发放率与噪声
        firingrate      % 当前发放率 (列向量, n×1)
        noise           % 当前噪声 (列向量, n×1)
        noise_std       % 噪声标准差
        noise_coherence_time  % 噪声相干时间
        
        % 发放率范围
        min_fr          % 最小发放率 (Hz)
        max_fr          % 最大发放率 (Hz)
        
        % 历史记录
        save_history    % 是否保存历史
        history         % 历史数据结构体 (t, firingrate, spikes 为 cell 数组)
        
        % 缓存（用于高效访问历史数组）
        history_arrays_cache          % 缓存的历史数组
        last_history_array_cache_time % 上次缓存时间
        
        % 绘图
        colormap        % colormap 名称
    end
    
    methods
        function obj = Neurons(agent, params)
            % 构造函数
            % agent: Agent 对象
            % params: 参数结构体
            
            if nargin < 2
                params = struct();
            end
            
            obj.Agent = agent;
            
            % 默认参数
            default_params = struct(...
                'n', 10, ...
                'name', 'Neurons', ...
                'color', [], ...
                'noise_std', 0.0, ...
                'noise_coherence_time', 0.5, ...
                'min_fr', 0.0, ...
                'max_fr', 1.0, ...
                'save_history', true ...
            );
            
            % 合并参数
            obj.params = obj.merge_params(default_params, params);
            
            % 提取参数到属性
            obj.n = obj.params.n;
            obj.name = obj.params.name;
            obj.color = obj.params.color;
            obj.noise_std = obj.params.noise_std;
            obj.noise_coherence_time = obj.params.noise_coherence_time;
            obj.min_fr = obj.params.min_fr;
            obj.max_fr = obj.params.max_fr;
            obj.save_history = obj.params.save_history;
            
            % 初始化
            obj.firingrate = zeros(obj.n, 1);
            obj.noise = zeros(obj.n, 1);
            
            % 初始化历史（使用 cell 数组动态增长）
            obj.history = struct();
            obj.history.t = {};
            obj.history.firingrate = {};
            obj.history.spikes = {};
            
            % 缓存
            obj.history_arrays_cache = struct();
            obj.last_history_array_cache_time = [];
            
            % 绘图
            obj.colormap = 'hot';  % 对应 Python inferno
        end
        
        function update(obj, varargin)
            % 更新神经元发放率
            % 调用 get_state() 计算发放率，添加噪声，保存历史
            
            % 更新噪声（Ornstein-Uhlenbeck 过程）
            if obj.noise_std > 0
                dnoise = obj.ornstein_uhlenbeck_update(...
                    obj.Agent.dt, ...
                    obj.noise, ...
                    0, ...  % drift
                    obj.noise_std, ...
                    obj.noise_coherence_time);
                obj.noise = obj.noise + dnoise;
            end
            
            % 更新发放率
            if any(isnan(obj.Agent.pos))
                firingrate = zeros(obj.n, 1);
            else
                firingrate = obj.get_state(varargin{:});
            end
            
            obj.firingrate = firingrate(:);  % 确保列向量
            obj.firingrate = obj.firingrate + obj.noise;
            
            % 保存历史
            if obj.save_history
                obj.save_to_history();
            end
        end
        
        function firingrate = get_state(obj, varargin)
            % 获取神经元状态（抽象方法，子类必须实现）
            error('Neurons:NotImplemented', ...
                'Subclass must implement get_state() method');
        end
        
        function save_to_history(obj)
            % 保存当前状态到历史
            % 生成泊松尖峰
            cell_spikes = rand(obj.n, 1) < (obj.Agent.dt * obj.firingrate);
            
            obj.history.t{end+1} = obj.Agent.t;
            obj.history.firingrate{end+1} = obj.firingrate;
            obj.history.spikes{end+1} = cell_spikes;
        end
        
        function reset_history(obj)
            % 重置历史
            obj.history.t = {};
            obj.history.firingrate = {};
            obj.history.spikes = {};
            obj.history_arrays_cache = struct();
            obj.last_history_array_cache_time = [];
        end
        
        function hist_arrays = get_history_arrays(obj)
            % 获取历史数据（转换为数组）
            % 使用缓存机制：仅在时间更新时重新转换
            
            if isempty(obj.last_history_array_cache_time) || ...
               obj.last_history_array_cache_time ~= obj.Agent.t
                
                % 转换 cell 数组到矩阵
                hist_arrays = struct();
                
                if ~isempty(obj.history.t)
                    hist_arrays.t = cell2mat(obj.history.t(:));  % 列向量
                    
                    % firingrate: 每个时间步是 n×1，堆叠为 T×n
                    fr_cell = obj.history.firingrate;
                    hist_arrays.firingrate = cell2mat(cellfun(@(x) x(:)', fr_cell, 'UniformOutput', false));
                    
                    % spikes: 同上
                    sp_cell = obj.history.spikes;
                    hist_arrays.spikes = cell2mat(cellfun(@(x) x(:)', sp_cell, 'UniformOutput', false));
                else
                    hist_arrays.t = [];
                    hist_arrays.firingrate = [];
                    hist_arrays.spikes = [];
                end
                
                % 更新缓存
                obj.history_arrays_cache = hist_arrays;
                obj.last_history_array_cache_time = obj.Agent.t;
            else
                hist_arrays = obj.history_arrays_cache;
            end
        end
        
        function chosen = return_list_of_neurons(obj, which)
            % 返回神经元索引列表
            % which: 'all', 数字, 或索引数组
            
            if ischar(which) || isstring(which)
                if strcmp(which, 'all')
                    chosen = 1:obj.n;
                elseif ~isnan(str2double(which))
                    num = str2double(which);
                    chosen = round(linspace(1, obj.n, min(obj.n, num)));
                else
                    error('Invalid neuron selection: %s', which);
                end
            elseif isnumeric(which)
                if isscalar(which)
                    chosen = round(linspace(1, obj.n, min(obj.n, which)));
                else
                    chosen = which(:)';
                end
            else
                error('Invalid neuron selection type');
            end
        end
    end
    
    methods (Access = protected)
        function merged = merge_params(~, default, user)
            % 合并默认参数和用户参数
            merged = default;
            if ~isempty(user)
                fnames = fieldnames(user);
                for i = 1:length(fnames)
                    merged.(fnames{i}) = user.(fnames{i});
                end
            end
        end
        
        function dnoise = ornstein_uhlenbeck_update(~, dt, x, drift, noise_scale, coherence_time)
            % Ornstein-Uhlenbeck 过程更新
            % dx = -(x - drift)/coherence_time * dt + noise_scale * sqrt(2*dt/coherence_time) * dW
            
            if coherence_time == 0 || noise_scale == 0
                dnoise = zeros(size(x));
                return;
            end
            
            mean_term = -(x - drift) / coherence_time * dt;
            std_term = noise_scale * sqrt(2 * dt / coherence_time);
            dnoise = mean_term + std_term * randn(size(x));
        end
    end
end
