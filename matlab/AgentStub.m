classdef AgentStub < handle
    % AgentStub - 简化 Agent 类（从轨迹文件读取，用于 demo）
    % input: Agent 轨迹数据
    % output: 提供位置、速度、方向等状态
    % pos: 支持 Neurons 类的桩实现
    %
    % 使用示例：
    %   agent = AgentStub('matlab/data/agent_path.csv');
    %   agent.step();
    %   pos = agent.pos;
    
    properties
        Environment     % 环境对象
        dt              % 时间步长
        t               % 当前时间
        pos             % 当前位置 (1×2)
        velocity        % 当前速度 (1×2)
        head_direction  % 当前朝向 (1×2, 归一化)
        
        % 轨迹数据
        trajectory      % 完整轨迹 (结构体: t, x, y)
        current_step    % 当前步数
        
        % 历史
        history         % 历史数据 (结构体: t, pos, vel, head_direction)
        
        % 速度统计（用于归一化）
        speed_mean
        speed_std
    end
    
    methods
        function obj = AgentStub(trajectory_file, environment)
            % 构造函数
            % trajectory_file: CSV 文件路径 (t, x, y)
            % environment: EnvironmentStub 对象
            
            if nargin < 2
                environment = EnvironmentStub();
            end
            
            obj.Environment = environment;
            
            % 读取轨迹
            obj.load_trajectory(trajectory_file);
            
            % 初始化
            obj.current_step = 1;
            obj.t = obj.trajectory.t(1);
            obj.pos = [obj.trajectory.x(1), obj.trajectory.y(1)];
            
            % 计算初始速度和方向
            if length(obj.trajectory.t) > 1
                dt = obj.trajectory.t(2) - obj.trajectory.t(1);
                dx = obj.trajectory.x(2) - obj.trajectory.x(1);
                dy = obj.trajectory.y(2) - obj.trajectory.y(1);
                obj.velocity = [dx, dy] / dt;
                obj.dt = dt;
            else
                obj.velocity = [0, 0];
                obj.dt = 0.01;
            end
            
            % 归一化朝向
            if norm(obj.velocity) > 0
                obj.head_direction = obj.velocity / norm(obj.velocity);
            else
                obj.head_direction = [1, 0];
            end
            
            % 计算速度统计
            all_vels = diff([obj.trajectory.x, obj.trajectory.y], 1, 1) / obj.dt;
            all_speeds = sqrt(sum(all_vels.^2, 2));
            obj.speed_mean = mean(all_speeds);
            obj.speed_std = std(all_speeds);
            
            % 初始化历史
            obj.history = struct();
            obj.history.t = {obj.t};
            obj.history.pos = {obj.pos};
            obj.history.vel = {obj.velocity};
            obj.history.head_direction = {obj.head_direction};
        end
        
        function load_trajectory(obj, filepath)
            % 从 CSV 文件加载轨迹
            data = readtable(filepath);
            obj.trajectory = struct();
            obj.trajectory.t = data.t;
            obj.trajectory.x = data.x;
            obj.trajectory.y = data.y;
        end
        
        function step(obj)
            % 前进一步
            if obj.current_step >= length(obj.trajectory.t)
                warning('AgentStub:EndOfTrajectory', 'Reached end of trajectory');
                return;
            end
            
            obj.current_step = obj.current_step + 1;
            obj.t = obj.trajectory.t(obj.current_step);
            obj.pos = [obj.trajectory.x(obj.current_step), obj.trajectory.y(obj.current_step)];
            
            % 计算速度（后向差分）
            if obj.current_step > 1
                dt = obj.trajectory.t(obj.current_step) - obj.trajectory.t(obj.current_step - 1);
                dx = obj.trajectory.x(obj.current_step) - obj.trajectory.x(obj.current_step - 1);
                dy = obj.trajectory.y(obj.current_step) - obj.trajectory.y(obj.current_step - 1);
                obj.velocity = [dx, dy] / dt;
            end
            
            % 更新朝向
            if norm(obj.velocity) > 0
                obj.head_direction = obj.velocity / norm(obj.velocity);
            end
            
            % 保存历史
            obj.history.t{end+1} = obj.t;
            obj.history.pos{end+1} = obj.pos;
            obj.history.vel{end+1} = obj.velocity;
            obj.history.head_direction{end+1} = obj.head_direction;
        end
        
        function hist_arrays = get_history_arrays(obj)
            % 获取历史数据（转换为数组）
            hist_arrays = struct();
            
            if ~isempty(obj.history.t)
                hist_arrays.t = cell2mat(obj.history.t(:));
                
                % pos: T×2
                pos_cell = obj.history.pos;
                hist_arrays.pos = cell2mat(cellfun(@(x) x(:)', pos_cell, 'UniformOutput', false));
                
                % vel: T×2
                vel_cell = obj.history.vel;
                hist_arrays.vel = cell2mat(cellfun(@(x) x(:)', vel_cell, 'UniformOutput', false));
                
                % head_direction: T×2
                hd_cell = obj.history.head_direction;
                hist_arrays.head_direction = cell2mat(cellfun(@(x) x(:)', hd_cell, 'UniformOutput', false));
            else
                hist_arrays.t = [];
                hist_arrays.pos = [];
                hist_arrays.vel = [];
                hist_arrays.head_direction = [];
            end
        end
        
        function slice = get_history_slice(obj, t_start, t_end)
            % 获取历史时间片索引
            hist = obj.get_history_arrays();
            slice = (hist.t >= t_start) & (hist.t <= t_end);
        end
    end
end
