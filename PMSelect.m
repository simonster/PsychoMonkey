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

function [index, value] = PMSelect(varargin)
%PMSelect(event1, event2, ...) Wait for several events
%   index = PMSelect(event1, event2, ...) Waits until at least one of the
%   given functions returns a positive value, then returns the index of
%   the function in the argument list as INDEX and the output of the
%   function as OUTPUT
global CONFIG PM;

debug = isfield(CONFIG, 'debug') && CONFIG.debug;
eventLoop = PM.eventLoop;
eventLoopIndexes = 1:length(eventLoop);
indexes = 1:length(varargin);

if debug
    start = GetSecs();
    maxT = 0;
    i = 0;
end
while true
    if debug
        i = i + 1;
        t = GetSecs();
    end
    for index=eventLoopIndexes
        f = eventLoop{index};
        f();
    end
    for index=indexes
        f = varargin{index};
        value = f();
        if value
            if debug
                fprintf('Executed PMSelect at %.2f Hz, Max Lag %.2f ms\n', ...
                    i/(GetSecs()-start), maxT*1000);
            end
            return;
        end
    end
    if debug
        t = GetSecs() - t;
        if t > maxT
            maxT = t;
        end
    end
end
