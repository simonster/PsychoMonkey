% PsychoMonkey
% Copyright (C) 2012 Simon Kornblith
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as
% published by the Free Software Foundation, either version 3 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Affero General Public License for more details.
% 
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

classdef PMEyeAnalog < handle
% PMEyeAnalog Analog eye tracker interface
%   PMEyeAnalog() Creates a new EyeTracker object for an analog eye
%   tracker.
    properties
        % Calibration points
        POINTS = [0 0; -1 0; 1 0; 0 -1; 0 1]*5;
        % Type of transform (must be an argument of cp2tform)
        TRANSFORM_TYPE = 'projective';
    end
    
    properties(Access = private)
        % The last eye position. An optimization for speed.
        lastEyePosition = [0 0];
        
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
        function self = PMEyeAnalog()
            global CONFIG;
            
            % Initialize raw eye data buffer
            self.rawEyeDataBuffer = zeros(CONFIG.analogSampleRate*60, 2);
            
            if(exist('calibration.mat', 'file'))
                % Try to load old transform if there is one
                self.transform = load('calibration.mat');
                self.transform = self.transform.transform;
            else
                % Set up a boring default transform that will at least work
                mat = [0 0; -1 0; 1 0; 0 -1; 0 1];
                self.transform = cp2tform(mat, mat*20, 'projective');
            end
        end
        
        function [eyePosition, rawEyePosition] = getEyePosition(self, retrieveSamples)
        % GETEYEPOSITION Gets eye position and updates OSD
        %   EYEPOSITION = OBJ.GETEYEPOSITION() gets the current eye 
        %   position in pixels and updates the auxiliary display
            global CONFIG PM;
            
            if ~exist('retrieveSamples', 'var')
                retrieveSamples = 1;
            end
            
            % Get last sample of eye data from the DAQ
            rawEyeData = PM.daq.getData('eye');
            
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
            eyePosition = PMAngleToPixels(tformfwd(self.transform, rawEyePosition(:, 1), rawEyePosition(:, 2)));
            self.lastEyePosition = eyePosition(end, :);
        end
        
        function calibrate(self)
        % CALIBRATE Calibrate the eye tracker
        %   SUCCESS = OBJ.CALIBRATE() shows the dot pattern to calibrate
        %   the eye tracker. If SUCCESS is false, the user cancelled
        %   calibration.
            global CONFIG PM;
            
            KEY_USE = 32;       % Space
            KEY_ANIMATE = 65;   % A
            KEY_BLINK = 66;     % B
            KEY_BACK = 37;      % Left
            KEY_FORWARD = 39;   % Right
            KEY_QUIT = 27;      % Escape
            KEY_JUICE = 74;     % J
            KEYS = [KEY_USE KEY_ANIMATE KEY_BLINK KEY_BACK KEY_FORWARD ...
                KEY_QUIT KEY_JUICE];
            
            PM.osd.state = 'ISCAN Calibration';
            PM.osd.keyInfo = struct(...
                'Space', 'Use eye position',...
                'A', 'Animate point',...
                'B', 'Blink point',...
                'LEFT', 'Previous point',...
                'RIGHT', 'Next point',...
                'J', 'Give juice',...
                'ESC', 'Exit calibration'...
            );
            PM.osd.redraw();
            
            pointRadius = round(PMAngleToPixels(CONFIG.fixationPointRadius));
            pointLocations = round(PMAngleToPixels(self.POINTS));
            pointValues = self.POINTS*NaN;
            targetPos = pointValues;
            targetStd = pointValues;
            
            % Perform calibration
            i = 1;
            while true
                % Show point
                pointCenter = CONFIG.displayCenter+pointLocations(i, :);
                PMScreen('FillOval', 255, ...
                    [pointCenter-pointRadius pointCenter+pointRadius]);
                PMScreen('Flip');
                
                % Wait for a key press
                key = 0;
                while key ~= KEY_USE && key ~= KEY_BACK && key ~= KEY_FORWARD
                    [~, key] = PMSelect(PMEvKeyPress(KEYS, true));
                    
                    if key == KEY_QUIT
                        return;
                    elseif key == KEY_JUICE
                        PM.daq.giveJuice(CONFIG.juiceManual);
                    else
                        if key == KEY_ANIMATE
                            [~, key] = PMSelect(...
                                PMEvKeyPress(KEYS, true), ...
                                self.animatePoint(pointCenter) ...
                            );
                        elseif key == KEY_BLINK
                            [~, key] = PMSelect(...
                                PMEvKeyPress(KEYS, true), ...
                                self.blinkPoint(pointCenter) ...
                            );
                        end
                        
                        if key ~= KEY_USE && key ~= KEY_QUIT ...
                                && key ~= KEY_BACK && key ~= KEY_FORWARD
                            PMScreen('FillOval', 255, ...
                                [pointCenter-pointRadius pointCenter+pointRadius]);
                            PMScreen('Flip');
                        end
                    end
                end
                
                if key == KEY_USE
                    % Get smoothTime worth of samples of eye data from the DAQ
                    [eyePosition, rawEyePosition] = self.getEyePosition(CONFIG.analogSampleRate*self.smoothTime);
                    pointValues(i, :) = median(rawEyePosition);
                    
                    targetPos(i, :) = tformfwd(self.transform, pointValues(i, 1), pointValues(i, 2));
                    targetStd(i, :) = abs(diff(prctile(eyePosition, [95 5])));
                    PM.osd.plotTarget(targetPos(i, :), targetStd(i, :));
                    
                    if sum(~isnan(pointValues)) == size(self.POINTS, 1)
                        % Got all points; try to transform
                        try
                            self.transform = cp2tform(pointValues, self.POINTS, self.TRANSFORM_TYPE);
                            transform = self.transform;
                            save('calibration.mat', 'transform');
                            break;
                        catch e
                            disp(e.identifier);
                            PM.osd.state = 'Calibration Failed; Retrying';
                            PM.osd.redraw();
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
                elseif key == KEY_BACK && i ~= 1
                    % Go back without saving calibration
                    i = i - 1;
                    
                    PM.osd.clearTargets();
                    for j=find(~isnan(targetPos(i, 1)))
                    	PM.osd.plotTarget(targetPos(j, :), targetStd(j, :));
                    end
                elseif key == KEY_FORWARD && i ~= size(self.POINTS, 1);
                    % Go forward without saving calibration
                    i = i + 1;
                    
                    PM.osd.clearTargets();
                    for j=find(~isnan(targetPos(i, 1)))
                    	PM.osd.plotTarget(targetPos(j, :), targetStd(j, :));
                    end
                end
            end
        end
    end
    
    methods(Static, Access = protected)
        function fn = animatePoint(pointCenter)
        % ANIMATEPOINT Animates a point at the specified location
        %   OBJ.ANIMATEPOINT() returns a function that steps through an
        %   animation at the specified location, using synchronous flips.
        %   It returns TRUE when the animation is complete.
            global CONFIG;
            radii = round(PMAngleToPixels(CONFIG.fixationPointRadius));
            radii = [repmat(radii:radii/2:radii*5, 1, 4) radii];
            index = 1;
            
            function isFinished = animationFunction()
                % Check if finished
                isFinished = index > length(radii);
                if isFinished
                    return;
                end
                
                % Show oval
                PMScreen('FillOval', 255, ...
                    [pointCenter-radii(index) pointCenter+radii(index)]);
                index = index + 1;
                PMScreen('Flip');
            end
            
            fn = @animationFunction;
        end
        
        function fn = blinkPoint(pointCenter)
        % BLINKPOINT Blinks a point at the specified location
        %   OBJ.BLINKPOINT() returns a function that blinks a point on
        %   and off at the specified location. It returns TRUE when the
        %   animation is complete.
            global CONFIG;
            radius = round(PMAngleToPixels(CONFIG.fixationPointRadius));
            rect = [pointCenter-radius pointCenter+radius];
            showingPoint = false;
            blinksRemaining = 6;
            secsBetween = 50e-3;
            timer = 0;
            
            function isFinished = animationFunction()
                % Check if finished
                isFinished = blinksRemaining == 0;
                if isFinished
                    return;
                end
                
                if GetSecs() > timer
                    if ~showingPoint
                        % Show oval
                        PMScreen('FillOval', 255, rect);
                        blinksRemaining = blinksRemaining - 1;
                    end
                    flipTime = PMScreen('Flip');
                    showingPoint = ~showingPoint;
                    timer = flipTime + secsBetween;
                end
            end
            
            fn = @animationFunction;
        end
    end
end
