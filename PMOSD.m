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

classdef PMOSD < handle
% PMOSD Manage animal performance information on on-screen display
    properties
        state = ' ';
        performance = [];
        keyInfo = [];
    end
    
    properties(GetAccess = public, SetAccess = private)
        targetRects = zeros(0, 4);
        targetIsOval = [];
    end
    
    properties(Access = private)
        redrawInfo = false;
        redrawTargets = false;
        textSpacing = 10;
        lastPlottedFixationPoint = [];
    end
    
    events
        targetsChanged
        statusChanged
    end
    
    methods
        function self = PMOSD()
        end
        
        function set.state(self, value)
            self.state = value;
            self.onStatusChanged()
        end
        
        function set.performance(self, value)
            self.performance = value;
            self.onStatusChanged()
        end
        
        function set.keyInfo(self, value)
            self.keyInfo = value;
            self.onStatusChanged();
        end
        
        function draw(self, window, force)
        % DRAW Draw the info on the aux display
        % OBJ.DRAW() draws the OSD info at the top of the aux display,
        %   without executing a flip. This should only be called from
        %   PMScreenManager; it should never be called explicitly from a
        %   a paradigm.
            global CONFIG;
            
            % If the OSD has changed, then it needs to be redrawn
            if self.redrawInfo
                Screen('TextSize', window, 10);
                Screen('TextColor', window, 255);
                Screen('Preference', 'TextRenderer', 0);

                % Clear the OSD
                Screen('FillRect', window, 0, ...
                    [0 0 CONFIG.displaySize(1) CONFIG.OSDHeight]);
                
                % Display state
                Screen('DrawText', window, self.state, 0, 0);
                
                % Display key info
                if ~isempty(self.keyInfo)
                    fields = fieldnames(self.keyInfo);
                    for i=1:length(fields)
                        field = fields{i};
                        Screen('DrawText', window, ...
                            [field ' - ' self.keyInfo.(field)], 0, ...
                            self.textSpacing*(i+1));
                    end
                end
                
                % Display performance data
                if ~isempty(self.performance)
                    x = 2*round(CONFIG.displaySize(1)/3);
                    indent = round(CONFIG.displaySize(1)/200);
                    Screen('DrawText', window, 'Performance', x, 0);
                    if isstruct(self.performance);
                        fields = fieldnames(self.performance);
                        for i=1:length(fields)
                            name = fields{i};
                            perf = self.performance.(name);

                            if perf(2) == 0
                                pct = 0;
                            else
                                pct = perf(1)./perf(2)*100;
                            end

                            str = sprintf('%s %i/%i (%.0f%%)', name, perf(1), perf(2), pct);
                            Screen('DrawText', window, str, x+indent, self.textSpacing*i);
                        end
                    end
                end
                
                self.redrawInfo = false;
            end
            
            % If targets need to be redrawn
            if self.redrawTargets || force
                for i=1:size(self.targetRects, 1)
                    if self.targetIsOval(i)
                        targetType = 'FrameOval';
                    else
                        targetType = 'FrameRect';
                    end
                    Screen(targetType, window, [255 255 0 1], ...
                       self.targetRects(i, :));
                end
                self.redrawTargets = false;
            end
            
            % Show fixation location if specified
            pointLocation = CONFIG.eyeTracker.getEyePosition();

            % Don't try to plot fixation off the screen
            pointLocation = [min(pointLocation(1), CONFIG.displaySize(1)) ...
                min(max(pointLocation(2), CONFIG.OSDHeight), CONFIG.displaySize(2))];

            % Plot fixation
            if force
                self.lastPlottedFixationPoint = [];
            end
            
            if ~isempty(self.lastPlottedFixationPoint)
                dots = [self.lastPlottedFixationPoint' pointLocation'];
                colors = [0 255; 0 0; 255 0];
            else
                dots = pointLocation';
                colors = [255; 0; 0];
            end
            self.lastPlottedFixationPoint = pointLocation;
            Screen('DrawDots', window, dots, 4, colors);
        end
        
        function plotTarget(self, location, radius)
        % PLOTTARGET Show a target on the eye tracker or auxiliary display
        %   OBJ.PLOTTARGET(LOCATION) draws a rectangular target at
        %   LOCATION, defined in degress relative to the center of the
        %   display
        %   OBJ.PLOTTARGET(LOCATION, RADIUS) draws an oval target of RADIUS
        %   degrees at LOCATION, defined in degress relative to the
        %   center of the display
            global CONFIG;
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
            target(1) = max(min(CONFIG.displaySize(1), target(1)), 0);
            target(2) = max(min(CONFIG.displaySize(2), target(2)), 0);
            target(3) = max(min(CONFIG.displaySize(1), target(3)), 0);
            target(4) = max(min(CONFIG.displaySize(2), target(4)), 0);
            self.targetRects = [self.targetRects; target];
            self.redrawTargets = true;
            
            notify(self, 'targetsChanged');
        end
        
        function clearTargets(self)
        % CLEARTARGET Clear targets on eye tracker or auxiliar display
        %   OBJ.CLEARTARGETS() clears all targets currently visible on the
        %   display
            global PM;
            self.targetRects = zeros(0, 4);
            self.targetIsOval = [];
            PM.screenManager.redrawUnderlay = true;
            
            notify(self, 'targetsChanged');
        end
    end
    
    methods(Access = protected)
        function onStatusChanged(self)
            self.redrawInfo = true;
            notify(self, 'statusChanged');
        end
    end
end
