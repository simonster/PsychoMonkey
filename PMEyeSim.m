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

classdef PMEyeSim < PMEyeBase
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
            
            keys = struct();
            for i=1:size(positions, 1)
                keys.(KbName(10+i)) = sprintf('(%d,%d)', positions(i, 1), positions(i, 2));
            end
            
            self.evKeyboardFixate = PM.fKeyPress(keys);
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
                eyePosition = self.positions(key-48, :);
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
