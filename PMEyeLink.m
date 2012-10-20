classdef PMEyeLink < PMEyeBase
% PMEYELINK  EyeLink module
%   PMEYELINK(PM, CONFIG) sets up an EyeLink eye tracker. This class requires
%   that the EyeLink toolbox.
    properties(Access = private)
        % A buffer of the last 60 seconds of raw eye positions. X and Y are
        % the first and second columns; each row is a sample.
        eyeDataBuffer = zeros(2, 60000);
        eyeDataBufferLength = 0;
        
        % EyeLink
        el = false;
    end
    
    methods
        function self = PMEyeLink(PM, config)
            self.PM = PM;
            self.config = PM.parseOptions(config, struct(...
                    'juiceTime', 150e-3, ...
                    'calibrationPoints', [0 0; -1 0; 1 0; 0 -1; 0 1]*5, ...
                    'eye', 'r', ...
                    'edfName', [num2str(floor(rand()*100000)) '.edf'], ...
                    'drawOnTracker', false ...
                ));
            
            % Register with PsychoMonkey
            PM.EyeTracker = self;
        end
        
        function init(self)
        % INIT Initialize eye tracker 
        %   TRACKER.INIT() is called after PsychoMonkey is initialized to
        %   complete setup.
            PM = self.PM;
            
            if isstruct(self.el)
                return;
            end
            
            self.el = EyelinkInitDefaults(PM.mainDisplayPtr);
            if ~EyelinkInit()
                error('Could not initialize EyeLink');
            end
            
            Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', ...
                0, 0, PM.displaySize(1)-1, PM.displaySize(2)-1);
            Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, ...
                0, PM.displaySize(1)-1, PM.displaySize(2)-1);
            Eyelink('Openfile', self.config.edfName);
            
            function onStateChanged(~, ~)
            % ONSTATECHANGED Sends a message to EyeLink on state change.
                Eyelink('Message', '%s', PM.state);
            end
            function onTargetsChanged(~, ~)
            % ONTARGETSCHANGED Updates targets on EyeLink.
            %   This function is registered as a listener for the
            %   targetsChanged event on PMOSD.
                if isempty(PM.targetRects)
                    Eyelink('command','clear_screen 0');
                else
                    rect = PM.targetRects(end, :);
                    Eyelink('command','draw_box %d %d %d %d 15', ...
                        rect(1), rect(2), rect(3), rect(4));
                end
            end
            addlistener(PM, 'stateChanged', @onStateChanged);
            if self.config.drawOnTracker
                addlistener(PM, 'targetsChanged', @onTargetsChanged);
            end
        end
        
        function delete(~)
            Eyelink('Shutdown');
        end
        
        function eyePosition = getEyePosition(self, retrieveSamples)
        % GETEYEPOSITION Gets eye position and updates OSD
        %   EYEPOSITION = EYETRACKER.GETEYEPOSITION() gets the current eye 
        %   position in pixels
        %   EYEPOSITION = EYETRACKER.GETEYEPOSITION(RETRIEVESAMPLES) gets
        %   RETRIEVESAMPLES samples from the eye tracker, or all available
        %   samples if RETRIEVESAMPLES is larger than the buffer
            if ~exist('retrieveSamples', 'var')
                retrieveSamples = 1;
            end
            
            samples = Eyelink('GetQueuedData');
            
            if isempty(samples) && retrieveSamples == 1
                % In case we haven't acquired a new sample since the last
                % time we checked the eye position
                eyePosition = self.eyeDataBuffer(:, end)';
                return;
            end
            
            if any(self.config.eye == 'l')
                rows = [14 16];
            else
                rows = [15 17];
            end
            
            % Rotate buffer
            nSamples = size(samples, 2);
            if nSamples
                bufLength = self.eyeDataBufferLength;
                maxBufferLength = size(self.eyeDataBuffer, 2);
                if size(samples, 2) >= maxBufferLength
                    % If we have read more data than the buffer, clear it
                    self.eyeDataBuffer = samples(rows, end-maxBufferLength+1:end);
                    self.eyeDataBufferLength = maxBufferLength;
                else
                    % If the buffer is filled, rotate it
                    self.eyeDataBuffer = [self.eyeDataBuffer(:, nSamples+1:end) samples(rows, :)];
                    self.eyeDataBufferLength = min(maxBufferLength, bufLength + nSamples);
                end
            end

            eyePosition = self.eyeDataBuffer(:, end-min(retrieveSamples, self.eyeDataBufferLength)+1:end)';
        end
        
        function calibrate(self)
        % CALIBRATE Calibrate the eye tracker
        %   SUCCESS = OBJ.CALIBRATE() shows the dot pattern to calibrate
        %   the eye tracker. If SUCCESS is false, the user cancelled
        %   calibration.
            PM = self.PM;
            
            KEYS = struct(...
                'SPACE', 'Use eye position',...
                'A', 'Animate point',...
                'B', 'Blink point',...
                'J', 'Give juice',...
                'RETURN', 'Accept calibration',...
                'ESCAPE', 'Cancel calibration'...
            );
            
            oldState = PM.state;
            PM.setState('EyeLink Calibration');
            PM.clearTargets();
            pointRadius = round(PM.angleToPixels(self.FIXATION_POINT_RADIUS));
            
            Eyelink('StartSetup');
            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
            Eyelink('SendKeyButton', double('c'), 0, self.el.KB_PRESS);
            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
            
            showPoint = 0;
            tx = 0;
            ty = 0;
            function isFinished = fTargetChanged()
                [newShowPoint, newTx, newTy] = Eyelink('TargetCheck');
                isFinished = newShowPoint ~= showPoint ...
                    || newTx ~= tx || newTy ~= ty;
                if isFinished
                    showPoint = newShowPoint;
                    tx = newTx;
                    ty = newTy;
                end
            end
            function isFinished = fModeChanged()
                isFinished = ~bitand(Eyelink('CurrentMode'), self.el.IN_TARGET_MODE);
            end
            
            % Perform calibration
            while true
                [whatHappened, key] = PM.select(@fModeChanged, @fTargetChanged, ...
                    PM.fKeyPress(KEYS, true));
                
                if whatHappened == 1            % Left calibration mode
                    PM.setState(oldState);
                    return;
                elseif whatHappened == 2        % Point moved
                    if showPoint && tx && ty
                        % Show point
                        pointCenter = [tx ty];
                        PM.screen('FillRect', 0, [0 0 PM.displaySize]);
                        PM.screen('FillOval', 255, ...
                            [pointCenter-pointRadius pointCenter+pointRadius]);
                    else
                        PM.screen('FillRect', 0, [0 0 PM.displaySize]);
                    end
                    PM.screen('Flip');
                elseif whatHappened == 3        % Key pressed
                    switch key
                        case 'SPACE'
                            Eyelink('AcceptTrigger');
                        case 'J'
                            PM.DAQ.giveJuice(self.config.juiceTime);
                        case 'RETURN'
                            Eyelink('SendKeyButton', self.el.ENTER_KEY, 0, ...
                                self.el.KB_PRESS);
                            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
                            Eyelink('StartRecording');
                            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
                        case 'ESCAPE'
                            Eyelink('SendKeyButton', self.el.ESC_KEY, 0, ...
                                self.el.KB_PRESS);
                            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
                            Eyelink('StartRecording');
                            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
                        case {'A', 'B'}
                            if tx && ty
                                pointCenter = [tx ty];
                                if key == 'A'
                                    animateFn = self.fAnimatePoint(pointCenter);
                                elseif key == 'B'
                                    animateFn = self.fBlinkPoint(pointCenter);
                                end
                                PM.select(PM.fKeyPress(KEYS, true), animateFn);
                                PM.screen('FillOval', 255, ...
                                    [pointCenter-pointRadius pointCenter+pointRadius]);
                                PM.screen('Flip');
                            end
                    end
                end
            end
        end
        
        function correctDrift(self, correctX, correctY, numberOfSamples)
        % CORRECTDRIFT Corrects drift using known pupil position.
        %   OBJ.CORRECTDRIFT(CORRECTX, CORRECTY) assumes that the subject
        %   is fixating on an object at pixel coordinates
        %   (CORRECTX, CORRECTY) and corrects the eye signal to compensate
        %   using the median of the previous 50 samples of eye data.
        %   OBJ.CORRECTDRIFT(CORRECTX, CORRECTY, NUMBEROFSAMPLES) specifies
        %   the median of the previous NUMBEROFSAMPLES samples should be
        %   used to compute the offset.
            if ~exist('numberOfSamples', 'var')
                numberOfSamples = 50;
            end
            samples = self.getEyePosition(numberOfSamples);
            offset = round([correctX correctY] - median(samples));
            Eyelink('command', 'drift_correction %ld %ld %ld %ld', ...
                offset(1), offset(2), correctX, correctY);
        end
    end
end
