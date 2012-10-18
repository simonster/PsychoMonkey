classdef PMEyeSim < PMEyeBase
% PMEyeSim Simulated eye tracker
%   PMEyeSim(LOCATIONS) Creates a new EyeTracker object that simulates an eye
%   tracker. LOCATIONS should be an n x 2 matrix of fixation locations in
%   degrees from the center of the screen. These fixation locations will be
%   mapped to function keys on the keyboard,such that F1 = fixation at
%   location 1, F2 = fixation at location 2, etc.
    properties(Access = private)
        lastPosition = [10 10];
        positions;
        evKeyboardFixate;
    end
    
    methods
        function self = PMEyeSim(PM, positions)
            self.PM = PM;
            self.config = struct('positions', positions);
            if size(self.config.positions, 1) > 12
                error('PMEyeSim supports at most 12 fixation locations');
            end
            
            keys = struct();
            for i=1:size(positions, 1)
                keys.(KbName(111+i)) = sprintf('(%d,%d)', positions(i, 1), positions(i, 2));
            end
            
            self.evKeyboardFixate = PM.fKeyPress(keys);
            
            % Register with PsychoMonkey
            PM.EyeTracker = self;
        end
        
        function init(~)
        % INIT Initialize eye tracker 
        %   TRACKER.INIT() is called after PsychoMonkey initialization
        end
        
        function eyePosition = getEyePosition(self)
        % GETEYEPOSITION Gets eye position and updates OSD
        %   EYEPOSITION = TRACKER.GETEYEPOSITION() gets the current eye 
        %   position in degrees and updates the auxiliary display
            key = self.evKeyboardFixate();
            if key
                eyePosition = self.PM.displayCenter ...
                    + self.PM.angleToPixels(self.config.positions(str2double(key(2:end)), :));
                self.lastPosition = eyePosition;
            else
                eyePosition = self.lastPosition;
            end
        end
        
        function calibrate(~)
        % CALIBRATE Calibrate the eye tracker
        %   SUCCESS = TRACKER.CALIBRATE() shows the dot pattern to calibrate
        %   the eye tracker. If SUCCESS is false, the user cancelled
        %   calibration.
        end
        
        function correctDrift(~, ~, ~, ~)
        % CORRECTDRIFT Corrects drift using known pupil position.
        %   TRACKER.CORRECTDRIFT(CORRECTX, CORRECTY) assumes that the subject
        %   is fixating on an object at pixel coordinates
        %   (CORRECTX, CORRECTY) and corrects the eye signal to compensate
        %   using the median of the previous 50 samples of eye data.
        %   TRACKER.CORRECTDRIFT(CORRECTX, CORRECTY, NUMBEROFSAMPLES) specifies
        %   the median of the previous NUMBEROFSAMPLES samples should be
        %   used to compute the offset.
        end
    end
end
