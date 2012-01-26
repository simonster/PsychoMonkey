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
        needsRedraw = false;
    end
    
    properties(SetAccess = private, GetAccess = public)
        isFlipping;
    end
    
    properties(Access = private)
        waitingForAsyncFlip = false;
        textSpacing = 10;
    end
    
    methods
        function self = PMOSD()
        end
        
        function draw(self, window)
            % DRAW Draw the OSD info at the top of the aux display
            % OBJ.DRAW() draws the OSD info at the top of the aux display,
            %   without executing a flip. This should only be called from
            %   PMScreenManager; it should never be called explicitly from a
            %   a paradigm.
            global CONFIG;
            
            % Set text size and color
            Screen('TextSize', window, 10);
            Screen('TextColor', window, 255);
            
            % Clear the OSD
            Screen('FillRect', window, 0, ...
                [0 0 CONFIG.displaySize(1) CONFIG.OSDHeight]);
            
            % Display state
            Screen('DrawText', window, self.state, 0, 0);
            
            % Display key info
            if ~isempty(self.keyInfo)
                maxX = 0;
                fields = fieldnames(self.keyInfo);
                for i=1:length(fields)
                    x = Screen('DrawText', window, ...
                        fields{i}, 0, self.textSpacing*(i+1));
                    maxX = max(x, maxX);
                end
                for i=1:length(fields)
                    Screen('DrawText', window, ...
                        [' - ' self.keyInfo.(fields{i})], maxX, ...
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
        end
    end
    
    methods(Static)
        function redraw()
            % REDRAW Flag OSD info for redraw
            %   OBJ.REDRAW() indicates that the OSD info needs to be
            %   redrawn. Call this when you have changed performance or key
            %   info data
            global CONFIG;
            CONFIG.screenManager.osdNeedsRedraw = true;
        end
    end
end
