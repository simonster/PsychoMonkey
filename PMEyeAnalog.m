classdef PMEyeAnalog < PMEyeBase
% PMEyeAnalog Analog eye tracker interface
%   PMEyeAnalog() Creates a new EyeTracker object for an analog eye
%   tracker.
    
    properties(Access = private)
        % The last eye position. An optimization for speed.
        lastEyePosition = [0 0];
        
        % Linear drift correction angle
        linearDrift = [0 0];
        
        % A buffer of the last 60 seconds of raw eye positions. X and Y are
        % the first and second columns; each row is a sample.
        rawEyeDataBuffer = [];
        rawEyeDataBufferLength = 0;
        
        % The transform used to convert eye position into degrees.
        transform;
        
        % The amount of time to use when acquiring the eye position during
        % calibration, in seconds. The median X and Y positions during this
        % amount of time will serve as the estimates.
        smoothTime = 200e-3;
    end
    
    methods
        function self = PMEyeAnalog(PM, config)
            self.PM = PM;
            if isempty(PM.DAQ)
                error('PMDAQ must be initialized before PMEyeAnalog');
            end
            
            self.config = PM.parseOptions(config, struct(...
                    'juiceTime', 150e-3, ...
                    'calibrationPoints', [0 0; -1 0; 1 0; 0 -1; 0 1]*5, ...
                    'transformType', 'projective', ...
                    'transform', [] ...
                ));
            
            % Initialize raw eye data buffer
            self.rawEyeDataBuffer = zeros(PM.DAQ.config.analogSampleRate*60, 2);
            
            if(~isempty(config.transform))
                % Try to load old transform if there is one
                self.transform = config.transform;
            else
                % Set up a boring default transform that will at least work
                mat = [0 0; -1 0; 1 0; 0 -1; 0 1];
                self.transform = cp2tform(mat, mat*20, self.config.transformType);
            end
        end
        
        function [eyePosition, rawEyePosition] = getEyePosition(self, retrieveSamples)
        % GETEYEPOSITION Gets eye position and updates OSD
        %   EYEPOSITION = OBJ.GETEYEPOSITION() gets the current eye 
        %   position in pixels and updates the auxiliary display
            PM = self.PM;
            
            if ~exist('retrieveSamples', 'var')
                retrieveSamples = 1;
            end
            
            % Get last sample of eye data from the DAQ
            rawEyeData = PM.DAQ.getData('eye');
            
            if isempty(rawEyeData) && retrieveSamples == 1
                % In case we haven't acquired a new sample since the last
                % time we checked the eye position
                rawEyePosition = self.rawEyeDataBuffer(end, :);
                eyePosition = self.lastEyePosition;
                return;
            end
            
            % Rotate buffer
            nSamples = size(rawEyeData, 1);
            bufLength = self.rawEyeDataBufferLength;
            maxBufferLength = size(self.rawEyeDataBuffer, 1);
            if size(rawEyeData, 1) > maxBufferLength
                % If we have read more data than the buffer, clear it
                self.rawEyeDataBuffer = rawEyeData(end-maxBufferLength+1:end, :);
                self.rawEyeDataBufferLength = maxBufferLength;
            else
                % If the buffer is filled, rotate it
                self.rawEyeDataBuffer = [self.rawEyeDataBuffer(nSamples+1:end, :); rawEyeData];
                self.rawEyeDataBufferLength = min(maxBufferLength, bufLength + nSamples);
            end
            
            % Scale the eye data
            rawEyePosition = self.rawEyeDataBuffer(end-min(retrieveSamples, self.rawEyeDataBufferLength)+1:end, :);
            rawEyePosition(:, 1) = rawEyePosition(:, 1) + self.linearDrift(1);
            rawEyePosition(:, 2) = rawEyePosition(:, 2) + self.linearDrift(2);
            eyePosition = PM.angleToPixels(tformfwd(self.transform, rawEyePosition(:, 1), rawEyePosition(:, 2)));
            self.lastEyePosition = eyePosition(end, :);
        end
        
        function init(~)
        % INIT Initialize eye tracker 
        %   TRACKER.INIT() is called after PsychoMonkey is initialized to
        %   complete setup.
        end
        
        function calibrate(self)
        % CALIBRATE Calibrate the eye tracker
        %   SUCCESS = OBJ.CALIBRATE() shows the dot pattern to calibrate
        %   the eye tracker. If SUCCESS is false, the user cancelled
        %   calibration.
            PM = self.PM;
            
            KEYS = struct(...
                'SPACE', 'Use eye position',...
                'LEFTARROW', 'Previous point',...
                'RIGHTARROW', 'Next point',...
                'A', 'Animate point',...
                'B', 'Blink point',...
                'J', 'Give juice',...
                'ENTER', 'Accept calibration',...
                'ESCAPE', 'Cancel calibration'...
            );
            
            pointRadius = round(PM.angleToPixels(self.FIXATION_POINT_RADIUS));
            pointLocations = round(PM.angleToPixels(self.config.calibrationPoints));
            pointValues = self.config.calibrationPoints*NaN;
            targetPos = pointValues;
            targetStd = pointValues;
            
            % Perform calibration
            i = 1;
            while true
                % Show point
                pointCenter = PM.displayCenter+pointLocations(i, :);
                PM.screen('FillOval', 255, ...
                    [pointCenter-pointRadius pointCenter+pointRadius]);
                PM.screen('Flip');
                
                % Wait for a key press
                key = 0;
                while ~any(strcmp(key, {'SPACE', 'LEFTARROW', 'RIGHTARROW'}))
                    [~, key] = PM.select(PM.fKeyPress(KEYS, true));
                    
                    switch key
                        case 'J'
                            PM.daq.giveJuice(self.config.juiceTime);
                        case 'ESCAPE'
                            return;
                        case {'A', 'B'}
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
                
                if strcmp(key, 'SPACE')
                    % Get smoothTime worth of samples of eye data from the DAQ
                    [eyePosition, rawEyePosition] = self.getEyePosition(PM.DAQ.config.analogSampleRate*self.smoothTime);
                    pointValues(i, :) = median(rawEyePosition);
                    
                    targetPos(i, :) = tformfwd(self.transform, pointValues(i, 1), pointValues(i, 2));
                    targetStd(i, :) = abs(diff(prctile(eyePosition, [95 5])));
                    PM.plotTarget(targetPos(i, :), targetStd(i, :));
                    
                    if sum(~isnan(pointValues)) == size(self.config.calibrationPoints, 1)
                        % Got all points; try to transform
                        try
                            self.transform = cp2tform(pointValues, self.config.calibrationPoints, self.config.transformType);
                            break;
                        catch e
                            disp(e.identifier);
                            PM.osd.state = 'Calibration Failed; Retrying';
                            i = 1;
                        end
                    else
