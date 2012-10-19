classdef PsychoMonkey < handle
    properties
        EyeTracker = [];
        DAQ = [];
    end
    
    properties(SetAccess = private, GetAccess = public)
        config = [];
        
        % For screen functionality
        mainDisplayPtr = [];
        displaySize;
        displayCenter;
        state = 'Uninitialized';
        trialInfo = [];
        keyInfo = [];
        targetRects = zeros(0, 4);
        targetIsOval = [];
    end
    
    properties(Access = private)
        % For screen functionality
        auxDisplayPtr = [];
        offscreenDupPtr = [];
        auxWaitingForAsyncFlip = false;
        redrawUnderlay = false;

        simulatedKeysPressed = [];
    end
    
    properties(Constant)
        TEXT_SIZE = 12;
        TEXT_SPACING = 12;
        OSD_HEIGHT = 140;
    end
    
    events
        tick              % Triggered while running event loop in select()
        
        % For screen functionality
        screenCommand     % Triggered by screen()
        
        % For OSD
        stateChanged      % Triggered by setState()
        trialInfoChanged  % Triggered by setTrialInfo()
        keyInfoChanged    % Triggered by setKeyInfo()
        targetsChanged    % Triggered by plotTarget()/clearTargets()
        
        initialized
    end
    
    methods
        function self = PsychoMonkey(config)
            self.config = self.parseOptions(config, struct(...
                    'mainDisplay', 1,...
                    'auxDisplay', [],...
                    'backgroundColor', 0,...
                    'debug', false,...
                    'displayWidth', 'required', ...
                    'displayDistance', 'required' ...
                ));
            KbName('UnifyKeyNames');
        end
        
        function init(self)
            % INIT  Initialize PsychoMonkey
            KbName('UnifyKeyNames');
            self.initScreens();
            if ~isempty(self.DAQ)
                self.DAQ.init();
            end
            if ~isempty(self.EyeTracker)
                self.EyeTracker.init();
            end
            notify(self, 'initialized');
            
            % There is a stupid PTB bug that requires us to put an oval
            % (not a square) on the screen on some ATI video cards...
            self.setState('Initialized');
            self.screen('FillOval', 0);
            self.screen('Flip');
            notify(self, 'tick');
        end
        
        function delete(self)
            % DELETE  Destructor
            while self.auxIsFlipping()
            end
            Screen('Close', self.auxDisplayPtr);
            Screen('Close', self.offscreenDupPtr);
            Screen('Close', self.mainDisplayPtr);
        end

        function varargout = screen(self, func, varargin)
            % SCREEN  PTB Screen() call equivalent
            % PM.SCREEN() behaves identically to the PTB screen call, but
            % contains allowances for asynchronous flips in progress on the
            % auxiliary display, and duplicates draw commands to an
            % offscreen window.
            if isempty(self.mainDisplayPtr)
                error('Not initialized');
            end

            if strcmp(func, 'Flip') && ~isempty(self.auxDisplayPtr)
                Screen('CopyWindow', self.mainDisplayPtr, self.offscreenDupPtr, ...
                    [0 0 self.displaySize]);
                self.redrawUnderlay = true;
            end
            
            if strcmpi(func, 'MakeTexture')
                [varargout{1:nargout}] = Screen(func, self.mainDisplayPtr, varargin{:});
                notify(self, 'screenCommand', ...
                    PMEventDataScreenCommand(func, varargin, varargout{1}));
            else
                notify(self, 'screenCommand', ...
                    PMEventDataScreenCommand(func, varargin));
                [varargout{1:nargout}] = Screen(func, self.mainDisplayPtr, varargin{:});
            end
        end
        
        function pixels = angleToPixels(self, angle)
        % ANGLETOPIXELS  Convert an angle to pixels
        %   PM.ANGLETOPIXELS(ANGLE) converts degrees of visual angle to
        %   pixels
            pixels = 2*self.config.displayDistance*tand(angle/2)*(self.displaySize(1)/self.config.displayWidth);
        end
        
        function plotTarget(self, location, radius)
        % PLOTTARGET  Show a target on the eye tracker or auxiliary display
        %   PM.PLOTTARGET(LOCATION) draws a rectangular target at
        %   LOCATION, defined in degress relative to the center of the
        %   display
        %   PM.PLOTTARGET(LOCATION, RADIUS) draws an oval target of RADIUS
        %   degrees at LOCATION, defined in degress relative to the
        %   center of the display
            if isempty(self.mainDisplayPtr)
                error('Not initialized');
            end
            if exist('radius', 'var') && ~isempty(radius)
                target = [location-radius location+radius];
                self.targetIsOval = [self.targetIsOval; true];
            else
                if length(location) ~= 4
                    error('PLOTTARGET(LOCATION) requires a rect');
                end
                target = location;
                self.targetIsOval = [self.targetIsOval; false];
            end
            target(1) = max(min(self.displaySize(1), target(1)), 0);
            target(2) = max(min(self.displaySize(2), target(2)), 0);
            target(3) = max(min(self.displaySize(1), target(3)), 0);
            target(4) = max(min(self.displaySize(2), target(4)), 0);
            self.targetRects = [self.targetRects; target];
            self.redrawUnderlay = true;
            
            notify(self, 'targetsChanged');
        end
        
        function clearTargets(self)
        % CLEARTARGET  Clear targets on eye tracker or auxiliar display
        %   PM.CLEARTARGETS() clears all targets currently visible on the
        %   display
            self.targetRects = zeros(0, 4);
            self.targetIsOval = [];
            self.redrawUnderlay = true;
            
            notify(self, 'targetsChanged');
        end
        
        function [index, value] = select(self, varargin)
        %SELECT  Wait for several events
        %   [INDEX, OUTPUT] = PM.SELECT(FN1, FN2, ...) waits until at
        %   least one of the given functions returns a positive value,   
        %   then returns the index of the function in the argument list as 
        %   INDEX and the output of the function as OUTPUT.
            indexes = 1:length(varargin);

            if self.config.debug
                startTime = GetSecs();
                currentTime = startTime;
                maxLag = 0;
                nIter = 0;
                fnTime = zeros(1, length(varargin)+1);
                fnMaxLag = fnTime;
                
                while true
                    nIter = nIter + 1;
                    loopStartTime = currentTime;

                    notify(self, 'tick');

                    tempTime = GetSecs();
                    fnTime(1) = fnTime(1)+tempTime-currentTime;
                    if tempTime-currentTime > fnMaxLag(1)
                        fnMaxLag(1) = tempTime-currentTime;
                    end
                    currentTime = tempTime;

                    for index=indexes
                        f = varargin{index};
                        value = f();
                        
                        if value
                            if currentTime-loopStartTime > maxLag
                                maxLag = currentTime - loopStartTime;
                            end
                            
                            fprintf('Executed PM.select for %.3f s at %.2f Hz; Max Lag %.3f ms\n', ...
                                currentTime-startTime, nIter/(currentTime-startTime), maxLag*1000);
                            
                            for j=1:length(varargin)+1
                                if j == 1
                                    funcname = 'Event Loop';
                                else
                                    funcname = func2str(varargin{j-1});
                                end
                                fprintf('  %s: %.2f Hz; Max Lag %.3f ms\n', ...
                                    funcname, nIter/fnTime(j), fnMaxLag(j)*1000);
                            end
                            fprintf('\n');
                            
                            return;
                        else
                            % We don't actually count time for functions
                            % when they return true, since e.g. fKeyPress
                            % will (intentionally) take longer if it's
                            % waiting for key up
                            tempTime = GetSecs();
                            fnTime(index+1) = fnTime(index+1)+tempTime-currentTime;
                            if tempTime-currentTime > fnMaxLag(index+1)
                                fnMaxLag(index+1) = tempTime-currentTime;
                            end
                            currentTime = tempTime;
                        end
                    end

                    if currentTime-loopStartTime > maxLag
                        maxLag = currentTime - loopStartTime;
                    end
                end
            else
                while true
                    notify(self, 'tick');
                    for index=indexes
                        f = varargin{index};
                        value = f();
                        if value
                            return;
                        end
                    end
                end
            end
        end
        
        function output = cselect(self, varargin)
        %CSELECT  Wait for several events using closures
        %   PM.CSELECT(FN1, CB1, FN2, CB2, ...) waits until at least one 
        %   function FN returns positive value, and then calls the 
        %   associated callback CB, passing the function output as the 
        %   argument and returning the return value of the callback.
            if mod(length(varargin), 2) ~= 0
                error('CSELECT() requires an even number of arguments');
            end
            
            events = cell(1, length(varargin)/2);
            callbacks = events;
            for i=1:2:length(varargin)
                if ~isa(varargin{i}, 'function_handle') || isa(varargin{i+1}, 'function_handle')
                    error('CSELECT() requires function handle arguments');
                end
                
                events{(i-1)/2+1} = varargin{i};
                callbacks{(i+1)/2} = varargin{i+1};
            end
            
            [index, output] = self.select(events{:});
            f = callbacks{index};
            output = f(output);
        end
        
        function f = fKeyPress(self, keys, blockUntilRelease)
        %FKEYPRESS Create keypress function
        %   FKEYPRESS(KEYS) creates a function whose that returns they keycode
        %   or name of the key when one of the keys specified by KEYS has been
        %   pressed. KEYS must be a struct whose fields are key names and
        %   values are descriptions of functionality.
        %   
        %   FKEYPRESS(KEYS, TRUE) acts as above, but the function blocks until
        %   the key is released before returning.
            if ~exist('blockUntilRelease', 'var')
                blockUntilRelease = false;
            end
            
            self.keyInfo = keys;
            notify(self, 'keyInfoChanged');
            keyNames = fieldnames(keys);
            upperKeyNames = upper(keyNames); 
            keyCodes = KbName(keyNames);

            function isFinished = innerFunction()
                isFinished = false;
                [keyDown, ~, keysPressed] = KbCheck();
                if keyDown
                    codesOn = keysPressed(keyCodes);
                    if any(codesOn)
                        isFinished = keyNames{find(codesOn, 1)};
                        if blockUntilRelease
                            while true
                                [~, ~, keysPressed] = KbCheck();
                                if ~any(keysPressed(keyCodes))
                                    return;
                                end
                            end
                        end
                    end
                elseif ~isempty(self.simulatedKeysPressed)
                    tf = ismember(upperKeyNames, self.simulatedKeysPressed);
                    if any(tf)
                        isFinished = keyNames{find(tf, 1)};
                        self.simulatedKeysPressed = [];
                    end
                end
            end

            f = @innerFunction;
        end
        
        function simulateKeyPress(self, keys)
        %SIMULATEKEYPRESS  Simulate a keypress
        %    PM.SIMULATEKEYPRESS(KEYS) makes functions returned by
        %    PM.FKEYPRESS() return true if they are waiting for one of the
        %    keys in KEYS. KEYS is a cell array of key names.
            self.simulatedKeysPressed = keys;
        end
        
        function setState(self, state)
        %SETSTATE  Set current state string
            if ~strcmp(state, self.state)
                self.state = state;
                notify(self, 'stateChanged');
            end
        end
        
        function setTrialInfo(self, info)
        %SETTRIALINFO  Set current trialInfo structure
            self.trialInfo = info;
            notify(self, 'trialInfoChanged');
        end
    end
    
    methods(Static)
        function f = fAnd(varargin)
        %FAND  Compose two or more functions
        %   PM.FAND(F1, F2, ...) creates a function that returns true iff the 
        %   functions passed as arguments both evaluate to true

            function isFinished = innerFunction()
                for i=1:length(varargin)
                    r = varargin{i};
                    if ~r()
                        isFinished = false;
                        return;
                    end
                end
                isFinished = true;
            end

            f = @innerFunction;
        end
        
        function f = fTimer(waitUntil)
        %FTIMER  Create timer event
        %   PM.FTIMER(WAITUNTIL) creates a function that returns true when
        %   GetSecs returns WAITUNTIL or greater
            f = @() GetSecs() > waitUntil;
        end
        
        function options = parseOptions(options, defaults)
        % PARSEOPTIONS  Parse options
        %   OPTIONS PM.PARSEOPTIONS(OPTIONS, DEFAULTS) parses options
        %   passed to functions. OPTIONS and DEFAULTS can be structs, cell
        %   arrays, or empty; the return value is always a struct. An error
        %   is thrown if a field in OPTIONS does not exist in DEFAULTS, or
        %   if a field in DEFAULTS has value 'required' but is not set
        %   in OPTIONS.

            if iscell(options)
                options = struct(options{:});
            elseif isempty(options)
                options = struct();
            elseif ~isstruct(options)
                error('OPTIONS must be empty or a struct or cell array');
            end

            if iscell(defaults)
                defaults = struct(defaults{:});
            elseif ~isstruct(defaults)
                error('DEFAULTS must be a struct or cell array');
            end

            option_fields = fieldnames(options);
            for i=1:length(option_fields)
                field = option_fields{i};
                if ~isfield(defaults, field)
                    error(['Unrecognized field "' field '"']);
                end
            end

            default_fields = fieldnames(defaults);

            for i=1:length(default_fields)
                field = default_fields{i};
                if ~isfield(options, field);
                    val = defaults.(field);
                    if strcmp(val, 'required')
                        error(['Field "' field '" is required']);
                    else
                        options.(field) = defaults.(field);
                    end
                end
            end
        end
    end
    
    methods(Access = private)
        function initScreens(self)
            % INITSCREENS()  Initialize screens
            
            % Open main screen
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
            PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
            [self.mainDisplayPtr, displayRect] = PsychImaging('OpenWindow', self.config.mainDisplay, ...
                self.config.backgroundColor);
            self.displaySize = displayRect(3:4)-displayRect(1:2);
            self.displayCenter = displayRect(1:2)+self.displaySize/2;
            
            % Open aux screen if requested
            if isempty(self.config.auxDisplay)
                return
            end
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
            PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
            [self.auxDisplayPtr, auxDisplayRect] = PsychImaging('OpenWindow', self.config.auxDisplay, ...
                self.config.backgroundColor);
            assert(all(self.displaySize == auxDisplayRect(3:4)), ...
                'Main and auxiliary displays must be the same size')
            
            self.offscreenDupPtr = Screen('OpenOffscreenWindow', self.auxDisplayPtr, ...
                self.config.backgroundColor, ...
                [0 0 self.displaySize(1) self.displaySize(2)]);
            
            Screen('TextSize', self.auxDisplayPtr, self.TEXT_SIZE);
            Screen('TextColor', self.auxDisplayPtr, 255);
            Screen('Preference', 'TextRenderer', 0);
            
            % Draw some text now, because it will speed up future
            % operations
            for j=32:127
                Screen('DrawText', self.auxDisplayPtr, char(j), 0, 0);
            end
            Screen('FillRect', self.auxDisplayPtr, 0);
            
            % Add OSD listeners
            redrawState = false;
            redrawKeyInfo = false;
            redrawTrialInfo = false;
            function onStateChanged(~, ~)
                redrawState = true;
            end
            function onKeyInfoChanged(~, ~)
                redrawKeyInfo = true;
            end
            function onTrialInfoChanged(~, ~)
                redrawTrialInfo = true;
            end
            function onTargetsChanged(~, ~)
                self.redrawUnderlay = true;
            end
            addlistener(self, 'stateChanged', @onStateChanged);
            addlistener(self, 'keyInfoChanged', @onKeyInfoChanged);
            addlistener(self, 'trialInfoChanged', @onTrialInfoChanged);
            addlistener(self, 'targetsChanged', @onTargetsChanged);
            
            % Add aux display update to event loop
            trialInfoOffset = round(self.displaySize(1)*2/3);
            window = self.auxDisplayPtr;
            maxLines = floor(self.OSD_HEIGHT/self.TEXT_SPACING);
            function onTick(~, ~)
                persistent lastPlottedFixationPoint;
                
                % Updates auxiliary display if necessary
                % If no aux display, or if already performing an async flip
                % on the aux display, don't try to do anything
                if self.auxIsFlipping()
                    return;
                end

                if self.config.debug
                    t = GetSecs();
                end
                
                if self.redrawUnderlay
                    % The "right" way to do this is with CopyWindow, but that seems to expose
                    % a PTB bug, so we use DrawTexture instead...
                    %Screen('CopyWindow', self.offscreenDupPtr, ...
                    %    self.auxDisplayPtr, [], ...
                    %    [0 self.OSD_HEIGHT self.displaySize]);
                    Screen('DrawTexture', window, ...
                        self.offscreenDupPtr, [0 self.OSD_HEIGHT self.displaySize], ...
                        [0 self.OSD_HEIGHT self.displaySize]);
                    
                    % Also redraw the targets
                    for i=1:size(self.targetRects, 1)
                        if self.targetIsOval(i)
                            targetType = 'FrameOval';
                        else
                            targetType = 'FrameRect';
                        end
                        Screen(targetType, window, [255 255 0 1], ...
                           self.targetRects(i, :));
                    end
                    
                    self.redrawUnderlay = false;
                    
                    if self.config.debug
                        tnew = GetSecs();
                        fprintf('Redrew underlay in %.3f ms\n', (tnew-t)*1000);
                        t = tnew;
                    end
                end
                
                if redrawState
                    Screen('FillRect', window, 0, ...
                        [0 0 self.displaySize(1)-trialInfoOffset self.TEXT_SPACING]);

                    % Display state
                    Screen('DrawText', window, self.state, 0, 0);

                    redrawState = false;
                    
                    if self.config.debug
                        tnew = GetSecs();
                        fprintf('Printed state in %.3f ms\n', (tnew-t)*1000);
                        t = tnew;
                    end
                end

                if redrawKeyInfo
                    Screen('FillRect', window, 0, ...
                        [0 self.TEXT_SPACING ...
                        self.displaySize(1)-trialInfoOffset ...
                        self.OSD_HEIGHT]);

                    % Display key info
                    if ~isempty(self.keyInfo)
                        fields = fieldnames(self.keyInfo);
                        for i=1:min(maxLines-2, length(fields))
                            field = fields{i};
                            Screen('DrawText', window, ...
                                [field ' - ' self.keyInfo.(field)], 0, ...
                                self.TEXT_SPACING*(i+1));
                        end
                    end

                    redrawKeyInfo = false;
                    
                    if self.config.debug
                        tnew = GetSecs();
                        fprintf('Printed keyInfo in %.3f ms\n', (tnew-t)*1000);
                        t = tnew;
                    end
                end

                if redrawTrialInfo
                    Screen('FillRect', window, 0, ...
                        [trialInfoOffset 0 self.displaySize(1) self.OSD_HEIGHT]);

                    if isstruct(self.trialInfo)
                        fields = fieldnames(self.trialInfo);
                        for i=1:min(maxLines, length(fields))
                            name = fields{i};
                            perf = self.trialInfo.(name);

                            if perf(2) == 0
                                pct = 0;
                            else
                                pct = perf(1)./perf(2)*100;
                            end

                            str = sprintf('%s %i/%i (%.0f%%)', name, perf(1), perf(2), pct);
                            Screen('DrawText', window, str, trialInfoOffset, self.TEXT_SPACING*(i-1));
                        end
                    end

                    redrawTrialInfo = false;
                    
                    if self.config.debug
                        tnew = GetSecs();
                        fprintf('Printed trialInfo in %.3f ms\n', (tnew-t)*1000);
                        %t = tnew;
                    end
                end
                
                % Show fixation location if specified
                if ~isempty(self.EyeTracker)
                    pointLocation = self.EyeTracker.getEyePosition();
                end

                % Don't try to plot fixation off the screen
                pointLocation = [min(pointLocation(1), self.displaySize(1)) ...
                    min(max(pointLocation(2), self.OSD_HEIGHT), self.displaySize(2))];

                % Plot fixation
                if ~isempty(lastPlottedFixationPoint)
                    dots = [lastPlottedFixationPoint' pointLocation'];
                    colors = [0 255; 0 0; 255 0];
                else
                    dots = pointLocation';
                    colors = [255; 0; 0];
                end
                lastPlottedFixationPoint = pointLocation;
                Screen('DrawDots', window, dots, 4, colors);
                    
%                 if self.config.debug
%                     tnew = GetSecs();
%                     fprintf('Plotted fixation in %.3f ms\n', (tnew-t)*1000);
%                     t = tnew;
%                 end

                % Flip display
                Screen('AsyncFlipBegin', self.auxDisplayPtr, 0, 1);
                self.auxWaitingForAsyncFlip = true;
                %fprintf('Updated screen in %.2f ms\n', GetSecs()-start);
                    
%                 if self.config.debug
%                     tnew = GetSecs();
%                     fprintf('Flipped display in %.3f ms\n', (tnew-t)*1000);
%                     t = tnew;
%                 end
            end
            addlistener(self, 'tick', @onTick);
        end
        
        function isFlipping = auxIsFlipping(self)
            % AUXISFLIPPING() Determine whether aux display is flipping
            if ~self.auxWaitingForAsyncFlip
                isFlipping = false;
                return;
            end
            
            try
                isFlipping = ~Screen('AsyncFlipCheckEnd', self.auxDisplayPtr);
            catch %#ok<CTCH>
                isFlipping = false;
            end
            if ~isFlipping
                self.auxWaitingForAsyncFlip = false;
            end
        end
    end
end
