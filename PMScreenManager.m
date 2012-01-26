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

classdef PMScreenManager < handle
	% PMScreenManager Screen management
    properties
        underlayNeedsRedraw = false;
        osdNeedsRedraw = false;
        targetsNeedRedraw = false;
        offscreenOSDPtr = [];
    end
    
    properties(SetAccess = private, GetAccess = private)
        auxDisplayPtr;
        offscreenDupPtr = [];
        auxWaitingForAsyncFlip = false;
        lastPlottedFixationPoint = [];
        haveDrawnSinceLastFlip = false;
    end
    
    methods
        function self = PMScreenManager()
            global CONFIG;
            
            % Open main screen
            [CONFIG.mainDisplayPtr, displayRect] = Screen('OpenWindow', CONFIG.mainDisplay, ...
                CONFIG.backgroundColor);
            CONFIG.displaySize = displayRect(3:4)-displayRect(1:2);
            CONFIG.displayCenter = displayRect(1:2)+CONFIG.displaySize/2;
            
            % Open aux screen if requested
            if isempty(CONFIG.auxDisplay)
                return
            end
            [self.auxDisplayPtr, auxDisplayRect] = Screen('OpenWindow', CONFIG.auxDisplay, ...
                CONFIG.backgroundColor);
            assert(all(CONFIG.displaySize == auxDisplayRect(3:4)), ...
                'Main and auxiliary displays must be the same size')
            
            self.offscreenDupPtr = Screen('OpenOffscreenWindow', self.auxDisplayPtr, ...
                CONFIG.backgroundColor, [0 CONFIG.OSDHeight CONFIG.displaySize]);
            self.offscreenOSDPtr = Screen('OpenOffscreenWindow', self.auxDisplayPtr, ...
                CONFIG.backgroundColor, [0 0 CONFIG.displaySize(1) CONFIG.OSDHeight], 32);
        end

        function varargout = Screen(self, func, display, varargin)
            % SCREEN Emulates PTB Screen() call
            % OBJ.SCREEN() behaves identically to the PTB screen call, but
            % contains allowances for asynchronous flips in progress on the
            % auxiliary display, and duplicates draw commands to an
            % offscreen window.
            global CONFIG;
            
            if ~exist('display', 'var')
                self.waitForAuxFlip();
                [varargout{1:nargout}] = Screen(func);
            elseif display == CONFIG.mainDisplayPtr
                if isempty(CONFIG.auxDisplay)
                    [varargout{1:nargout}] = Screen(func, display, varargin{:});
                else
                    if (strcmp(func, 'PreloadTextures') ...
                            || strcmp(func, 'DrawTexture') ...
                            || strcmp(func, 'DrawTextures')) ...
                            && self.auxIsFlipping()
                        % "You can not do anything with textures or 
                        % offscreen windows while any onscreen window is in 
                        % async flip state"
                        self.waitForAuxFlip();
                    elseif strcmp(func, 'AsyncFlipBegin')
                        error('Asynchronous flips are not supported');
                    end
                    
                    if strcmp(func, 'Flip')
                        % Copy data to aux display and set async flip
                        
                        % If attempting to copy the main display to a
                        % window when the main display has not been drawn
                        % to since the last flip, PTB will crash
                        if self.haveDrawnSinceLastFlip
                            if self.auxIsFlipping()
                                self.waitForAuxFlip();
                            end
                            Screen('CopyWindow', CONFIG.mainDisplayPtr, ...
                               self.offscreenDupPtr, ...
                               [0 CONFIG.OSDHeight CONFIG.displaySize]);
                        else
                            % Nothing drawn since last flip, so flip screen
                            % with white, since this is what PTB appears to
                            % do regardless of background color. (No, I
                            % don't get it either.)
                            Screen('FillRect', self.offscreenDupPtr, 255, ...
                                [0 CONFIG.OSDHeight CONFIG.displaySize]);
                        end
                        self.underlayNeedsRedraw = true;
                        
                        % Unless told not to clear the back buffer, set 
                        % haveDrawnSinceLastFlip to false
                        if length(varargin) < 2 || ~varargin{2}
                            self.haveDrawnSinceLastFlip = false;
                        end
                    else
                        self.haveDrawnSinceLastFlip = true;
                    end
                    
                    [varargout{1:nargout}] = Screen(func, display, varargin{:});
                end
            else
                disp('PMScreen() called with invalid window');
            end
        end
        
        function updateAuxDisplay(self)
            % UPDATEAUXDISPLAY Updates auxiliary display if necessary
            global CONFIG;
            
            % If no aux display, or if already performing an async flip
            % on the aux display, don't try to do anything
            if isempty(CONFIG.auxDisplay) || self.auxIsFlipping()
                return;
            end
            
            %start = GetSecs();
            % If the main display has changed, then the underlay needs to
            % be redrawn
            if self.underlayNeedsRedraw
                % Plot offscreen window
                Screen('DrawTexture', self.auxDisplayPtr, self.offscreenDupPtr, ...
                  [], [0 CONFIG.OSDHeight CONFIG.displaySize]);
                self.lastPlottedFixationPoint = [];
                self.underlayNeedsRedraw = false;
                self.targetsNeedRedraw = true;
            end
            
            % If the OSD has changed, then it needs to be redrawn
            if self.osdNeedsRedraw
                %Screen('DrawTexture', self.auxDisplayPtr, self.offscreenOSDPtr, ...
                %   [], [0 0 CONFIG.displaySize(1) CONFIG.OSDHeight]);
                CONFIG.osd.draw(self.auxDisplayPtr);
                self.osdNeedsRedraw = false;
            end
            
            % If targets need to be redrawn
            if self.targetsNeedRedraw || self.underlayNeedsRedraw
                for i=1:size(CONFIG.eyeTracker.targetRects, 1)
                    if CONFIG.eyeTracker.targetIsOval(i)
                        targetType = 'FrameOval';
                    else
                        targetType = 'FrameRect';
                    end
                    Screen(targetType, self.auxDisplayPtr, [255 255 0 1], ...
                       CONFIG.eyeTracker.targetRects(i, :));
                end
                self.targetsNeedRedraw = false;
            end
            
            % Show fixation location if specified
            location = round(PMAngleToPixels(CONFIG.eyeTracker.getEyePosition()));
            pointLocation = CONFIG.displayCenter+location;

            % Don't try to plot fixation off the screen
            pointLocation = [min(pointLocation(1), CONFIG.displaySize(1)) ...
                min(max(pointLocation(2), CONFIG.OSDHeight), CONFIG.displaySize(2))];

            % Plot fixation
            if ~isempty(self.lastPlottedFixationPoint)
                dots = [self.lastPlottedFixationPoint' pointLocation'];
                colors = [0 255; 0 0; 255 0];
            else
                dots = pointLocation';
                colors = [255; 0; 0];
            end
            self.lastPlottedFixationPoint = pointLocation;
            Screen('DrawDots', self.auxDisplayPtr, dots, 4, colors);
            
            % Flip display
            Screen('AsyncFlipBegin', self.auxDisplayPtr, 0, 1);
            self.auxWaitingForAsyncFlip = true;
            %Screen('Flip', self.auxDisplayPtr);
            
            %fprintf('Updated screen in %.2f ms\n', GetSecs()-start);
        end
    end
    
    methods(Access = private)
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
        
        function timestamp = waitForAuxFlip(self)
            % WAITFORFLIP Wait for an asynchronous flip on aux display
            if self.auxIsFlipping()
                timestamp = Screen('AsyncFlipEnd', self.auxDisplayPtr);
                self.auxWaitingForAsyncFlip = false;
            else
                timestamp = false;
            end
        end
    end
end
