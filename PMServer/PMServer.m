classdef PMServer < handle
% PMSERVER  Server for observing paradigms over a network.
%   PMSERVER(PM, CONFIG) creates a new server for PsychoMonkey. In the
%   process, it modifies the Java dynamic class path, which will destroy
%   global variables. Be careful!
    properties(Constant)
        % Maximum rate at which updates will be sent to the socket, in Hz
        MAX_UPDATE_RATE = 30;
    end

    properties(SetAccess = private, GetAccess = public)
        config;
    end
    
    properties(Access = private)
        server = [];
    end
    
    methods
        function self = PMServer(PM, config)
            % Set Java classpath. This will obliterate global variables.
            pathToPM = fileparts(which('PsychoMonkey.m'));
            javaaddpath(fullfile(pathToPM, 'PMServer', 'bin'));
            javaaddpath(fullfile(pathToPM, 'PMServer', 'Java-WebSocket', 'dist', ...
                'WebSocket.jar'));
            javaaddpath(fullfile(pathToPM, 'PMServer', 'lib', 'jackson-core-2.1.0.jar'));
            javaaddpath(fullfile(pathToPM, 'PMServer', 'lib', 'jackson-annotations-2.1.0.jar'));
            javaaddpath(fullfile(pathToPM, 'PMServer', 'lib', 'jackson-databind-2.1.0.jar'));
            
            self.config = PM.parseOptions(config, struct(...
                'password', 'required' ...
            ));
            
            function onInitialized(~, ~)
                % Initialize server
                self.server = javaObject('com.simonster.PsychoMonkey.PMServer', ...
                    [fieldnames(PM.config); {'displaySize'}], ...
                    [struct2cell(PM.config); {PM.displaySize}], ...
                    self.config.password);

                % Register listeners
                lastEyePositionUpdateTime = -1;
                drawCommands = {};
                function onTargetsChanged(~, ~)
                    self.server.updateTargets(PM.targetRects, PM.targetIsOval);
                end
                function onInfoChanged(~, ~)
                    if isstruct(PM.keyInfo)
                        keyInfo = self.server.constructMap(fieldnames(PM.keyInfo), struct2cell(PM.keyInfo));
                    else
                        keyInfo = [];
                    end
                    if ~isempty(PM.trialInfo)
                        trialInfo = self.server.constructMap(keys(PM.trialInfo), values(PM.trialInfo));
                    else
                        trialInfo = [];
                    end
                    self.server.updateStatus(PM.state, keyInfo, trialInfo);
                end
                function onScreenCommand(~, event)
                    if strcmp(event.command, 'Flip')
                        self.server.updateDisplay(drawCommands);
                        drawCommands = {};
                    elseif(strcmp(event.command, 'MakeTexture'))
                        self.server.addTexture(event.textureIndex, event.arguments{1});
                    else
                        drawCommands{end+1} = [{event.command} event.arguments];
                    end
                end
                function onTick(~, ~)
                    t = GetSecs();
                    if t-lastEyePositionUpdateTime > 1/self.MAX_UPDATE_RATE
                        lastEyePositionUpdateTime = t;
                        eyePosition = PM.EyeTracker.getEyePosition();
                        self.server.updateEyePosition(eyePosition(1), eyePosition(2));
                    end

                    keys = self.server.getPressedKeys();
                    if ~isempty(keys)
                        PM.simulateKeyPress(cell(keys));
                    end
                end
                function onJuice(~, event)
                    self.server.juiceGiven(event.time, event.between, event.reps);
                end
                addlistener(PM, 'targetsChanged', @onTargetsChanged);
                addlistener(PM, 'stateChanged', @onInfoChanged);
                addlistener(PM, 'keyInfoChanged', @onInfoChanged);
                addlistener(PM, 'trialInfoChanged', @onInfoChanged);
                addlistener(PM, 'screenCommand', @onScreenCommand);
                addlistener(PM, 'tick', @onTick);
                if ~isempty(PM.DAQ)
                    addlistener(PM.DAQ, 'juice', @onJuice);
                end
            end
            addlistener(PM, 'initialized', @onInitialized);
        end
        
        function delete(self)
            if ~isempty(self.server)
                self.server.stop();
            end
        end
    end
end