%                         if sum(~isnan(pointValues)) >= 3
%                             % Try to transform with 3 or more points
%                             try
%                                 self.transform = cp2tform(pointValues(1:i, :), POINTS(1:i, :), 'affine');
%                             catch %#ok<CTCH>
%                             end
%                         end
                        i = find(isnan(pointValues), 1);
                    end
                elseif strcmp(key, 'LEFTARROW') && i ~= 1
                    % Go back without saving calibration
                    i = i - 1;
                    
                    PM.clearTargets();
                    for j=find(~isnan(targetPos(i, 1)))
                    	PM.plotTarget(targetPos(j, :), targetStd(j, :));
                    end
                elseif strcmp(key, 'RIGHTARROW') && i ~= size(self.config.calibrationPoints, 1);
                    % Go forward without saving calibration
                    i = i + 1;
                    
                    PM.clearTargets();
                    for j=find(~isnan(targetPos(i, 1)))
                    	PM.plotTarget(targetPos(j, :), targetStd(j, :));
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
            PM = self.PM;
            if ~exist('numberOfSamples', 'var')
                numberOfSamples = 50;
            end
            samples = self.getEyePosition(numberOfSamples);
            offset = round([correctX correctY] - median(samples));
            self.linearDrift = 2*atan(([correctX correctY]*PM.config.displayWidth/PM.displaySize(1))/2*PM.config.displayDistance)-offset;
        end
    end
end
