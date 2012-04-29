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

function PMInit()
% PMInit Initialize screens and DAQ
%   PMInit() Opens PTB windows on main window and auxiliary window (if
%   specified) and initializes the DAQ
global CONFIG PM;
if isempty(CONFIG)
    error('Configuration not loaded');
end
KbName('UnifyKeyNames');
PM = struct();
PM.eventLoop = {};
PM.daq = PMDAQ();
PM.screenManager = PMScreenManager();
PM.osd = PMOSD();
if isfield(CONFIG, 'eyeTracker')
    CONFIG.eyeTracker.init();
end
if isfield(CONFIG, 'server') && CONFIG.server
    PM.server = PMServer();
end