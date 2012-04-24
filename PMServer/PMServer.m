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

classdef PMServer < handle
% PMServer Server for observing paradigms over a network
    properties(Constant = true)
        % Maximum rate at which updates will be sent to the socket, in Hz
        MAX_UPDATE_RATE = 30;
    end
    
    properties(Access = private)
        server;
        lastEyePositionUpdateTime = -1;
        drawCommands = {};
    end
    
    methods
        function self = PMServer()
            global CONFIG PM;
            
            % Initialize server
            import com.simonster.PsychoMonkey.PMServer;
            self.server = PMServer(savejson([], ...
                rmfield(CONFIG, 'eyeTracker')));
            
            % Hook into OSD and event loop
            addlistener(PM.osd, 'targetsChanged', @self.onTargetsChanged);
            addlistener(PM.osd, 'statusChanged', @self.onStatusChanged);
            addlistener(PM.screenManager, 'screenCommand', @self.onScreenCommand);
            addlistener(PM.daq, 'juice', @self.onJuice);
            PM.eventLoop{end+1} = @self.updateEyePosition;
        end
        
        function onTargetsChanged(self, osd, event)
            self.server.updateTargets(savejson([], ...
                struct('targetRects', osd.targetRects, ...
                'targetIsOval', osd.targetIsOval)));
        end
        
        function onStatusChanged(self, osd, event)
            status = struct('state', osd.state, ...
                'performance', osd.performance, ...
                'keyInfo', osd.keyInfo);
            self.server.updateStatus(savejson([], status));
        end
        
        function onScreenCommand(self, src, event)
            if strcmp(event.command, 'Flip')
                self.server.updateDisplay(savejson([], self.drawCommands, ...
                    'NoRowBracket', 1));
                self.drawCommands = {};
            elseif(strcmp(event.command, 'MakeTexture'))
                self.server.addTexture(event.textureIndex, event.arguments{1});
            else
                self.drawCommands{end+1} = struct('command', event.command, ...
                    'arguments', {event.arguments});
            end
        end
        
        function onJuice(self, src, event)
            global PM;
            self.server.juiceGiven(savejson([], ...
                struct('time', event.time, ...
                'between', event.between, ...
                'reps', event.reps)));
        end
        
        function updateEyePosition(self)
            global CONFIG;
            t = GetSecs();
            if t-self.lastEyePositionUpdateTime > 1/self.MAX_UPDATE_RATE
                self.lastEyePositionUpdateTime = t;
                eyePosition = CONFIG.eyeTracker.getEyePosition();
                self.server.updateEyePosition(eyePosition(1), eyePosition(2));
            end
        end
    end
end
