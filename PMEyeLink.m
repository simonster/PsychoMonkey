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

classdef PMEyeLink < handle
% PMEyeAnalog Analog eye tracker interface
%   PMEyeAnalog() Creates a new EyeTracker object for an analog eye
%   tracker.
    properties
        % Calibration points
        POINTS = [0 0; -1 0; 1 0; 0 -1; 0 1]*5;
        % Type of transform (must be an argument of cp2tform)
        TRANSFORM_TYPE = 'projective';
        EYE = 'r';
    end
    
    properties(Access = private)
        % A buffer of the last 60 seconds of raw eye positions. X and Y are
        % the first and second columns; each row is a sample.
        eyeDataBuffer = zeros(2, 60000);
        eyeDataBufferLength = 0;
        
        % The transform used to convert eye position into degrees.
        transform;
        
        % EyeLink
        el = false;
        edfName = '';
    end
    
    methods
        function self = PMEyeLink(aEdfName)
            if exist('aEdfName', 'var')
                self.edfName = aEdfName;
            else
                self.edfName = [num2str(ceil(rand()*10000)) '.edf'];
            end
        end
        
        function initEyelink(self)
            global CONFIG PM;
            
            if isstruct(self.el)
                return;
            end
            
            self.el = EyelinkInitDefaults(PM.screenManager.mainDisplayPtr);
            if ~EyelinkInit()
                error('Could not initialize EyeLink');
            end
            
            Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', ...
                0, 0, CONFIG.displaySize(1)-1, CONFIG.displaySize(2)-1);
            Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, ...
                0, CONFIG.displaySize(1)-1, CONFIG.displaySize(2)-1);
            Eyelink('Openfile', self.edfName);
        end
        
        function eyePosition = getEyePosition(self, retrieveSamples)
        % GETEYEPOSITION Gets eye position and updates OSD
        %   EYEPOSITION = OBJ.GETEYEPOSITION() gets the current eye 
        %   position in pixels and updates the auxiliary display
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
            
            if any(self.EYE == 'lL')
                rows = [14 16];
            else
                rows = [15 17];
            end
            
            % Rotate buffer
            nSamples = size(samples, 2);
            bufLength = self.eyeDataBufferLength;
            maxBufferLength = size(self.eyeDataBuffer, 2);
            if size(samples, 2) > maxBufferLength
                % If we have read more data than the buffer, clear it
                self.eyeDataBuffer = samples(rows, end-maxBufferLength+1:end);
                self.eyeDataBufferLength = maxBufferLength;
            else
                % If the buffer is filled, rotate it
                self.eyeDataBuffer = [self.eyeDataBuffer(:, nSamples+1:end) samples(rows, :)];
                self.eyeDataBufferLength = min(maxBufferLength, bufLength + nSamples);
            end
            
            eyePosition = self.eyeDataBuffer(:, end-min(retrieveSamples, self.eyeDataBufferLength)+1:end)';
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
            KEY_ACCEPT = 13;    % Enter
            KEY_QUIT = 27;      % Escape
            KEY_JUICE = 74;     % J
            KEYS = [KEY_USE KEY_ANIMATE KEY_BLINK KEY_BACK ...
                KEY_QUIT KEY_JUICE KEY_ACCEPT];
            
            PM.osd.state = 'EyeLink Calibration';
            PM.osd.keyInfo = struct(...
                'SPACE', 'Use eye position',...
                'A', 'Animate point',...
                'B', 'Blink point',...
                'LEFT', 'Previous point',...
                'J', 'Give juice',...
                'ENTER', 'Accept calibration',...
                'ESC', 'Cancel calibration'...
            );
            PM.osd.clearTargets();
            PM.osd.redraw();
            pointRadius = round(PMAngleToPixels(CONFIG.fixationPointRadius));
            
            self.initEyelink();
            Eyelink('StartSetup');
            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
            Eyelink('SendKeyButton', double('c'), 0, self.el.KB_PRESS);
            Eyelink('WaitForModeReady', self.el.waitformodereadytime);
            
            showPoint = 0;
            tx = 0;
            ty = 0;
            function isFinished = evTargetChanged()
                [newShowPoint, newTx, newTy] = Eyelink('TargetCheck');
                isFinished = newShowPoint ~= showPoint ...
                    || newTx ~= tx || newTy ~= ty;
                if isFinished
                    showPoint = newShowPoint;
                    tx = newTx;
                    ty = newTy;
                end
            end
            function isFinished = evModeChanged()
                isFinished = ~bitand(Eyelink('CurrentMode'), self.el.IN_TARGET_MODE);
            end
            
            % Perform calibration
            while true
                [whatHappened, key] = PMSelect(@evModeChanged, @evTargetChanged, ...
                    PMEvKeyPress(KEYS, true));
                
                if whatHappened == 1            % Left calibration mode
                    return;
                elseif whatHappened == 2        % Point moved
                    if showPoint && tx && ty
                        % Show point
                        pointCenter = [tx ty];
                        PMScreen('FillRect', 0, [0 0 CONFIG.displaySize]);
                        PMScreen('FillOval', 255, ...
                            [pointCenter-pointRadius pointCenter+pointRadius]);
                    else
                        PMScreen('FillRect', 0, [0 0 CONFIG.displaySize]);
                    end
                    PMScreen('Flip');
                elseif whatHappened == 3        % Key pressed
                    if key == KEY_QUIT
                        Eyelink('SendKeyButton', self.el.ESC_KEY, 0, ...
                            self.el.KB_PRESS);
                        Eyelink('WaitForModeReady', self.el.waitformodereadytime);
            			Eyelink('StartRecording');
                        Eyelink('WaitForModeReady', self.el.waitformodereadytime);
                    elseif key == KEY_ACCEPT
                        Eyelink('SendKeyButton', self.el.ENTER_KEY, 0, ...
                            self.el.KB_PRESS);
                        Eyelink('WaitForModeReady', self.el.waitformodereadytime);
            			Eyelink('StartRecording');
                        Eyelink('WaitForModeReady', self.el.waitformodereadytime);
                    elseif key == KEY_JUICE
                        PM.daq.giveJuice(CONFIG.juiceManual);
                    elseif (key == KEY_ANIMATE || key == KEY_BLINK) && tx && ty
                        pointCenter = [tx ty];
                        if key == KEY_ANIMATE
                            PMSelect(self.animatePoint(pointCenter));
                        elseif key == KEY_BLINK
                            PMSelect(self.blinkPoint(pointCenter));
                        end
                        
                        PMScreen('FillOval', 255, ...
                            [pointCenter-pointRadius pointCenter+pointRadius]);
                        PMScreen('Flip');
                    elseif key == KEY_USE
                        Eyelink('AcceptTrigger');
                    elseif key == KEY_BACK
                        Eyelink('SendKeyButton', hex2dec('0010'), 0, self.el.KB_PRESS);
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
