classdef PMEyeSim < PMEyeISCAN
% PMEyeSim Simulated eye tracker
%   PMEyeSim(LOCATIONS) Creates a new EyeTracker object that simulates an eye
%   tracker. LOCATIONS should be an n x 2 matrix of fixation locations.
%   These fixation locations will be mapped to numbers on the keyboard, 
%   such that 1 = fixation at location 1, 2 = fixation at location 2, etc.
    properties(Access = private)
        lastPosition = [10 10];
        positions;
        evKeyboardFixate;
    end
    
    methods
        function self = PMEyeSim(positions)
            self.positions = positions;
            if size(self.positions, 1) > 9
                error('PMEyeSim supports at most 9 fixation locations');
            end
            self.evKeyboardFixate = PMEvKeyPress(48+(1:size(self.positions, 1)));
        end
        
        function eyePosition = getEyePosition(self)
        % GETEYEPOSITION Gets eye position and updates OSD
        %   EYEPOSITION = OBJ.GETEYEPOSITION() gets the current eye 
        %   position in degrees and updates the auxiliary display
            key = self.evKeyboardFixate();
            if key
                eyePosition = self.positions(key-48, :);
                self.lastPosition = eyePosition;
            else
                eyePosition = self.lastPosition;
            end
        end
        
        function calibrate(self)
        % CALIBRATE Calibrate the eye tracker
        %   SUCCESS = OBJ.CALIBRATE() shows the dot pattern to calibrate
        %   the eye tracker. If SUCCESS is false, the user cancelled
        %   calibration.
        end
    end
end