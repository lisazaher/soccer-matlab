classdef LiveQueue < Trajectories.GeneralizedTrajectory
    %ACTIONQUEUE Queue storing sequence of trajectories
    %   Manages update and retrieval
    
    properties (Constant, Hidden)
        MAXLEN = 10;
    end
    
    properties (Hidden)
        transitions % Transition times between the data
        data % List of data
        current_time = 0 % Time from beggining of first data
        increment = 0.01 % Time step
        last_hold % Last position expected in data
        speed_enabled = true % Whether or not speed calculation enabled
        end_idx = 0;
    end
    
    methods (Hidden)
        function obj = simplify(obj)
        %SIMPLIFY keeps only the data after the current time
        %   OBJ = SIMPLIFY(OBJ)
        %
        %   This is used to reduce the amount of data stored by
        %   removing data that has already passed.
            while obj.current_time >= obj.transitions(1)
                if obj.isempty
                    obj.current_time = 0;
                    break
                end
                % Remove one object and iteratively simplify
                obj.current_time = obj.current_time - obj.transitions(1);
                obj.end_idx = obj.end_idx - 1;
                for i = 1:obj.end_idx
                    obj.data{i} = obj.data{i + 1};
                end
                obj.transitions(1:obj.end_idx) = obj.transitions(2:obj.end_idx + 1);
                if obj.end_idx == 0
                    obj.transitions(1) = 0;
                end
            end
            obj.duration = sum(obj.transitions(1:obj.end_idx));
        end
        
        function obj = generateHold(obj)
            %GENERATEHOLD records last position of data
            %   OBJ = GENERATEHOLD(OBJ)
            %
            %   When queue runs out of data, the hold generated by this
            %   function is output instead.
            if obj.isempty
                obj.last_hold = obj.data{obj.end_idx}.positionAtTime(0);
            elseif obj.end_idx >= 1
                obj.last_hold = obj.data{obj.end_idx}.positionAtTime(obj.transitions(obj.end_idx));
            end
        end
    end
    
    methods
        function obj = LiveQueue(init_data, speed_enabled)
        %LIVEQUEUE initializes empty queue
        %   OBJ = LIVEQUEUE(INIT_DATA)
        %   OBJ = LIVEQUEUE(INIT_DATA, SPEED_ENABLED)
        %
        %
        %   Arguments
        %
        %   INIT_DATA = [0 x 0] Trajectories.GeneralizedTrajectory
        %       Initial data
        %
        %   SPEED_ENABLED = [1 x 1] Logical : True
        %       Ability to disable speed capture
            % Of length MAXLEN. Done in this silly way because of code
            % generation constraints.
            obj.data = {
                init_data; init_data; init_data; init_data; init_data; ...
                init_data; init_data; init_data; init_data; init_data
            };
            obj.transitions = zeros(obj.MAXLEN, 1);
            if nargin == 2
                obj.speed_enabled = speed_enabled;
            end
            obj.simplify();
            obj.last_hold = init_data.positionAtTime(0);
        end
        
        function position = next(obj)
        %NEXT produces the next element in the queue
        %   POSITION = NEXT(OBJ)
        %
        %   This is essentially the pop from the queue
        %
        %   
        %   Outputs
        %
        %   POSTION = [T]
        %       The next output of the trajectory, time varies.
            obj.current_time = obj.current_time + obj.increment;
            obj.simplify();
            position = obj.positionAtTime(0);
        end
        
        function position = positionAtTime(obj, time)
        %POSITIONATTIME returns the position at the given time
        %   X = POSITIONATTIME(OBJ, T)   
        %
        %
        %   Arguments
        %
        %   T = [1 x 1]
        %       The time to retrieve the positon at
        %
        %
        %   Outputs
        %
        %   X = [T]
        %       The position at time T
            % Determine current action (usually 1) and return position
            if isempty(obj) || time >= obj.duration - obj.current_time
                position = obj.last_hold;
                return
            end
            idx = 1;
            while time > obj.transitions(idx) - obj.current_time && ...
                    idx <= obj.end_idx
                time = time - obj.transitions(idx);
                idx = idx + 1;
            end
            position = obj.data{idx}.positionAtTime(obj.current_time + time);
        end
        
        function speed = speedAtTime(obj, time)            
        %SPEEDATTIME returns the speed at the given team
        %   V = SPEEDATTIME(OBJ, T)
        %
        %
        %   Arguments
        %
        %   T = [1 x 1]
        %       The time to retrieve the speed at
        %
        %
        %   Outputs
        %
        %   V = [T]
        %       The speed at time T
            % Determine current action (usually 1) and return speed
            if ~obj.speed_enabled
                error('Speed not enabled for this data');
            end
            if isempty(obj) || time >= obj.duration - obj.current_time
                if obj.last_hold.isobject
                    speed = Pose(0,0,0,0,0);
                else
                    speed = zeros(size(obj.last_hold));
                end
                return
            end
            idx = 1;
            while time > obj.transitions(idx) - obj.current_time && ...
                    idx <= obj.end_idx
                time = time - obj.transitions(idx);
                idx = idx + 1;
            end
            speed = obj.data{idx}.speedAtTime(obj.current_time + time);
        end
        
        function empty = isempty(obj)
        %ISEMPTY returns true if the queue has no more data
        %   EMPTY = ISEMPTY(OBJ)
        %
        %
        %   Outputs
        %
        %   EMPTY = [1 x 1] Logical
        %       Whether the queue is empty
            empty = ~obj.end_idx;
        end
        
        function len = length(obj)
        %LENGTH returns the length of the queue
        %   LENG = LENGTH(OBJ)
        %
        %
        %   Outputs
        %
        %   LEN = [1 x 1] Logical
        %       Length of the queue
            len = obj.end_idx;
        end
        
        function obj = append(obj, data)
        %APPEND appends a new piece of data to the queue
        %   OBJ = APPEND(OBJ, DATA)
        %
        %
        %   Arguments
        %
        %   DATA = [1 x 1] Trajectories.GeneralizedTrajectory
        %       The new piece of data to append.
            obj.end_idx = obj.end_idx + 1;
            obj.data{obj.end_idx} = data;
            obj.transitions(obj.end_idx) = data.duration;
            obj.generateHold();
            obj.simplify();
        end
    end
    
end
