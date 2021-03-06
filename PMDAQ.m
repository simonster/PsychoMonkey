classdef PMDAQ < handle
% PMDAQ  DAQ abstraction interface
%   PMDAQ(PM, CONFIG) initializes the DAQ device
    properties(Access = private)
        % A buffer of data that has not been requested, up to 60 seconds
        % long. Rows represent samples; columns represent channels.
        buffer;
        
        % The length of the buffer
        bufferLength;
        
        % analoginput object
        ai;
        
        % digitalio object
        dio;
        
        % IDs of channels on the adapter
        channelIDs = [];
        
        % Struct whose members indicate which channels belong to which
        % components.
        channels;

        % Internal things for efficient events
        eventUDDParent;
        eventIndex;
        strobeUDDParent;
        strobeIndex;
        
        PM;
    end
    
    properties(SetAccess = private, GetAccess = public)
        % Configuration object
        config;

        % Function to be executed by PsychoMonkey on tick, if any. We
        % should be able to keep this modular and use notify but we can't
        % because MATLAB is awful.
        tick = [];
    end
    
    properties(Constant)
        % Amount of time to keep in buffer
        BUFFER_SECONDS = 60;
    end
    
    events
        % Fired when giveJuice() is called with a PMEventDataJuice object
        juice
    end
    
    methods
        function self = PMDAQ(PM, config)
            self.config = PM.parseOptions(config, struct(...
                    'daqAdaptor', 'required', ...
                    'daqID', 'required', ...
                    'daqInputType', 'SingleEnded', ...
                    'analogChannels', struct(), ...
                    'juiceChannel', [], ...
                    'eventChannels', [], ...
                    'strobeChannel', [], ...
                    'analogSampleRate', 1000 ...
                ));
            
            % Initialize channels
            self.channels = struct();
            channelNames = fieldnames(self.config.analogChannels);
            for i=1:length(channelNames)
                currentChannelName = channelNames{i};
                currentChannels = self.config.analogChannels.(currentChannelName);
                self.channels.(currentChannelName) = length(self.channelIDs)+(1:length(currentChannels));
                self.channelIDs = [self.channelIDs currentChannels];
            end
            
            % Register with PsychoMonkey
            self.PM = PM;
            PM.DAQ = self;
        end
        
        function init(self)
            daqreset;
            
            % Initialize analog IO
            if ~isempty(self.channelIDs)
                self.ai = analoginput(self.config.daqAdaptor, self.config.daqID);
                addchannel(self.ai, self.channelIDs);
                
                assert(setverify(self.ai, 'SampleRate', ...
                    self.config.analogSampleRate) == self.config.analogSampleRate, ...
                    'Specified sample rate not supported');
                set(self.ai, 'SamplesPerTrigger', Inf);
                if ~isempty(self.config.daqInputType)
                    assert(strcmp(setverify(self.ai, 'InputType', ...
                        self.config.daqInputType), self.config.daqInputType), ...
                        'Specified input type not supported');
                end

                start(self.ai);
                
                self.buffer = zeros(self.config.analogSampleRate*self.BUFFER_SECONDS, length(self.channelIDs));
                self.bufferLength = zeros(1, length(self.channelIDs));
            end
            
            % Initialize digital IO
            if ~isempty(self.config.juiceChannel) || ~isempty(self.config.eventChannels) ...
                    || ~isempty(self.config.strobeChannel)
                self.dio = digitalio(self.config.daqAdaptor, self.config.daqID);
            end
            if ~isempty(self.config.juiceChannel)
                addline(self.dio, self.config.juiceChannel, 'out');
            end

            % Initialize events
            if ~isempty(self.config.eventChannels)
                event_lines = addline(self.dio, self.config.eventChannels, 'out');
                udd = daqgetfield(event_lines, 'uddobject');
                self.eventUDDParent = get(udd(1), 'Parent');
                eventIndex = get(udd, 'Index');
                self.eventIndex = [eventIndex{:}];
            end

            % Initialize strobe
            if ~isempty(self.config.strobeChannel)
                strobe_line = addline(self.dio, self.config.strobeChannel, 'out');
                udd = daqgetfield(strobe_line, 'uddobject');
                self.strobeUDDParent = get(udd, 'Parent');
                self.strobeIndex = get(udd, 'Index');
            end
        end
        
        function delete(self)
            self.haltJuice();
            daqreset;
        end

        function sendEvent(self, code)
        % SENDEVENT Send an event
        %   SENDEVENT(CODE) sends event code CODE
            putvalue(self.eventUDDParent, code, self.eventIndex);
            if ~isempty(self.strobeIndex)
                putvalue(self.strobeUDDParent, 1, self.strobeIndex);
            end
            putvalue(self.eventUDDParent, 0, self.eventIndex);
            if ~isempty(self.strobeIndex)
                putvalue(self.strobeUDDParent, 0, self.strobeIndex);
            end
        end
        
        function giveJuice(self, time, between, reps)
        % GIVEJUICE Administer a specified amount of juice
        %   GIVEJUICE(TIME) administers juice for TIME seconds
        %
        %   GIVEJUICE(TIME, BETWEEN, REPS) adminsters juice REPS times,
        %   with BETWEEN seconds between each administration
            if ~exist('between', 'var')
                between = 0;
            end
            if ~exist('reps', 'var')
                reps = 1;
            end
            
			notify(self, 'juice', PMEventDataJuice(time, between, reps));
            PM = self.PM; %#ok<*PROP>
            for i=1:reps
                putvalue(self.dio.Line(1), 1);
                PM.select(PM.fTimer(GetSecs()+time));
                putvalue(self.dio.Line(1), 0);
                PM.select(PM.fTimer(GetSecs()+between));
            end
        end
        
        function giveJuiceAsync(self, time, between, reps)
        % GIVEJUICEASYNC Administer a specified amount of juice
        %   GIVEJUICEASYNC(TIME) administers juice for TIME seconds
        %
        %   GIVEJUICEASYNC(TIME, BETWEEN, REPS) adminsters juice
        %   REPS times, with BETWEEN seconds between each
        %   administration
        %
        %   Unlike GIVEJUICE, GIVEJUICEASYNC returns immediately.
            if ~exist('between', 'var')
                between = 0;
            end
            if ~exist('reps', 'var')
                reps = 1;
            elseif reps < 1
                return;
            end
            if ~isempty(self.tick)
                warning('attempted to give juice while juice was already being given');
                return;
            end
            
            notify(self, 'juice', PMEventDataJuice(time, between, reps));
            PM = self.PM; %#ok<*PROP>

            i = 1;
            givingJuice = false;
            timer = PM.fTimer(GetSecs());
            ch = self.dio.Line(1);
            function onTick()
                if timer()
                    if givingJuice
                        putvalue(ch, 0);
                        t = GetSecs();
                        givingJuice = false;
                        i = i + 1;
                        if i > reps
                            self.tick = [];
                        else
                            timer = PM.fTimer(t+between);
                        end
                    else
                        putvalue(ch, 1);
                        timer = PM.fTimer(GetSecs()+time);
                        givingJuice = true;
                    end
                end
            end
            self.tick = @onTick;
        end

        function haltJuice(self)
        % HALTJUICE Stop giving juice given with giveJuiceAsync
            if ~isempty(self.tick)
                putvalue(self.dio.Line(1), 0);
                self.tick = [];
            end
        end
        
        function data = getData(self, channelname)
        % GETDATA Gets all data acquired by the DAQ since last call
        %   DATA = OBJ.GETDATA(CHANNELNAME) gets eye position data from the
        %   DAQ. DATA is a m x n matrix, where m is the number of samples 
        %   acquired since last GETDATA(CHANNELNAME) call and n is the
        %   number of channels corresponding to CHANNELNAME.
            if isfield(self.channels, channelname)
                channel = self.channels.(channelname);
                if isempty(channel)
                    error(['Attempted to get ' channelname ' data, but no ' ...
                        'channel with this name has been defined']);
                end
            else
                error(['Invalid channel ' channelname]);
            end
            
            % Get available samples
            nSamples = get(self.ai, 'SamplesAvailable');
            if nSamples == 0
                % Short circuit for speed
                data = self.buffer(1:self.bufferLength(channel(1)), channel);
                self.bufferLength(channel) = 0;
                return;
            end
            
            % Get samples from DAQ
            data = getdata(self.ai, nSamples);
            
            % Buffer data for other channels
            otherChannels = 1:length(self.channelIDs);
            otherChannels(channel) = [];
            maxBufferLength = size(self.buffer, 1);
            for i=otherChannels
                bufLength = self.bufferLength(i);
                if size(data, 1) > maxBufferLength
                    % If we have read more data than the buffer, clear it
                    self.buffer(:, i) = data(end-maxBufferLength+1:end, i);
                    self.bufferLength(i) = maxBufferLength;
                elseif (bufLength + nSamples) > maxBufferLength
                    % If the buffer is filled, rotate it
                    self.buffer(:, i) = [self.buffer(nSamples+1:end, i); data(:, i)];
                    self.bufferLength(i) = maxBufferLength;
                else
                    % If the buffer is not full, just add on at the end
                    self.buffer(bufLength+(1:nSamples), i) = data(:, i);
                    self.bufferLength(i) = bufLength + nSamples;
                end
            end
            
            % Return data for selected channels
            data = [self.buffer(1:self.bufferLength(channel(1)), channel); data(:, channel)];
            self.bufferLength(channel) = 0;
        end
        
        function f = fAboveThreshold(self, channelName, threshold)
        %FABOVETHRESHOLD Create channel monitor function
        %   FABOVETHRESHOLD(CHANNELNAME, THRESHOLD) creates a function
        %   that returns true if the voltage on CHANNELNAME rises above 
        %   THRESHOLD
            f = @() any(self.getData(channelName) > threshold);
        end
        
        function f = fBelowThreshold(self, channelName, threshold)
        %FBELOWTHRESHOLD Create channel monitor function
        %   FBELOWTHRESHOLD(CHANNELNAME, THRESHOLD) creates a function
        %   that returns true if the voltage on CHANNELNAME falls below 
        %   THRESHOLD
            f = @() any(self.getData(channelName) < threshold);
        end
    
        function f = fDerivativeExceedsThreshold(self, channelName, threshold)
        %FDERIVATIVEEXCEEDSTHRESHOLD Create channel monitor function
        %   FDERIVATIVEEXCEEDSTHRESHOLD(CHANNELNAME, THRESHOLD) returns a
        %   function that returns true when the difference between samples
        %   on CHANNELNAME exceeds THRESHOLD

            % Clear motion data before we start
            lastData = self.getData(channelName);
            if ~isempty(lastData)
                lastData = lastData(end);
            end

            function isFinished = innerFunction()
                data = self.getData(channelName);
                if isempty(data)
                    isFinished = false;
                    return;
                end
                isFinished = any(abs(diff([lastData; data])) > threshold);
                lastData = data(end);
            end
            f = @innerFunction;
        end
    end
end
