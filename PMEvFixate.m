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

function f = PMEvFixate(location, radius, invert)
%PMEvFixate Create a fixation event
%   PMEvFixate(LOCATION) creates a function that returns true
%   when the subject fixates within the box defined by LOCATION, specified
%   in degrees from the center of the screen
%
%   PMEvFixate(LOCATION, RADIUS) creates a function that returns true
%   when the subject fixates within RADIUS degrees of LOCATION, specified
%   in degrees from the center of the screen
%
%   PMEvFixate(LOCATION, ..., true) creates a function that returns
%   true when the subject's fixation leaves the specified interval
global CONFIG;
if ~exist('invert', 'var')
    invert = false;
end

function isFinished = innerFunctionCircle()
    dist = norm(location-CONFIG.eyeTracker.getEyePosition());
    isFinished = (invert == (dist > radius));
end
function isFinished = innerFunctionRectangle()
    eyeLocation = CONFIG.eyeTracker.getEyePosition();
    isFinished = (invert ~= (eyeLocation(1) >= location(1) ...
        && eyeLocation(1) <= location(3) && eyeLocation(2) >= location(2) ...
        && eyeLocation(2) <= location(4)));
end

if exist('radius', 'var') && ~isempty(radius)
    if length(location) ~= 2
        error('PMEvFixate(LOCATION, RADIUS) requires that LOCATION be specified as a single point');
    end
    if length(radius) ~= 1
        error('PMEvFixate(LOCATION, RADIUS) requires that RADIUS be specified a single number');
    end
    f = @innerFunctionCircle;
else
    if length(location) ~= 4
        error('PMEvFixate(LOCATION) requires a 4-element rect');
    end
    f = @innerFunctionRectangle;
end
end
