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
        redrawUnderlay = false;
        mainDisplayPtr;
        offscreenOSDPtr = [];
    end
    
    properties(SetAccess = private, GetAccess = private)
        auxDisplayPtr;
        offscreenDupPtr = [];
        auxWaitingForAsyncFlip = false;
        haveDrawnSinceLastFlip = false;
    end
    
    events
        screenCommand
    end
    
    methods
        function self = PMScreenManager()
            global CONFIG PM;
            
            % Open main screen
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
            [self.mainDisplayPtr, displayRect] = PsychImaging('OpenWindow', CONFIG.mainDisplay, ...
                CONFIG.backgroundColor);
            CONFIG.displaySize = displayRect(3:4)-displayRect(1:2);
            CONFIG.displayCenter = displayRect(1:2)+CONFIG.displaySize/2;
            
            % Open aux screen if requested
            if isempty(CONFIG.auxDisplay)
                return
            end
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
            [self.auxDisplayPtr, auxDisplayRect] = PsychImaging('OpenWindow', CONFIG.auxDisplay, ...
                CONFIG.backgroundColor);
            assert(all(CONFIG.displaySize == auxDisplayRect(3:4)), ...
                'Main and auxiliary displays must be the same size')
            
            self.offscreenDupPtr = Screen('OpenOffscreenWindow', self.auxDisplayPtr, ...
                CONFIG.backgroundColor, ...
                [0 0 CONFIG.displaySize(1) CONFIG.displaySize(2)-CONFIG.OSDHeight]);
            
            % Add aux display update to event loop
            PM.eventLoop{end+1} = @self.updateAuxDisplay;
        end

        function varargout = Screen(self, func, varargin)
            % SCREEN Emulates PTB Screen() call
            % OBJ.SCREEN() behaves identically to the PTB screen call, but
            % contains allowances for asynchronous flips in progress on the
            % auxiliary display, and duplicates draw commands to an
            % offscreen window.
            global CONFIG;

            if strcmp(func, 'Flip')
                Screen('CopyWindow', self.mainDisplayPtr, self.offscreenDupPtr, ...
                    [0 CONFIG.OSDHeight CONFIG.displaySize]);
                self.redrawUnderlay = true;
            end
            
            if strcmpi(func, 'CloseAll')
                Screen(func);
            elseif strcmpi(func, 'MakeTexture')
                [varargout{1:nargout}] = Screen(func, self.mainDisplayPtr, varargin{:});
                notify(self, 'screenCommand', ...
                    PMEventDataScreenCommand(func, varargin, varargout{1}));
            else
                notify(self, 'screenCommand', ...
                    PMEventDataScreenCommand(func, varargin));
                [varargout{1:nargout}] = Screen(func, self.mainDisplayPtr, varargin{:});
            end
        end
        
        function updateAuxDisplay(self)
            % UPDATEAUXDISPLAY Updates auxiliary display if necessary
            global CONFIG PM;
            
            % If no aux display, or if already performing an async flip
            % on the aux display, don't try to do anything
            if self.auxIsFlipping()
                return;
            end
            
            underlayRedrawn = self.redrawUnderlay;
            if underlayRedrawn
                % The "right" way to do this is with CopyWindow, but that seems to expose
                % a PTB bug, so we use DrawTexture instead...
                %Screen('CopyWindow', self.offscreenDupPtr, ...
                %    self.auxDisplayPtr, [], ...
                %    [0 CONFIG.OSDHeight CONFIG.displaySize]);
                Screen('DrawTexture', self.auxDisplayPtr, ...
                    self.offscreenDupPtr, [], ...
                    [0 CONFIG.OSDHeight CONFIG.displaySize]);
                self.redrawUnderlay = false;
            end
            
            PM.osd.draw(self.auxDisplayPtr, underlayRedrawn);
            
            % Flip display
            Screen('AsyncFlipBegin', self.auxDisplayPtr, 0, 1);
            self.auxWaitingForAsyncFlip = true;
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
    end
end